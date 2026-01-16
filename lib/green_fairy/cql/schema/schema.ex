defmodule GreenFairy.CQL.Schema.Helpers do
  @moduledoc """
  Schema integration for CQL filter types.

  Include this module in your schema to generate all CQL operator and filter input types.

  ## Usage

      defmodule MyApp.Schema do
        use Absinthe.Schema
        use GreenFairy.CQL.Schema

        # Import your types that use CQL
        import_types MyApp.GraphQL.Types.User
        import_types MyApp.GraphQL.Types.Post

        query do
          field :users, list_of(:user) do
            arg :filter, :cql_filter_user_input
            resolve &MyApp.Resolvers.list_users/3
          end
        end
      end

  ## What Gets Generated

  This module generates:

  1. **Operator Input Types** - Reusable types for field operators:
     - `CqlOpIdInput` - ID field operators (eq, neq, in, is_nil)
     - `CqlOpStringInput` - String field operators (eq, neq, contains, starts_with, ends_with, in, is_nil)
     - `CqlOpIntegerInput` - Integer field operators (eq, neq, gt, gte, lt, lte, in, is_nil)
     - `CqlOpFloatInput` - Float/Decimal field operators
     - `CqlOpBooleanInput` - Boolean field operators (eq, is_nil)
     - `CqlOpDatetimeInput` - DateTime field operators
     - `CqlOpDateInput` - Date field operators
     - `CqlOpTimeInput` - Time field operators
     - `CqlOpEnumInput` - Enum field operators
     - `CqlOpGenericInput` - Fallback for unknown types

  2. **Filter Input Types** - Type-specific filter inputs with combinators:
     - `CqlFilter{Type}Input` for each CQL-enabled type
     - Includes `_and`, `_or`, `_not` combinators
     - Includes field-specific operator references

  ## Dynamic Filter Generation

  For dynamically generated filter types, use the `cql_filter_input/1` macro:

      cql_filter_input MyApp.GraphQL.Types.User
      cql_filter_input MyApp.GraphQL.Types.Post

  Or use `cql_filter_inputs/1` to generate from a list:

      cql_filter_inputs [
        MyApp.GraphQL.Types.User,
        MyApp.GraphQL.Types.Post
      ]
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Absinthe.Schema.Notation

      import GreenFairy.CQL.Schema,
        only: [
          cql_operator_types: 0,
          cql_base_types: 0,
          cql_filter_input: 1,
          cql_filter_inputs: 1,
          cql_order_input: 1,
          cql_order_inputs: 1
        ]

      # Include base types by default (operators and order types)
      cql_base_types()

      # Register before_compile to auto-discover CQL types
      @before_compile GreenFairy.CQL.Schema
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    # Discover all CQL-enabled types in the schema's namespace
    schema_module = env.module
    schema_namespace = get_schema_namespace(schema_module)

    # Discover CQL types under the schema's namespace
    cql_types = GreenFairy.Discovery.discover_cql_types_in_namespaces([schema_namespace])

    # Collect all enums used by CQL types (for type-specific enum operator inputs)
    used_enums = collect_used_enums(cql_types)

    # Generate enum-specific operator inputs FIRST (before filter inputs reference them)
    enum_operator_statements = generate_enum_operator_statements(used_enums)

    # Generate filter and order inputs for all discovered CQL types
    filter_statements =
      Enum.map(cql_types, fn type_module ->
        quote do
          if function_exported?(unquote(type_module), :__cql_generate_filter_input__, 0) do
            filter_ast = unquote(type_module).__cql_generate_filter_input__()
            Code.eval_quoted(filter_ast, [], __ENV__)
          end
        end
      end)

    order_statements =
      Enum.map(cql_types, fn type_module ->
        quote do
          if function_exported?(unquote(type_module), :__cql_generate_order_input__, 0) do
            order_ast = unquote(type_module).__cql_generate_order_input__()
            Code.eval_quoted(order_ast, [], __ENV__)
          end
        end
      end)

    quote do
      # Generate enum-specific operator inputs first
      unquote_splicing(enum_operator_statements)
      # Generate all filter inputs
      unquote_splicing(filter_statements)
      # Generate all order inputs
      unquote_splicing(order_statements)
    end
  end

  # Collect all unique enum identifiers used by CQL-enabled types
  defp collect_used_enums(cql_types) do
    cql_types
    |> Enum.flat_map(fn type_module ->
      if function_exported?(type_module, :__cql_used_enums__, 0) do
        type_module.__cql_used_enums__()
      else
        []
      end
    end)
    |> Enum.uniq()
  end

  # Generate AST statements for enum-specific operator inputs
  defp generate_enum_operator_statements(enum_identifiers) do
    Enum.flat_map(enum_identifiers, fn enum_id ->
      # Generate both scalar and array operator inputs for each enum
      scalar_ast = GreenFairy.CQL.Schema.EnumOperatorInput.generate(enum_id)
      array_ast = GreenFairy.CQL.Schema.EnumOperatorInput.generate_array(enum_id)
      [scalar_ast, array_ast]
    end)
  end

  # Extract the namespace from a schema module
  # e.g., MyApp.GraphQL.Schema -> MyApp.GraphQL
  defp get_schema_namespace(schema_module) do
    module_parts =
      schema_module
      |> Module.split()
      |> Enum.reverse()
      |> tl()
      |> Enum.reverse()

    Module.concat(module_parts)
  end

  @doc """
  Generates all CQL base types (operators and order types).

  This includes:
  - CQL operator input types (CqlOp{Type}Input)
  - Sort direction enum (CqlSortDirection)
  - Standard order input (CqlOrderStandardInput)
  - Geo order input (CqlOrderGeoInput)

  This macro is automatically called when you `use GreenFairy.CQL.Schema`.

  ## Adapter Detection

  The macro attempts to detect the CQL adapter from the schema's configuration:
  1. First checks for explicit `@green_fairy_cql_adapter` module attribute
  2. Then detects from `@green_fairy_repo` if available
  3. Falls back to PostgreSQL adapter as default

  ## Operator Overlap Prevention

  Each schema generates operators for ONLY ONE adapter. This prevents conflicts
  where PostgreSQL's `_ilike` operator would conflict with MySQL's lack of that operator.

  Example:
  - PostgreSQL schema generates: CqlOpStringInput with [:_eq, :_ilike, ...]
  - MySQL schema generates: CqlOpStringInput with [:_eq, :_like, ...] (no _ilike)
  - Elasticsearch schema generates: CqlOpStringInput with [:_eq, :_match, :_match_phrase, ...]

  Since each schema is tied to a single database, this works correctly.

  """
  defmacro cql_base_types do
    # Detect adapter at macro expansion time
    adapter = detect_cql_adapter_at_compile(__CALLER__)

    # Generate order types (not adapter-specific) at macro expansion time
    order_base_types_ast = GreenFairy.CQL.Schema.OrderInput.generate_base_types()

    # Generate operator types for the detected adapter at macro expansion time
    # This ensures only ONE adapter's operators are in the schema
    operator_types_ast = GreenFairy.CQL.Schema.OperatorInput.generate_all(adapter: adapter)

    quote do
      (unquote_splicing(operator_types_ast))
      (unquote_splicing(order_base_types_ast))
    end
  end

  @doc """
  Detects the CQL adapter for a schema at macro expansion time.

  ## Detection Order

  1. Check `@green_fairy_cql_adapter` module attribute
  2. Check `@green_fairy_repo` and detect adapter from repo
  3. Check application config: `config :green_fairy, :cql_adapter`
  4. Check application config: `config :green_fairy, :repo` and detect
  5. Default to PostgreSQL adapter

  ## Examples

      # Explicit adapter
      defmodule MyApp.Schema do
        use Absinthe.Schema
        @green_fairy_cql_adapter GreenFairy.CQL.Adapters.MySQL
        use GreenFairy.CQL.Schema
      end

      # Detect from repo
      defmodule MyApp.Schema do
        use Absinthe.Schema
        @green_fairy_repo MyApp.Repo
        use GreenFairy.CQL.Schema
      end

  """
  def detect_cql_adapter_at_compile(caller) do
    schema_module = caller.module

    cond do
      # Check for explicit @green_fairy_cql_adapter attribute
      adapter_attr = Module.get_attribute(schema_module, :green_fairy_cql_adapter) ->
        adapter_attr

      # Check for @green_fairy_repo attribute and detect from repo
      repo_attr = Module.get_attribute(schema_module, :green_fairy_repo) ->
        if repo_attr do
          GreenFairy.CQL.Adapter.detect_adapter(repo_attr)
        else
          detect_from_config()
        end

      # Fallback to config or default
      true ->
        detect_from_config()
    end
  end

  # Helper to detect adapter from application config
  defp detect_from_config do
    cond do
      # Check application config for explicit adapter
      configured_adapter = Application.get_env(:green_fairy, :cql_adapter) ->
        configured_adapter

      # Check application config for repo and detect
      configured_repo = Application.get_env(:green_fairy, :repo) ->
        GreenFairy.CQL.Adapter.detect_adapter(configured_repo)

      # Default to PostgreSQL
      true ->
        GreenFairy.CQL.Adapters.Postgres
    end
  end

  @doc """
  Generates all CQL operator input types.

  These are the `CqlOp{Type}Input` types that define available operators
  for each scalar type in CQL filters.

  This is now included in `cql_base_types/0` and called automatically.

  The operator types generated depend on the detected adapter.
  """
  defmacro cql_operator_types do
    # Detect adapter at macro expansion time
    adapter = detect_cql_adapter_at_compile(__CALLER__)
    operator_types_ast = GreenFairy.CQL.Schema.OperatorInput.generate_all(adapter: adapter)

    quote do
      (unquote_splicing(operator_types_ast))
    end
  end

  @doc """
  Generates a CQL filter input type for a specific type module.

  ## Example

      cql_filter_input MyApp.GraphQL.Types.User

  This generates a `CqlFilterUserInput` type with:
  - `_and`, `_or`, `_not` combinators
  - Field-specific operator inputs (e.g., `name: CqlOpStringInput`)
  """
  defmacro cql_filter_input(type_module) do
    quote do
      # The type module must export __cql_generate_filter_input__/0
      filter_ast = unquote(type_module).__cql_generate_filter_input__()
      Code.eval_quoted(filter_ast, [], __ENV__)
    end
  end

  @doc """
  Generates CQL filter input types for a list of type modules.

  ## Example

      cql_filter_inputs [
        MyApp.GraphQL.Types.User,
        MyApp.GraphQL.Types.Post,
        MyApp.GraphQL.Types.Comment
      ]
  """
  defmacro cql_filter_inputs(modules) do
    quote do
      for module <- unquote(modules) do
        if function_exported?(module, :__cql_generate_filter_input__, 0) do
          filter_ast = module.__cql_generate_filter_input__()
          Code.eval_quoted(filter_ast, [], __ENV__)
        end
      end
    end
  end

  @doc """
  Generates a CQL order input type for a specific type module.

  ## Example

      cql_order_input MyApp.GraphQL.Types.User

  This generates a `CqlOrderUserInput` type with fields for each orderable field.
  """
  defmacro cql_order_input(type_module) do
    quote do
      # The type module must export __cql_generate_order_input__/0
      if function_exported?(unquote(type_module), :__cql_generate_order_input__, 0) do
        order_ast = unquote(type_module).__cql_generate_order_input__()
        Code.eval_quoted(order_ast, [], __ENV__)
      end
    end
  end

  @doc """
  Generates CQL order input types for a list of type modules.

  ## Example

      cql_order_inputs [
        MyApp.GraphQL.Types.User,
        MyApp.GraphQL.Types.Post,
        MyApp.GraphQL.Types.Comment
      ]
  """
  defmacro cql_order_inputs(modules) do
    quote do
      for module <- unquote(modules) do
        if function_exported?(module, :__cql_generate_order_input__, 0) do
          order_ast = module.__cql_generate_order_input__()
          Code.eval_quoted(order_ast, [], __ENV__)
        end
      end
    end
  end

  @doc """
  Returns the filter input type identifier for a type module.

  Useful for dynamically referencing filter types in queries.

  ## Example

      field :users, list_of(:user) do
        arg :filter, cql_filter_type_for(MyApp.GraphQL.Types.User)
        resolve &MyApp.Resolvers.list_users/3
      end
  """
  def cql_filter_type_for(type_module) do
    type_module.__cql_filter_input_identifier__()
  end

  @doc """
  Returns the order input type identifier for a type module.

  Useful for dynamically referencing order types in queries.

  ## Example

      field :users, list_of(:user) do
        arg :order_by, list_of(cql_order_type_for(MyApp.GraphQL.Types.User))
        resolve &MyApp.Resolvers.list_users/3
      end
  """
  def cql_order_type_for(type_module) do
    type_module.__cql_order_input_identifier__()
  end
end
