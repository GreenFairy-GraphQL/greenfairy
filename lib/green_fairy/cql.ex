defmodule GreenFairy.CQL do
  @moduledoc """
  CQL (Custom Query Language) extension for automatic filtering support.

  Uses the unified adapter system to detect and extract filter metadata from
  different data sources. Ships with an Ecto adapter, but can be extended
  for Elasticsearch, MongoDB, etc.

  ## Usage

      defmodule MyApp.GraphQL.Types.User do
        use GreenFairy.Type

        type "User", struct: MyApp.Accounts.User do
          use GreenFairy.CQL

          field :id, non_null(:id)
          field :name, :string
          field :email, :string
          field :full_name, :string  # Computed field
        end
      end

  ## Generated Filter Types

  CQL generates filter input types following the GigSmart schema pattern:

  - `CqlFilter{Type}Input` - Main filter with `_and`, `_or`, `_not` combinators
  - `CqlOp{Type}Input` - Operator inputs for each field type (string, integer, etc.)

  For example, a User type generates:

      input CqlFilterUserInput {
        _and: [CqlFilterUserInput]
        _or: [CqlFilterUserInput]
        _not: CqlFilterUserInput
        id: CqlOpIdInput
        name: CqlOpStringInput
        email: CqlOpStringInput
      }

  ## How It Works

  1. CQL uses `GreenFairy.Adapter.find_adapter/2` to find an adapter for the struct
  2. The adapter extracts queryable fields and their types
  3. Operators are inferred from the adapter's type mappings
  4. Custom filters can override or extend adapter-detected fields

  ## Authorization Integration

  CQL integrates with the type's `authorize` callback to prevent users from
  filtering on fields they cannot see:

      type "User", struct: MyApp.User do
        use GreenFairy.CQL

        authorize fn user, ctx ->
          if ctx[:current_user]?.admin do
            :all
          else
            [:id, :name]  # Non-admins can only filter on id and name
          end
        end

        field :id, non_null(:id)
        field :name, :string
        field :email, :string
        field :ssn, :string
      end

  Use `__cql_authorized_fields__/2` to get fields a user can filter on:

      authorized_fields = MyUserType.__cql_authorized_fields__(object, context)
      # [:id, :name]  # Only fields visible to this user

  ## Adapters

  Adapters implement the `GreenFairy.Adapter` behaviour. See that module
  for details on implementing custom adapters.

  Register adapters in config:

      config :green_fairy, :adapters, [
        MyApp.ElasticsearchAdapter,
        GreenFairy.Adapters.Ecto
      ]

  Or per-type:

      type "User", struct: MyApp.User do
        use GreenFairy.CQL, adapter: MyApp.CustomAdapter
        # ...
      end

  ## Custom Filters

  For computed fields or custom filter logic:

      custom_filter :full_name, [:eq, :contains], fn query, op, value ->
        # Your custom filter logic
      end

  Or use type shorthand:

      custom_filter :computed_score, :integer, fn query, op, value ->
        # Gets all integer operators automatically
      end

  ## Schema Integration

  Include CQL types in your schema:

      defmodule MyApp.Schema do
        use Absinthe.Schema
        use GreenFairy.CQL.Schema

        # This imports all CQL operator types and generates filter types
        # for all registered CQL-enabled types
      end

  """

  use GreenFairy.Extension

  alias GreenFairy.Adapter
  alias GreenFairy.CQL.Schema.FilterInput
  alias GreenFairy.CQL.Schema.OrderInput

  @impl true
  def using(opts) do
    adapter = Keyword.get(opts, :adapter)

    quote do
      import GreenFairy.CQL.Macros
      Module.register_attribute(__MODULE__, :cql_custom_filters, accumulate: true)
      Module.register_attribute(__MODULE__, :cql_adapter_override, accumulate: false)

      if unquote(adapter) do
        @cql_adapter_override unquote(adapter)
      end
    end
  end

  @impl true
  def before_compile(env, config) do
    struct_module = config.struct
    type_name = config.type_name
    type_identifier = config.type_identifier
    custom_filters = Module.get_attribute(env.module, :cql_custom_filters) || []
    adapter_override = Module.get_attribute(env.module, :cql_adapter_override)
    adapter = Adapter.find_adapter(struct_module, adapter_override)

    # Get GreenFairy field definitions (have GraphQL type identifiers, including enums)
    gf_fields = Module.get_attribute(env.module, :green_fairy_fields) || []
    gf_field_types = build_gf_field_types(gf_fields)

    {adapter_fields, adapter_field_types} = get_adapter_fields(adapter, struct_module)

    # Merge field types: prefer GreenFairy enum types over Ecto types
    merged_field_types = merge_field_types(adapter_field_types, gf_field_types)

    {custom_filter_meta, custom_filter_fields} = get_custom_filter_info(custom_filters)
    filter_function_clauses = generate_filter_clauses(custom_filters)

    # Build filter fields for input generation
    adapter_filter_fields =
      adapter_fields
      |> Enum.map(fn field -> {field, Map.get(merged_field_types, field)} end)

    custom_fields =
      custom_filter_fields
      |> Enum.map(fn field -> {field, nil} end)

    all_filter_fields = adapter_filter_fields ++ custom_fields
    filter_fields = Enum.uniq_by(all_filter_fields, fn {name, _type} -> name end)

    # Get associations from the struct module for nested filtering
    association_fields = get_association_fields(struct_module)

    # Generate filter input type directly in this module
    # This ensures it exists before Absinthe's @before_compile validates type references
    filter_input_ast =
      FilterInput.generate(type_name, filter_fields, custom_filter_meta, association_fields)

    # Note: Order input types are NOT generated here. They are generated via
    # __cql_generate_order_input__/0 during schema compilation to avoid duplicates.

    generate_cql_functions_and_types(
      filter_function_clauses,
      struct_module,
      adapter,
      adapter_fields,
      merged_field_types,
      custom_filter_meta,
      custom_filter_fields,
      type_name,
      type_identifier,
      filter_fields,
      filter_input_ast,
      association_fields
    )
  end

  # Build a map of field names to GraphQL types from GreenFairy field definitions
  defp build_gf_field_types(gf_fields) do
    gf_fields
    |> Enum.filter(fn field_def -> is_map(field_def) and Map.has_key?(field_def, :name) end)
    |> Map.new(fn field_def -> {field_def.name, field_def.type} end)
  end

  # Merge field types: if GreenFairy has an enum type for a field, use that
  # Otherwise use the adapter (Ecto) type
  defp merge_field_types(adapter_types, gf_types) do
    Map.merge(adapter_types, gf_types, fn _field, adapter_type, gf_type ->
      # If GreenFairy type is a registered enum, use it
      # This allows filter inputs to reference the actual GraphQL enum
      if gf_type && is_atom(gf_type) && GreenFairy.TypeRegistry.is_enum?(gf_type) do
        gf_type
      else
        # Check for array of enums
        case gf_type do
          {:array, inner} when is_atom(inner) ->
            if GreenFairy.TypeRegistry.is_enum?(inner), do: gf_type, else: adapter_type

          _ ->
            adapter_type
        end
      end
    end)
  end

  defp get_adapter_fields(nil, _struct_module), do: {[], %{}}
  defp get_adapter_fields(_adapter, nil), do: {[], %{}}

  defp get_adapter_fields(adapter, struct_module) do
    # Primary adapter (Ecto/ES) implements queryable_fields and field_type
    fields = adapter.queryable_fields(struct_module)
    types = Map.new(fields, fn f -> {f, adapter.field_type(struct_module, f)} end)
    {fields, types}
  end

  # Get association fields from an Ecto schema for nested filtering
  # Returns a list of {field_name, related_type_name} tuples
  defp get_association_fields(nil), do: []

  defp get_association_fields(struct_module) do
    if Code.ensure_loaded?(struct_module) and function_exported?(struct_module, :__schema__, 1) do
      try do
        struct_module.__schema__(:associations)
        |> Enum.map(fn assoc_name ->
          assoc = struct_module.__schema__(:association, assoc_name)
          get_related_type_name(assoc_name, assoc)
        end)
        |> Enum.reject(&is_nil/1)
      rescue
        # Handle schemas that don't fully implement Ecto.Schema (e.g., mocks)
        FunctionClauseError -> []
      end
    else
      []
    end
  end

  # Get the related type name from an association, handling different association types
  defp get_related_type_name(assoc_name, %{related: related}) do
    # Standard associations (belongs_to, has_one, has_many) have a :related key
    related_type_name =
      related
      |> Module.split()
      |> List.last()

    {assoc_name, related_type_name}
  end

  defp get_related_type_name(_assoc_name, %Ecto.Association.HasThrough{}) do
    # Skip has_through associations for now - they're complex and may not
    # have a direct corresponding filter type
    nil
  end

  defp get_related_type_name(_assoc_name, _assoc) do
    # Skip unknown association types
    nil
  end

  defp get_custom_filter_info(custom_filters) do
    meta =
      Map.new(custom_filters, fn cf ->
        {cf.field, %{field: cf.field, operators: cf.operators}}
      end)

    fields = Enum.map(custom_filters, & &1.field)
    {meta, fields}
  end

  defp generate_filter_clauses(custom_filters) do
    Enum.map(custom_filters, fn cf ->
      quote do
        def __cql_apply_custom_filter__(unquote(cf.field), query, op, value) do
          filter_fn = unquote(cf.filter_fn_ast)
          filter_fn.(query, op, value)
        end
      end
    end)
  end

  defp generate_cql_functions_and_types(
         filter_clauses,
         struct_module,
         adapter,
         adapter_fields,
         adapter_field_types,
         custom_filter_meta,
         custom_filter_fields,
         type_name,
         type_identifier,
         filter_fields,
         filter_input_ast,
         association_fields
       ) do
    filter_input_identifier = FilterInput.filter_type_identifier(type_name)

    quote do
      # Generate filter input type directly in this module
      # This ensures it exists before Absinthe's schema validation runs
      unquote(filter_input_ast)

      # Note: Order input types are generated via __cql_generate_order_input__/0
      # during schema compilation, not here, to avoid duplicate type definitions
      unquote_splicing(filter_clauses)

      def __cql_apply_custom_filter__(_field, query, _op, _value), do: query

      def __cql_config__ do
        %{
          struct: unquote(struct_module),
          adapter: unquote(adapter),
          adapter_fields: unquote(adapter_fields),
          adapter_field_types: unquote(Macro.escape(adapter_field_types)),
          custom_filters: unquote(Macro.escape(custom_filter_meta)),
          custom_filter_fields: unquote(custom_filter_fields),
          type_name: unquote(type_name),
          type_identifier: unquote(type_identifier),
          filter_input_identifier: unquote(filter_input_identifier)
        }
      end

      def __cql_adapter__, do: unquote(adapter)

      def __cql_filterable_fields__ do
        Enum.uniq(unquote(adapter_fields) ++ unquote(custom_filter_fields))
      end

      def __cql_association_fields__ do
        unquote(association_fields)
      end

      @doc """
      Checks if a field has a custom filter defined.
      """
      def __cql_has_custom_filter__(field) do
        field in unquote(custom_filter_fields)
      end

      @doc """
      Returns the filter input type identifier for this type.

      This is the GigSmart-style `CqlFilter{Type}Input` identifier.
      """
      def __cql_filter_input_identifier__ do
        unquote(filter_input_identifier)
      end

      @doc """
      Returns the order input type identifier for this type.

      This is the GigSmart-style `CqlOrder{Type}Input` identifier.
      """
      def __cql_order_input_identifier__ do
        OrderInput.order_type_identifier(unquote(type_name))
      end

      @doc """
      Returns fields with their types for filter input generation.
      """
      def __cql_filter_fields__ do
        unquote(Macro.escape(filter_fields))
      end

      @doc """
      Returns fields that can be ordered.

      By default, all filterable fields are also orderable.
      """
      def __cql_orderable_fields__ do
        __cql_filterable_fields__()
      end

      @doc """
      Returns fields that can be filtered, restricted by authorization.

      Uses the type's `authorize` callback to determine which fields the
      current user can see, then intersects with filterable fields.
      """
      def __cql_authorized_fields__(object, context) do
        all_filterable = __cql_filterable_fields__()

        # Call the type's authorize function to get visible fields
        info = %GreenFairy.AuthorizationInfo{}
        # Use Function.identity/1 to prevent compile-time type narrowing
        # This allows handling all cases even when authorize always returns :all
        visible = Function.identity(__authorize__(object, context, info))

        case visible do
          :all -> all_filterable
          :none -> []
          fields when is_list(fields) -> Enum.filter(all_filterable, &(&1 in fields))
        end
      end

      @doc """
      Validates that a filter only uses authorized fields.

      Returns :ok if all filter fields are authorized, or
      {:error, {:unauthorized_fields, fields}} if any are not.
      """
      def __cql_validate_filter__(filter_fields, object, context) when is_list(filter_fields) do
        authorized = __cql_authorized_fields__(object, context)
        unauthorized = filter_fields -- authorized

        if Enum.empty?(unauthorized) do
          :ok
        else
          {:error, {:unauthorized_fields, unauthorized}}
        end
      end

      def __cql_validate_filter__(filter_map, object, context) when is_map(filter_map) do
        filter_fields = Map.keys(filter_map) -- [:_and, :_or, :_not]
        __cql_validate_filter__(filter_fields, object, context)
      end

      @doc """
      Returns operators for a field, only if the field is authorized.

      Returns empty list if the user cannot filter on this field.
      """
      def __cql_authorized_operators_for__(field, object, context) do
        authorized_fields = __cql_authorized_fields__(object, context)

        if field in authorized_fields do
          __cql_operators_for__(field)
        else
          []
        end
      end

      def __cql_operators_for__(field) do
        config = __cql_config__()

        cond do
          Map.has_key?(config.custom_filters, field) ->
            config.custom_filters[field].operators

          field in config.adapter_fields ->
            type = Map.get(config.adapter_field_types, field)
            adapter = config.adapter
            # Use apply/3 to prevent compiler from type-checking module call
            # when adapter is nil at compile time
            if adapter, do: apply(adapter, :operators_for_type, [type]), else: [:eq, :in]

          true ->
            []
        end
      end

      @doc """
      Generates the filter input AST for this type.

      This is used by the schema compiler to generate the CqlFilter{Type}Input type.
      """
      def __cql_generate_filter_input__ do
        config = __cql_config__()

        FilterInput.generate(
          config.type_name,
          __cql_filter_fields__(),
          config.custom_filters,
          __cql_association_fields__()
        )
      end

      @doc """
      Generates the order input AST for this type.

      This is used by the schema compiler to generate the CqlOrder{Type}Input type.
      """
      def __cql_generate_order_input__ do
        config = __cql_config__()

        # Get orderable fields with their types
        orderable_fields =
          __cql_filter_fields__()
          |> Enum.filter(fn {field_name, _type} -> field_name in __cql_orderable_fields__() end)

        OrderInput.generate(
          config.type_name,
          orderable_fields,
          __cql_association_fields__()
        )
      end

      @doc """
      Returns the enum type identifiers used by this type's filter fields.

      This is used by the schema to know which enum-specific operator inputs
      need to be generated.

      ## Example

          MyUserType.__cql_used_enums__()
          # => [:user_role, :account_status]

      """
      def __cql_used_enums__ do
        config = __cql_config__()
        FilterInput.extract_enum_types(__cql_filter_fields__(), config.custom_filters)
      end
    end
  end

  # ============================================================================
  # Macros
  # ============================================================================

  defmodule Macros do
    @moduledoc false

    defmacro custom_filter(field, operators, filter_fn) do
      operators = normalize_operators(operators)
      filter_fn_ast = Macro.escape(filter_fn)

      quote do
        @cql_custom_filters %{
          field: unquote(field),
          operators: unquote(operators),
          filter_fn_ast: unquote(filter_fn_ast)
        }
      end
    end

    defp normalize_operators(:string),
      do: [:eq, :neq, :contains, :starts_with, :ends_with, :in, :is_nil]

    defp normalize_operators(:integer), do: [:eq, :neq, :gt, :lt, :gte, :lte, :in, :is_nil]
    defp normalize_operators(:boolean), do: [:eq, :is_nil]
    defp normalize_operators(:datetime), do: [:eq, :neq, :gt, :lt, :gte, :lte, :is_nil]
    defp normalize_operators(ops) when is_list(ops), do: ops
    defp normalize_operators(_), do: [:eq, :in]
  end
end
