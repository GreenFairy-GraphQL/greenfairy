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

      import GreenFairy.Type, only: [type: 2, type: 3, authorize: 1]
      import GreenFairy.Field.Connection, only: [connection: 2, connection: 3]
      # loader is only available inside has_many/has_one/belongs_to blocks
      # field blocks should use resolve for custom logic

      Module.register_attribute(__MODULE__, :green_fairy_type, accumulate: false)
      Module.register_attribute(__MODULE__, :green_fairy_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :green_fairy_interfaces, accumulate: true)
      Module.register_attribute(__MODULE__, :green_fairy_connections, accumulate: true)
      Module.register_attribute(__MODULE__, :green_fairy_policy, accumulate: false)
      Module.register_attribute(__MODULE__, :green_fairy_authorize_fn, accumulate: false)
      Module.register_attribute(__MODULE__, :green_fairy_extensions, accumulate: true)

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

    # Extract connection definitions from the block FIRST
    connection_defs = extract_connections(block, env)

    # Generate connection types (these need to be defined before the main object)
    connection_types = generate_connection_types_ast(connection_defs)

    # Transform the block - this removes connection definitions and leaves field references
    transformed_block = transform_block(block, env)

    quote do
      @green_fairy_type %{
        kind: :object,
        name: unquote(name),
        identifier: unquote(identifier),
        struct: unquote(opts[:struct]),
        description: unquote(opts[:description])
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

    {edge_block, connection_fields} = GreenFairy.Field.Connection.parse_connection_block(block)

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
  defp transform_block({:__block__, meta, statements}, env) do
    transformed = Enum.map(statements, &transform_statement(&1, env))
    {:__block__, meta, transformed}
  end

  defp transform_block(statement, env) do
    transform_statement(statement, env)
  end

  defp transform_statement({:implements, _meta, [interface_module_ast]}, env) do
    # Expand the module reference to get the actual module
    interface_module = Macro.expand(interface_module_ast, env)
    interface_identifier = interface_module.__green_fairy_identifier__()

    quote do
      @green_fairy_interfaces unquote(interface_module)
      Absinthe.Schema.Notation.interface(unquote(interface_identifier))
    end
  end

  # Transform authorize declaration - old style with policy module
  defp transform_statement({:authorize, _meta, [[with: policy_module]]}, _env) do
    quote do
      @green_fairy_policy unquote(policy_module)
    end
  end

  # Transform authorize declaration - new style with function
  defp transform_statement({:authorize, _meta, [func]}, _env) when not is_list(func) do
    quote do
      @green_fairy_authorize_fn unquote(Macro.escape(func))
    end
  end

  # Transform loader macro inside field blocks - converts to batch resolver
  defp transform_statement({:loader, _meta, [func]}, _env) do
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

  # Transform connection fields - emit only the field reference
  # The connection types are generated in the type macro before the main object
  defp transform_statement({:connection, _meta, args}, _env) do
    {field_name, _type_module_or_opts, _block} = parse_connection_args(args)
    connection_name = :"#{field_name}_connection"

    quote do
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
  defp transform_statement({:use, _meta, [module_ast | rest]}, env) do
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
  defp transform_statement({:field, meta, args}, _env) do
    {field_name, field_type, opts, has_resolver} = parse_field_args(args)

    field_info = %{
      name: field_name,
      type: field_type,
      opts: opts,
      resolver: has_resolver || false
    }

    quote do
      @green_fairy_fields unquote(Macro.escape(field_info))
      unquote({:field, meta, args})
    end
  end

  # Pass through everything else unchanged - let Absinthe handle it
  defp transform_statement(other, _env), do: other

  # Parse field arguments into components
  defp parse_field_args([name]), do: {name, nil, [], nil}

  defp parse_field_args([name, type]) when not is_list(type) do
    {base_type, type_opts} = unwrap_type(type)
    {name, base_type, type_opts, nil}
  end

  defp parse_field_args([name, opts]) when is_list(opts) do
    case Keyword.get(opts, :do) do
      nil -> {name, nil, opts, nil}
      _block -> {name, nil, [], nil}
    end
  end

  defp parse_field_args([name, type, opts]) when is_list(opts) do
    case Keyword.pop(opts, :do) do
      {nil, rest_opts} ->
        {base_type, type_opts} = unwrap_type(type)
        {name, base_type, Keyword.merge(type_opts, rest_opts), nil}

      {block, rest_opts} ->
        resolver = has_resolver?(block)
        {base_type, type_opts} = unwrap_type(type)
        {name, base_type, Keyword.merge(type_opts, rest_opts), resolver}
    end
  end

  defp parse_field_args([name, type, opts, block_opts]) when is_list(opts) and is_list(block_opts) do
    block = Keyword.get(block_opts, :do)
    resolver = has_resolver?(block)
    {base_type, type_opts} = unwrap_type(type)
    {name, base_type, Keyword.merge(type_opts, opts), resolver}
  end

  defp parse_field_args(args) when is_list(args) do
    # Fallback for any other format
    name = List.first(args)

    if length(args) > 1 do
      {base_type, type_opts} = unwrap_type(Enum.at(args, 1))
      {name, base_type, type_opts, nil}
    else
      {name, nil, [], nil}
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

        case :erlang.fun_info(auth_fn, :arity) do
          {:arity, 2} -> auth_fn.(object, context)
          {:arity, 3} -> auth_fn.(object, context, info)
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

    # Generate authorization function based on stored authorize_fn or policy
    authorize_impl = generate_authorize_impl(authorize_fn, policy_def)

    quote do
      # Register this type with the registry for auto resolve_type
      unquote_splicing(registrations)

      # Extension before_compile callbacks
      unquote_splicing(extension_callbacks)

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
    end
  end
end

defmodule GreenFairy.Type.DSL do
  @moduledoc false
  # This module is kept for backwards compatibility but is no longer used
  # by the main Type module since we now transform the AST directly.
end
