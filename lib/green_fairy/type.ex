defmodule GreenFairy.Type do
  @moduledoc """
  Defines a GraphQL object type with a clean DSL.

  ## Usage

      defmodule MyApp.GraphQL.Types.User do
        use GreenFairy.Type

        type "User", struct: MyApp.User do
          @desc "A user in the system"

          implements MyApp.GraphQL.Interfaces.Node

          field :id, :id, null: false
          field :email, :string, null: false
          field :name, :string

          field :full_name, :string do
            resolve fn user, _, _ ->
              {:ok, "\#{user.first_name} \#{user.last_name}"}
            end
          end
        end
      end

  ## Options

  - `:struct` - The backing Elixir struct for this type (used for resolve_type)
  - `:description` - Description of the type (can also use @desc)

  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Absinthe.Schema.Notation
      import Absinthe.Schema.Notation, except: [object: 2]

      import GreenFairy.Type, only: [type: 2, type: 3, authorize: 1, expose: 1, expose: 2]
      import GreenFairy.Field.Connection, only: [connection: 2, connection: 3]
      import GreenFairy.Field.Loader, only: [loader: 1, loader: 4]
      # assoc is handled via AST transformation, not as a regular macro

      Module.register_attribute(__MODULE__, :green_fairy_type, accumulate: false)
      Module.register_attribute(__MODULE__, :green_fairy_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :green_fairy_interfaces, accumulate: true)
      Module.register_attribute(__MODULE__, :green_fairy_connections, accumulate: true)
      Module.register_attribute(__MODULE__, :green_fairy_policy, accumulate: false)
      Module.register_attribute(__MODULE__, :green_fairy_authorize_fn, accumulate: false)
      Module.register_attribute(__MODULE__, :green_fairy_extensions, accumulate: true)
      Module.register_attribute(__MODULE__, :green_fairy_referenced_types, accumulate: true)
      Module.register_attribute(__MODULE__, :green_fairy_expose, accumulate: true)
      Module.register_attribute(__MODULE__, :cql_custom_filters, accumulate: true)

      # Import CQL macros for custom filters
      import GreenFairy.CQL.Macros

      @before_compile GreenFairy.Type
    end
  end

  @doc """
  Sets up field-level authorization for this type.

  ## Function-based Authorization (Recommended)

  Pass a function that receives the object and context, returns visible fields:

      type "User", struct: MyApp.User do
        authorize fn user, ctx ->
          cond do
            ctx[:current_user]?.admin -> :all
            ctx[:current_user]?.id == user.id -> :all
            true -> [:id, :name]
          end
        end

        field :id, non_null(:id)
        field :name, :string
        field :email, :string
        field :ssn, :string
      end

  ## With Path/Parent Info

  Use 3-arity function to access path through the graph:

      type "Comment", struct: MyApp.Comment do
        authorize fn comment, ctx, info ->
          # info.path = [:query, :user, :posts, :comments]
          # info.parent = %Post{...}
          # info.parents = [%User{}, %Post{}]

          post = info.parent
          if post.public, do: :all, else: [:id, :body]
        end

        field :id, non_null(:id)
        field :body, :string
        field :author, :user
      end

  ## Return Values

  - `:all` - All fields visible
  - `:none` - Object filtered from results (no access)
  - `[:field1, :field2]` - Only these fields visible

  ## Legacy Policy-based Authorization

  For backwards compatibility, you can still use a policy module:

      type "User", struct: MyApp.User do
        authorize with: MyApp.Policies.User
        # ...
      end

  """
  defmacro authorize(func) when is_tuple(func) do
    # Check if it's a keyword list (old style) or a function capture
    case func do
      {:fn, _, _} ->
        # It's an anonymous function
        quote do
          @green_fairy_authorize_fn unquote(Macro.escape(func))
        end

      _ ->
        # Could be a function capture like &visible_fields/2
        quote do
          @green_fairy_authorize_fn unquote(Macro.escape(func))
        end
    end
  end

  defmacro authorize(opts) when is_list(opts) do
    policy = Keyword.fetch!(opts, :with)

    quote do
      @green_fairy_policy unquote(policy)
    end
  end

  @doc """
  Exposes this type as a query field, fetchable by the given field.

  The field type is automatically inferred from the struct's adapter.

  ## Usage

      type "User", struct: MyApp.User do
        expose :id           # Generates query: user(id: ID!): User
        expose :email        # Generates query: userByEmail(email: String!): User

        field :id, non_null(:id)
        field :email, :string
        field :name, :string
      end

  ## Options

  - `:as` - Custom query field name (default: type_name or type_name_by_field)
  - `:unique` - Whether this field is unique (default: true for :id, false otherwise)

  ## Generated Queries

  For `expose :id`:
  - Query field name: `:user` (singular of type name)
  - Fetches via: `Repo.get(User, id)`

  For `expose :email`:
  - Query field name: `:user_by_email`
  - Fetches via: `Repo.get_by(User, email: email)`

  ## How It Works

  1. The field type is looked up from the adapter (Ecto schema, etc.)
  2. A query field is auto-generated with the appropriate arg type
  3. The resolver decodes GlobalId (if :id) or uses the raw value
  4. Fetches from the database using the schema's configured repo

  """
  defmacro expose(field_name, opts \\ []) do
    quote do
      @green_fairy_expose %{
        field: unquote(field_name),
        opts: unquote(opts)
      }
    end
  end

  @doc """
  Defines a GraphQL object type.

  ## Examples

      type "User" do
        field :id, :id
        field :name, :string
      end

      type "User", struct: MyApp.User do
        field :id, :id
      end

  """
  defmacro type(name, opts \\ [], do: block) do
    identifier = GreenFairy.Naming.to_identifier(name)
    env = __CALLER__
    struct_module_ast = opts[:struct]
    # Expand the struct module reference to the actual module
    struct_module = if struct_module_ast, do: Macro.expand(struct_module_ast, env), else: nil

    # Check if CQL is disabled via opts[:cql] == false
    cql_enabled = opts[:cql] != false && struct_module != nil

    # If CQL is enabled and not already in the block, prepend `use GreenFairy.CQL`
    block_with_cql =
      if cql_enabled && !has_cql_use?(block) do
        prepend_cql_use(block)
      else
        block
      end

    # Extract connection definitions from the block FIRST
    connection_defs = extract_connections(block_with_cql, env)

    # Generate connection types (these need to be defined before the main object)
    connection_types = generate_connection_types_ast(connection_defs)

    # Transform the block - this removes connection definitions and leaves field references
    transformed_block = transform_block(block_with_cql, env, struct_module)

    quote do
      @green_fairy_type %{
        kind: :object,
        name: unquote(name),
        identifier: unquote(identifier),
        struct: unquote(opts[:struct]),
        description: unquote(opts[:description]),
        on_unauthorized: unquote(opts[:on_unauthorized])
      }

      # Store connection definitions for introspection
      unquote_splicing(
        Enum.map(connection_defs, fn conn_def ->
          quote do
            @green_fairy_connections unquote(Macro.escape(conn_def))
          end
        end)
      )

      # Generate connection types BEFORE the main object that references them
      unquote_splicing(connection_types)

      @desc unquote(opts[:description])
      Absinthe.Schema.Notation.object unquote(identifier) do
        unquote(transformed_block)
      end
    end
  end

  # Check if the block already has `use GreenFairy.CQL`
  defp has_cql_use?({:__block__, _, statements}) do
    Enum.any?(statements, &cql_use?/1)
  end

  defp has_cql_use?(statement), do: cql_use?(statement)

  defp cql_use?({:use, _, [{:__aliases__, _, [:GreenFairy, :CQL]} | _]}), do: true
  defp cql_use?({:use, _, [GreenFairy.CQL | _]}), do: true
  defp cql_use?(_), do: false

  # Prepend `use GreenFairy.CQL` to the block
  defp prepend_cql_use({:__block__, meta, statements}) do
    cql_use = quote do: use(GreenFairy.CQL)
    {:__block__, meta, [cql_use | statements]}
  end

  defp prepend_cql_use(single_statement) do
    cql_use = quote do: use(GreenFairy.CQL)
    {:__block__, [], [cql_use, single_statement]}
  end

  # Extract connection definitions from the block
  defp extract_connections({:__block__, _, statements}, env) do
    statements
    |> Enum.flat_map(&extract_connection_from_statement(&1, env))
  end

  defp extract_connections(statement, env) do
    extract_connection_from_statement(statement, env)
  end

  defp extract_connection_from_statement({:connection, _, args}, env) do
    {field_name, type_module_or_opts, block} = parse_connection_args(args)

    {type_module, opts} =
      case type_module_or_opts do
        opts when is_list(opts) -> {nil, opts}
        module -> {module, []}
      end

    type_identifier =
      if type_module do
        type_module = Macro.expand(type_module, env)
        type_module.__green_fairy_identifier__()
      else
        opts[:node]
      end

    connection_name = :"#{field_name}_connection"
    edge_name = :"#{field_name}_edge"

    {edge_block, connection_fields, _custom_resolver, _aggregates} =
      GreenFairy.Field.Connection.parse_connection_block(block)

    [
      %{
        field_name: field_name,
        type_identifier: type_identifier,
        connection_name: connection_name,
        edge_name: edge_name,
        edge_block: edge_block,
        connection_fields: connection_fields
      }
    ]
  end

  defp extract_connection_from_statement(_, _env), do: []

  defp parse_connection_args([field_name]), do: {field_name, [], nil}
  defp parse_connection_args([field_name, [do: block]]), do: {field_name, [], block}
  defp parse_connection_args([field_name, type_module_or_opts]), do: {field_name, type_module_or_opts, nil}

  defp parse_connection_args([field_name, type_module_or_opts, [do: block]]),
    do: {field_name, type_module_or_opts, block}

  # Generate AST for connection types
  defp generate_connection_types_ast(connection_defs) do
    Enum.flat_map(connection_defs, fn conn ->
      edge_type =
        quote do
          Absinthe.Schema.Notation.object unquote(conn.edge_name) do
            field :node, unquote(conn.type_identifier)
            field :cursor, non_null(:string)
            unquote(conn.edge_block)
          end
        end

      connection_type =
        quote do
          Absinthe.Schema.Notation.object unquote(conn.connection_name) do
            field :edges, list_of(unquote(conn.edge_name))
            field :page_info, non_null(:page_info)
            unquote(conn.connection_fields)
          end
        end

      [edge_type, connection_type]
    end)
  end

  # Transform our DSL to Absinthe's notation - only handle implements, pass through rest
  defp transform_block({:__block__, meta, statements}, env, struct_module) do
    transformed = Enum.map(statements, &transform_statement(&1, env, struct_module))
    {:__block__, meta, transformed}
  end

  defp transform_block(statement, env, struct_module) do
    transform_statement(statement, env, struct_module)
  end

  defp transform_statement({:implements, _meta, [interface_module_ast]}, env, _struct_module) do
    # Expand the module reference to get the actual module
    interface_module = Macro.expand(interface_module_ast, env)
    interface_identifier = interface_module.__green_fairy_identifier__()

    quote do
      @green_fairy_interfaces unquote(interface_module)
      @green_fairy_referenced_types unquote(interface_module)
      Absinthe.Schema.Notation.interface(unquote(interface_identifier))
    end
  end

  # Transform authorize declaration - old style with policy module
  defp transform_statement({:authorize, _meta, [[with: policy_module]]}, _env, _struct_module) do
    quote do
      @green_fairy_policy unquote(policy_module)
    end
  end

  # Transform authorize declaration - new style with function
  defp transform_statement({:authorize, _meta, [func]}, _env, _struct_module) when not is_list(func) do
    quote do
      @green_fairy_authorize_fn unquote(Macro.escape(func))
    end
  end

  # Transform loader macro inside field blocks - converts to batch resolver
  defp transform_statement({:loader, _meta, [func]}, _env, _struct_module) do
    quote do
      resolve fn parent, args, %{context: context} ->
        batch_fn = unquote(func)

        Absinthe.Resolution.Helpers.batch(
          {GreenFairy.Field.Loader, :__batch_loader__, [batch_fn, args, context]},
          parent,
          fn results ->
            {:ok, Map.get(results, parent)}
          end
        )
      end
    end
  end

  # Transform assoc fields - generate field AST with automatic DataLoader
  defp transform_statement({:assoc, _meta, [field_name]}, env, struct_module) do
    # Generate the field AST
    field_ast = GreenFairy.Field.Association.generate_assoc_field_ast(struct_module, field_name, [], env)

    # Track the type reference for graph discovery
    type_ref = get_assoc_type_reference(struct_module, field_name)

    quote do
      if unquote(type_ref) do
        @green_fairy_referenced_types unquote(type_ref)
      end

      unquote(field_ast)
    end
  end

  defp transform_statement({:assoc, _meta, [field_name, opts]}, env, struct_module) do
    # Generate the field AST
    field_ast = GreenFairy.Field.Association.generate_assoc_field_ast(struct_module, field_name, opts, env)

    # Track the type reference for graph discovery
    type_ref = get_assoc_type_reference(struct_module, field_name)

    quote do
      if unquote(type_ref) do
        @green_fairy_referenced_types unquote(type_ref)
      end

      unquote(field_ast)
    end
  end

  # Transform connection fields - emit only the field reference
  # The connection types are generated in the type macro before the main object
  defp transform_statement({:connection, _meta, args}, _env, _struct_module) do
    {field_name, type_module_or_opts, _block} = parse_connection_args(args)
    connection_name = :"#{field_name}_connection"

    # Extract the node type reference for graph discovery
    type_ref =
      case type_module_or_opts do
        opts when is_list(opts) -> opts[:node]
        module -> module
      end

    quote do
      # Track the node type reference
      if unquote(type_ref) do
        @green_fairy_referenced_types unquote(type_ref)
      end

      field unquote(field_name), unquote(connection_name) do
        arg :first, :integer
        arg :after, :string
        arg :last, :integer
        arg :before, :string
      end
    end
  end

  # Transform use statements for extensions
  # Extensions must implement the GreenFairy.Extension behaviour
  defp transform_statement({:use, _meta, [module_ast | rest]}, env, _struct_module) do
    module = Macro.expand(module_ast, env)
    opts = List.first(rest) || []

    if extension_module?(module) do
      # Get the using callback result from the extension
      using_code = module.using(opts)

      quote do
        @green_fairy_extensions unquote(module)
        unquote(using_code)
      end
    else
      # Not an extension, pass through as regular use
      {:use, [], [module_ast | rest]}
    end
  end

  # Transform field macro - record field info and pass through to Absinthe
  defp transform_statement({:field, meta, args}, env, _struct_module) do
    {field_name, field_type, opts, has_resolver, block} = parse_field_args(args, env)

    # Validate that field doesn't have both resolve and loader
    if block do
      validate_field_resolution(block, field_name, env)
    end

    # Extract type reference from the original args for graph discovery
    type_ref = extract_type_reference(args)

    field_info = %{
      name: field_name,
      type: field_type,
      opts: opts,
      resolver: has_resolver || false
    }

    # Transform the field args to convert module references to type identifiers
    transformed_args = transform_field_type_refs(args, env)

    quote do
      @green_fairy_fields unquote(Macro.escape(field_info))

      # Track type reference for graph-based discovery
      if unquote(type_ref) do
        @green_fairy_referenced_types unquote(type_ref)
      end

      unquote({:field, meta, transformed_args})
    end
  end

  # Pass through everything else unchanged - let Absinthe handle it
  defp transform_statement(other, _env, _struct_module), do: other

  # Transform field args to convert module references to type identifiers
  defp transform_field_type_refs([name, type | rest], env) do
    [name, transform_field_type(type, env) | rest]
  end

  defp transform_field_type_refs(args, _env), do: args

  # Transform a type reference (possibly wrapped in non_null/list_of)
  defp transform_field_type({:non_null, meta, [inner]}, env) do
    {:non_null, meta, [transform_field_type(inner, env)]}
  end

  defp transform_field_type({:list_of, meta, [inner]}, env) do
    {:list_of, meta, [transform_field_type(inner, env)]}
  end

  defp transform_field_type({:__aliases__, _, _} = module_ast, env) do
    # Expand module alias and get type identifier
    module = Macro.expand(module_ast, env)

    case Code.ensure_compiled(module) do
      {:module, ^module} ->
        if function_exported?(module, :__green_fairy_identifier__, 0) do
          module.__green_fairy_identifier__()
        else
          module
        end

      _ ->
        module
    end
  end

  defp transform_field_type(type, _env), do: type

  # Extract type reference from field arguments for graph-based discovery
  # Returns the base type identifier (atom) or nil for built-in scalars
  defp extract_type_reference([_name]), do: nil
  defp extract_type_reference([_name, type]) when not is_list(type), do: extract_base_type(type)
  defp extract_type_reference([_name, opts]) when is_list(opts), do: nil

  defp extract_type_reference([_name, type, opts]) when is_list(opts) do
    extract_base_type(type)
  end

  defp extract_type_reference([_name, type, opts, _block]) when is_list(opts) do
    extract_base_type(type)
  end

  defp extract_type_reference(_), do: nil

  # Extract the base type identifier, unwrapping non_null and list_of
  defp extract_base_type({:non_null, _, [inner_type]}), do: extract_base_type(inner_type)
  defp extract_base_type({:list_of, _, [inner_type]}), do: extract_base_type(inner_type)

  # Module alias reference (e.g., MyApp.Types.Post)
  defp extract_base_type({:__aliases__, _, _} = module_ast), do: module_ast

  # Atom type identifier (e.g., :post, :user)
  defp extract_base_type(type) when is_atom(type) do
    if builtin_scalar?(type), do: nil, else: type
  end

  defp extract_base_type(_), do: nil

  # Built-in Absinthe scalar types that shouldn't be tracked
  @builtin_scalars ~w(
    id string integer float boolean datetime date time naive_datetime decimal
  )a

  defp builtin_scalar?(type) when is_atom(type) do
    type in @builtin_scalars
  end

  # Get the type identifier for an association field
  # Returns the type identifier atom (e.g., :post) or nil
  defp get_assoc_type_reference(struct_module, field_name) when not is_nil(struct_module) do
    case Code.ensure_compiled(struct_module) do
      {:module, ^struct_module} ->
        if function_exported?(struct_module, :__schema__, 2) do
          case struct_module.__schema__(:association, field_name) do
            nil ->
              nil

            %{related: related} ->
              # Get the type identifier from the related Ecto struct
              GreenFairy.Field.Association.get_type_identifier(related)

            _ ->
              nil
          end
        else
          nil
        end

      _ ->
        nil
    end
  end

  defp get_assoc_type_reference(_struct_module, _field_name), do: nil

  # Parse field arguments into components
  # Returns: {field_name, field_type, opts, has_resolver, block}
  defp parse_field_args([name], _env), do: {name, nil, [], nil, nil}

  defp parse_field_args([name, type], _env) when not is_list(type) do
    {base_type, type_opts} = unwrap_type(type)
    {name, base_type, type_opts, nil, nil}
  end

  defp parse_field_args([name, opts], _env) when is_list(opts) do
    case Keyword.get(opts, :do) do
      nil -> {name, nil, opts, nil, nil}
      block -> {name, nil, [], nil, block}
    end
  end

  defp parse_field_args([name, type, opts], _env) when is_list(opts) do
    case Keyword.pop(opts, :do) do
      {nil, rest_opts} ->
        {base_type, type_opts} = unwrap_type(type)
        {name, base_type, Keyword.merge(type_opts, rest_opts), nil, nil}

      {block, rest_opts} ->
        resolver = has_resolver?(block)
        {base_type, type_opts} = unwrap_type(type)
        {name, base_type, Keyword.merge(type_opts, rest_opts), resolver, block}
    end
  end

  defp parse_field_args([name, type, opts, block_opts], _env) when is_list(opts) and is_list(block_opts) do
    block = Keyword.get(block_opts, :do)
    resolver = has_resolver?(block)
    {base_type, type_opts} = unwrap_type(type)
    {name, base_type, Keyword.merge(type_opts, opts), resolver, block}
  end

  defp parse_field_args(args, _env) when is_list(args) do
    # Fallback for any other format
    name = List.first(args)

    if length(args) > 1 do
      {base_type, type_opts} = unwrap_type(Enum.at(args, 1))
      {name, base_type, type_opts, nil, nil}
    else
      {name, nil, [], nil, nil}
    end
  end

  # Unwrap non_null wrapper and extract base type
  defp unwrap_type({:non_null, _, [inner_type]}) do
    {base_type, inner_opts} = unwrap_type(inner_type)
    {base_type, Keyword.merge(inner_opts, null: false)}
  end

  defp unwrap_type({:list_of, _, [inner_type]}) do
    {base_type, inner_opts} = unwrap_type(inner_type)
    {base_type, Keyword.merge(inner_opts, list: true)}
  end

  defp unwrap_type(type) when is_atom(type), do: {type, []}
  defp unwrap_type({type, _, _}) when is_atom(type), do: {type, []}
  defp unwrap_type(type), do: {type, []}

  # Check if a block contains a resolve statement
  defp has_resolver?({:resolve, _, _}), do: true
  defp has_resolver?({:__block__, _, statements}), do: Enum.any?(statements, &has_resolver?/1)
  defp has_resolver?(_), do: false

  # Check if a block contains a loader statement
  defp has_loader?({:loader, _, _}), do: true
  defp has_loader?({:__block__, _, statements}), do: Enum.any?(statements, &has_loader?/1)
  defp has_loader?(_), do: false

  # Validate that a field doesn't have both resolve and loader
  defp validate_field_resolution(block, field_name, env) do
    has_resolve = has_resolver?(block)
    has_load = has_loader?(block)

    if has_resolve and has_load do
      raise CompileError,
        file: env.file,
        line: env.line,
        description: """
        Field :#{field_name} cannot have both `resolve` and `loader`.

        These are mutually exclusive - use one or the other:
        - Use `resolve` for single-item resolution
        - Use `loader` for batch loading

        Remove either the `resolve` or `loader` statement.
        """
    end
  end

  # Check if a module implements the Extension behaviour
  defp extension_module?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and
      function_exported?(module, :using, 1)
  end

  defp extension_module?(_), do: false

  # Generate the __authorize__/3 implementation based on authorize_fn or policy
  defp generate_authorize_impl(nil, nil) do
    # No authorization - return :all
    quote do
      @doc """
      Determines which fields are visible for the given object and context.

      Returns `:all`, `:none`, or a list of field names.
      """
      def __authorize__(object, context, info) do
        :all
      end

      @doc false
      def __has_authorization__, do: false
    end
  end

  defp generate_authorize_impl(authorize_fn, _policy) when not is_nil(authorize_fn) do
    # Function-based authorization
    quote do
      @doc """
      Determines which fields are visible for the given object and context.

      Returns `:all`, `:none`, or a list of field names.
      """
      def __authorize__(object, context, info) do
        auth_fn = unquote(authorize_fn)

        # Use apply/3 to avoid compiler type-checking issues with different arities
        case :erlang.fun_info(auth_fn, :arity) do
          {:arity, 2} -> apply(auth_fn, [object, context])
          {:arity, 3} -> apply(auth_fn, [object, context, info])
          _ -> :all
        end
      end

      @doc false
      def __has_authorization__, do: true
    end
  end

  defp generate_authorize_impl(nil, policy) when not is_nil(policy) do
    # Legacy policy-based authorization
    quote do
      @doc """
      Determines which fields are visible for the given object and context.

      Uses the legacy policy module approach.
      """
      def __authorize__(object, context, _info) do
        current_user = Map.get(context, :current_user)

        if unquote(policy).can?(current_user, :view, object) do
          :all
        else
          :none
        end
      end

      @doc false
      def __has_authorization__, do: true
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    type_def = Module.get_attribute(env.module, :green_fairy_type)
    fields_def = Module.get_attribute(env.module, :green_fairy_fields) || []
    interfaces_def = Module.get_attribute(env.module, :green_fairy_interfaces) || []
    connections_def = Module.get_attribute(env.module, :green_fairy_connections) || []
    policy_def = Module.get_attribute(env.module, :green_fairy_policy)
    authorize_fn = Module.get_attribute(env.module, :green_fairy_authorize_fn)
    extensions_def = Module.get_attribute(env.module, :green_fairy_extensions) || []
    expose_def = Module.get_attribute(env.module, :green_fairy_expose) || []

    # Generate registration calls for each interface if struct is defined
    registrations =
      if type_def[:struct] do
        Enum.map(interfaces_def, fn interface_module ->
          quote do
            GreenFairy.Registry.register(
              unquote(type_def[:struct]),
              unquote(type_def[:identifier]),
              unquote(interface_module)
            )
          end
        end)
      else
        []
      end

    # Call before_compile on each extension
    extension_config = %{
      module: env.module,
      type_name: type_def[:name],
      type_identifier: type_def[:identifier],
      struct: type_def[:struct]
    }

    extension_callbacks =
      extensions_def
      |> Enum.reverse()
      |> Enum.map(fn ext ->
        if function_exported?(ext, :before_compile, 2) do
          ext.before_compile(env, extension_config)
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    # Generate CQL support automatically for types with structs
    # This makes CQL a core feature, not an opt-in extension
    cql_callback =
      if type_def[:struct] do
        GreenFairy.CQL.before_compile(env, extension_config)
      else
        nil
      end

    # Generate authorization function based on stored authorize_fn or policy
    authorize_impl = generate_authorize_impl(authorize_fn, policy_def)

    quote do
      # Register this type in the TypeRegistry for graph-based discovery
      GreenFairy.TypeRegistry.register(
        unquote(type_def[:identifier]),
        __MODULE__
      )

      # Register this type with the registry for auto resolve_type
      unquote_splicing(registrations)

      # Extension before_compile callbacks
      unquote_splicing(extension_callbacks)

      # CQL support (automatically enabled for types with structs)
      unquote(cql_callback)

      # Authorization implementation
      unquote(authorize_impl)

      @doc false
      def __green_fairy_definition__ do
        %{
          kind: :object,
          name: unquote(type_def[:name]),
          identifier: unquote(type_def[:identifier]),
          struct: unquote(type_def[:struct]),
          interfaces: unquote(Macro.escape(interfaces_def)),
          fields: unquote(Macro.escape(Enum.reverse(fields_def))),
          connections: unquote(Macro.escape(connections_def)),
          policy: unquote(policy_def),
          extensions: unquote(Macro.escape(Enum.reverse(extensions_def)))
        }
      end

      @doc false
      def __green_fairy_kind__ do
        :object
      end

      @doc false
      def __green_fairy_identifier__ do
        unquote(type_def[:identifier])
      end

      @doc false
      def __green_fairy_struct__ do
        unquote(type_def[:struct])
      end

      @doc false
      def __green_fairy_policy__ do
        unquote(policy_def)
      end

      @doc false
      def __green_fairy_extensions__ do
        unquote(Macro.escape(Enum.reverse(extensions_def)))
      end

      @doc false
      def __green_fairy_referenced_types__ do
        unquote(Macro.escape(Module.get_attribute(env.module, :green_fairy_referenced_types) || []))
      end

      @doc false
      def __green_fairy_expose__ do
        unquote(Macro.escape(Enum.reverse(expose_def)))
      end
    end
  end
end

defmodule GreenFairy.Type.DSL do
  @moduledoc false
  # This module is kept for backwards compatibility but is no longer used
  # by the main Type module since we now transform the AST directly.
end
