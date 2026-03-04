defmodule GreenFairy.Schema do
  @moduledoc """
  Schema assembly with graph-based type discovery.

  Automatically discovers types by walking the type graph from your root
  query/mutation/subscription modules.

  ## Basic Usage

      defmodule MyApp.GraphQL.Schema do
        use GreenFairy.Schema,
          query: MyApp.GraphQL.RootQuery,
          mutation: MyApp.GraphQL.RootMutation,
          subscription: MyApp.GraphQL.RootSubscription
      end

  The schema will automatically discover all types reachable from your roots.

  ## Inline Root Definitions

  Or define roots inline:

      defmodule MyApp.GraphQL.Schema do
        use GreenFairy.Schema

        root_query do
          field :health, :string do
            resolve fn _, _, _ -> {:ok, "ok"} end
          end
        end

        root_mutation do
          field :noop, :boolean do
            resolve fn _, _, _ -> {:ok, true} end
          end
        end
      end

  ## Options

  - `:query` - Module to use as root query (or use `root_query` macro)
  - `:mutation` - Module to use as root mutation (or use `root_mutation` macro)
  - `:subscription` - Module to use as root subscription (or use `root_subscription` macro)
  - `:repo` - Ecto repo module for database operations and Node resolution
  - `:global_id` - Custom GlobalId implementation (defaults to `GreenFairy.GlobalId.Base64`)
  - `:dataloader` - DataLoader configuration
    - `:sources` - List of `{source_name, repo_or_source}` tuples

  ## Custom Global IDs

  You can implement custom global ID encoding/decoding:

      defmodule MyApp.CustomGlobalId do
        @behaviour GreenFairy.GlobalId

        @impl true
        def encode(type_name, id), do: # your encoding

        @impl true
        def decode(global_id), do: # your decoding
      end

      use GreenFairy.Schema,
        query: MyApp.RootQuery,
        repo: MyApp.Repo,
        global_id: MyApp.CustomGlobalId

  ## Type Discovery

  Types are discovered by walking the graph from your root modules:
  1. Start at Query/Mutation/Subscription modules
  2. Extract type references from field definitions
  3. Recursively follow references to discover all reachable types
  4. Only import types actually used in your schema

  This means:
  - Types can live anywhere in your codebase
  - Unused types are not imported
  - Clear dependency graph
  - Supports circular references

  """

  @doc false
  defmacro __using__(opts) do
    dataloader_opts = Keyword.get(opts, :dataloader, [])
    repo_ast = Keyword.get(opts, :repo)
    cql_adapter_ast = Keyword.get(opts, :cql_adapter)
    global_id_ast = Keyword.get(opts, :global_id)
    query_module_ast = Keyword.get(opts, :query)
    mutation_module_ast = Keyword.get(opts, :mutation)
    subscription_module_ast = Keyword.get(opts, :subscription)

    # Expand module aliases to actual atoms
    repo = if repo_ast, do: Macro.expand(repo_ast, __CALLER__), else: nil
    cql_adapter = if cql_adapter_ast, do: Macro.expand(cql_adapter_ast, __CALLER__), else: nil
    global_id = if global_id_ast, do: Macro.expand(global_id_ast, __CALLER__), else: nil
    query_module = if query_module_ast, do: Macro.expand(query_module_ast, __CALLER__), else: nil
    mutation_module = if mutation_module_ast, do: Macro.expand(mutation_module_ast, __CALLER__), else: nil
    subscription_module = if subscription_module_ast, do: Macro.expand(subscription_module_ast, __CALLER__), else: nil

    # Generate import_types for explicit modules NOW (in __using__)
    # Query block is deferred to __before_compile__ so expose fields can be included
    explicit_imports = generate_using_imports(query_module, mutation_module, subscription_module)
    # Only mutation and subscription blocks are generated here - query is deferred
    mutation_block = generate_using_mutation_block(mutation_module)
    subscription_block = generate_using_subscription_block(subscription_module)

    quote do
      # Store configuration FIRST for use in callbacks
      @green_fairy_dataloader unquote(Macro.escape(dataloader_opts))
      @green_fairy_repo unquote(repo)
      @green_fairy_cql_adapter unquote(cql_adapter)
      @green_fairy_global_id unquote(global_id)
      @green_fairy_query_module unquote(query_module)
      @green_fairy_mutation_module unquote(mutation_module)
      @green_fairy_subscription_module unquote(subscription_module)

      # For inline root definitions
      Module.register_attribute(__MODULE__, :green_fairy_inline_query, accumulate: false)
      Module.register_attribute(__MODULE__, :green_fairy_inline_mutation, accumulate: false)
      Module.register_attribute(__MODULE__, :green_fairy_inline_subscription, accumulate: false)

      # Register our before_compile FIRST so it runs before Absinthe's
      @before_compile GreenFairy.Schema

      # Now use Absinthe.Schema (which registers its own @before_compile that runs after ours)
      use Absinthe.Schema

      # Import Absinthe's built-in custom scalars (naive_datetime, datetime, date, time)
      # TODO: Replace with GreenFairy's own enhanced scalar definitions
      import_types Absinthe.Type.Custom

      # Import GreenFairy built-in types
      import_types GreenFairy.BuiltIns.PageInfo
      import_types GreenFairy.BuiltIns.UnauthorizedBehavior
      import_types GreenFairy.BuiltIns.OnUnauthorizedDirective

      # Import explicit root modules (must happen before query/mutation/subscription blocks)
      unquote_splicing(explicit_imports)

      # Query block is generated in __before_compile__ to include expose fields
      # Only mutation and subscription are generated here
      unquote(mutation_block)
      unquote(subscription_block)

      # Add visibility filtering phase to the Absinthe pipeline.
      # Absinthe skips middleware/3 for built-in introspection types,
      # so we insert a custom phase after Document.Result instead.
      #
      # pipeline/2 is used by Absinthe.Plug for HTTP requests.
      # run/2 is a helper for direct execution (tests, scripts).
      def pipeline(config, opts) do
        config
        |> Absinthe.Pipeline.for_document(opts)
        |> GreenFairy.Introspection.add_filter_phase()
      end

      defoverridable pipeline: 2

      @doc """
      Execute a GraphQL query against this schema with visibility filtering.

      Use this instead of `Absinthe.run/3` to ensure introspection visibility
      filtering is applied. Same API as `Absinthe.run/3` but without the
      schema argument.

          {:ok, result} = MySchema.run("{ __type(name: \\"User\\") { fields { name } } }",
            context: %{current_user: admin}
          )
      """
      def run(document, opts \\ []) do
        Absinthe.run(
          document,
          __MODULE__,
          Keyword.put(opts, :pipeline_modifier, &GreenFairy.Introspection.pipeline_modifier/2)
        )
      end

      import GreenFairy.Schema, only: [root_query: 1, root_mutation: 1, root_subscription: 1]
    end
  end

  # Helper functions for __using__ macro (run at compile time of calling code)
  defp generate_using_imports(query_module, mutation_module, subscription_module) do
    [query_module, mutation_module, subscription_module]
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn module ->
      quote do
        import_types unquote(module)
      end
    end)
  end

  defp generate_using_mutation_block(nil), do: nil

  defp generate_using_mutation_block(module) do
    identifier = module.__green_fairy_mutation_fields_identifier__()

    quote do
      mutation do
        import_fields unquote(identifier)
      end
    end
  end

  defp generate_using_subscription_block(nil), do: nil

  defp generate_using_subscription_block(module) do
    identifier = module.__green_fairy_subscription_fields_identifier__()

    quote do
      subscription do
        import_fields unquote(identifier)
      end
    end
  end

  @doc """
  Define inline query fields for this schema.

      root_query do
        field :health, :string do
          resolve fn _, _, _ -> {:ok, "ok"} end
        end
      end

  """
  defmacro root_query(do: block) do
    quote do
      @green_fairy_inline_query unquote(Macro.escape(block))
    end
  end

  @doc """
  Define inline mutation fields for this schema.

      root_mutation do
        field :noop, :boolean do
          resolve fn _, _, _ -> {:ok, true} end
        end
      end

  """
  defmacro root_mutation(do: block) do
    quote do
      @green_fairy_inline_mutation unquote(Macro.escape(block))
    end
  end

  @doc """
  Define inline subscription fields for this schema.

      root_subscription do
        field :events, :event do
          config fn _, _ -> {:ok, topic: "*"} end
        end
      end

  """
  defmacro root_subscription(do: block) do
    quote do
      @green_fairy_inline_subscription unquote(Macro.escape(block))
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    dataloader_opts = Module.get_attribute(env.module, :green_fairy_dataloader)
    repo = Module.get_attribute(env.module, :green_fairy_repo)
    global_id = Module.get_attribute(env.module, :green_fairy_global_id)

    # Get explicit module configurations
    query_module = Module.get_attribute(env.module, :green_fairy_query_module)
    mutation_module = Module.get_attribute(env.module, :green_fairy_mutation_module)
    subscription_module = Module.get_attribute(env.module, :green_fairy_subscription_module)

    # Get inline definitions
    inline_query = Module.get_attribute(env.module, :green_fairy_inline_query)
    inline_mutation = Module.get_attribute(env.module, :green_fairy_inline_mutation)
    inline_subscription = Module.get_attribute(env.module, :green_fairy_inline_subscription)

    # Graph-based discovery from explicit roots
    root_modules =
      [query_module, mutation_module, subscription_module]
      |> Enum.reject(&is_nil/1)

    # Ensure all root modules are compiled first
    Enum.each(root_modules, &Code.ensure_compiled!/1)

    discovered = discover_via_graph(root_modules)

    # Ensure all discovered modules are compiled
    # This is necessary because type modules might not be compiled yet
    discovered =
      Enum.filter(discovered, fn module ->
        case Code.ensure_compiled(module) do
          {:module, _} -> true
          _ -> false
        end
      end)

    grouped = GreenFairy.Discovery.group_by_kind(discovered)

    # Generate import_types for all discovered modules
    import_statements = generate_imports(grouped)

    # Collect expose definitions from discovered object types
    expose_fields = collect_expose_fields(discovered, repo)

    # Note: Explicit root modules are handled in __using__, not here
    # Here we only handle inline definitions and auto-discovered modules

    # Generate root operation types for inline and discovered ONLY (explicit handled in __using__)
    # Only generate if there's no explicit module (explicit modules are handled in __using__)
    query_block =
      generate_before_compile_root_block(:query, query_module, inline_query, grouped[:queries] || [], expose_fields)

    mutation_block =
      generate_before_compile_root_block(:mutation, mutation_module, inline_mutation, grouped[:mutations] || [])

    subscription_block =
      generate_before_compile_root_block(
        :subscription,
        subscription_module,
        inline_subscription,
        grouped[:subscriptions] || []
      )

    # Generate dataloader context if configured
    dataloader_context = generate_dataloader_context(dataloader_opts, repo, global_id)

    # Generate CQL types for all CQL-enabled types
    cql_types_statements = generate_cql_types(discovered, env.module)

    # Build all statements as a list, filtering out nils and non-AST values
    statements =
      [
        cql_types_statements,
        import_statements,
        [query_block],
        [mutation_block],
        [subscription_block],
        [dataloader_context],
        [
          quote do
            @doc false
            def __green_fairy_discovered__ do
              unquote(Macro.escape(discovered))
            end
          end
        ]
      ]
      |> List.flatten()
      |> Enum.reject(&is_nil/1)
      |> Enum.filter(&is_tuple/1)

    {:__block__, [], statements}
  end

  # Generate CQL types (operator inputs, filter inputs, order inputs) for all CQL-enabled types
  defp generate_cql_types(discovered, schema_module) do
    # Filter to CQL-enabled types
    cql_types =
      discovered
      |> Enum.filter(fn module ->
        Code.ensure_loaded?(module) and function_exported?(module, :__cql_config__, 0)
      end)

    # If no CQL types, return empty
    if cql_types == [] do
      []
    else
      # Detect adapter from the schema's configuration
      adapter = Module.get_attribute(schema_module, :green_fairy_cql_adapter)
      adapter = adapter || detect_cql_adapter(schema_module)

      # Generate CQL types module name
      # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
      cql_types_module = Module.concat(schema_module, CqlTypes)

      # Generate operator types and order base types
      order_base_types_ast = GreenFairy.CQL.Schema.OrderInput.generate_base_types()
      operator_types_ast = GreenFairy.CQL.Schema.OperatorInput.generate_all(adapter: adapter)
      base_types_ast = operator_types_ast ++ order_base_types_ast

      # Collect enums used by CQL types
      used_enums = collect_cql_enums(cql_types)
      enum_operator_asts = generate_cql_enum_operator_asts(used_enums)

      # Generate filter and order input ASTs for all CQL types
      filter_asts =
        cql_types
        |> Enum.filter(&function_exported?(&1, :__cql_generate_filter_input__, 0))
        |> Enum.map(& &1.__cql_generate_filter_input__())

      order_asts =
        cql_types
        |> Enum.filter(&function_exported?(&1, :__cql_generate_order_input__, 0))
        |> Enum.map(& &1.__cql_generate_order_input__())

      all_type_asts = enum_operator_asts ++ filter_asts ++ order_asts

      [
        # Define CQL types module inline
        quote do
          defmodule unquote(cql_types_module) do
            @moduledoc false
            use Absinthe.Schema.Notation

            unquote_splicing(base_types_ast)
          end
        end,
        # Import the generated types
        quote do
          import_types(unquote(cql_types_module))
        end,
        # Import period types for datetime operators
        # Each import_types is separate to ensure proper macro expansion
        quote do
          import_types(GreenFairy.CQL.Scalars.DateTime.PeriodDirection)
        end,
        quote do
          import_types(GreenFairy.CQL.Scalars.DateTime.PeriodUnit)
        end,
        quote do
          import_types(GreenFairy.CQL.Scalars.DateTime.PeriodInput)
        end,
        quote do
          import_types(GreenFairy.CQL.Scalars.DateTime.CurrentPeriodInput)
        end
        # Inject filter/order types directly into schema
      ] ++ all_type_asts
    end
  end

  defp detect_cql_adapter(schema_module) do
    repo = Module.get_attribute(schema_module, :green_fairy_repo)

    if repo do
      GreenFairy.CQL.Adapter.detect_adapter(repo)
    else
      repo = Application.get_env(:green_fairy, :repo)

      if repo do
        GreenFairy.CQL.Adapter.detect_adapter(repo)
      else
        GreenFairy.CQL.Adapters.Postgres
      end
    end
  end

  defp collect_cql_enums(cql_types) do
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

  defp generate_cql_enum_operator_asts(enum_identifiers) do
    Enum.flat_map(enum_identifiers, fn enum_id ->
      scalar_ast = GreenFairy.CQL.Schema.EnumOperatorInput.generate(enum_id)
      array_ast = GreenFairy.CQL.Schema.EnumOperatorInput.generate_array(enum_id)
      [scalar_ast, array_ast]
    end)
  end

  # Collect expose definitions from discovered object types
  defp collect_expose_fields(discovered, repo) do
    discovered
    |> Enum.filter(fn module ->
      function_exported?(module, :__green_fairy_expose__, 0) and
        module.__green_fairy_expose__() != []
    end)
    |> Enum.flat_map(fn module ->
      type_def = module.__green_fairy_definition__()
      expose_defs = module.__green_fairy_expose__()

      Enum.map(expose_defs, fn expose_def ->
        Map.merge(expose_def, %{
          type_module: module,
          type_name: type_def[:name],
          type_identifier: type_def[:identifier],
          struct_module: type_def[:struct],
          repo: repo
        })
      end)
    end)
  end

  # Generate root block for __before_compile__ - skips if explicit module exists
  # (explicit modules are handled in __using__)
  defp generate_before_compile_root_block(
         _type,
         explicit_module,
         _inline_block,
         _discovered_modules,
         _expose_fields \\ []
       )

  # For non-query types with explicit module, return nil (handled in __using__)
  defp generate_before_compile_root_block(type, explicit_module, _inline_block, _discovered_modules, _expose_fields)
       when not is_nil(explicit_module) and type != :query do
    nil
  end

  defp generate_before_compile_root_block(:query, explicit_module, inline_block, discovered_modules, expose_fields) do
    # Generate expose fields AST
    expose_ast = generate_expose_query_fields(expose_fields)

    cond do
      # Explicit module - generate query block with both import_fields and expose fields
      not is_nil(explicit_module) ->
        generate_query_with_explicit_and_expose(explicit_module, expose_ast)

      inline_block != nil ->
        # Combine inline with expose fields
        combined = combine_query_blocks(inline_block, expose_ast)
        generate_root_from_inline(:query, combined)

      discovered_modules != [] or expose_fields != [] ->
        # Combine discovered with expose fields
        generate_root_from_discovered_with_expose(:query, discovered_modules, expose_ast)

      true ->
        nil
    end
  end

  # Handle non-query types (mutation, subscription) with inline or discovered modules
  defp generate_before_compile_root_block(type, _explicit_module, inline_block, discovered_modules, _expose_fields) do
    cond do
      inline_block != nil ->
        generate_root_from_inline(type, inline_block)

      discovered_modules != [] ->
        generate_root_from_discovered(type, discovered_modules)

      true ->
        nil
    end
  end

  # Generate query block with explicit module import_fields and expose fields
  # IMPORTANT: expose fields must come BEFORE import_fields to avoid unused literal warnings
  # This appears to be an Absinthe/Elixir quirk with how import_fields interacts with
  # subsequent statements in the same block
  defp generate_query_with_explicit_and_expose(explicit_module, nil) do
    identifier = explicit_module.__green_fairy_query_fields_identifier__()

    quote do
      query do
        import_fields unquote(identifier)
      end
    end
  end

  defp generate_query_with_explicit_and_expose(explicit_module, {:__block__, _, expose_statements}) do
    identifier = explicit_module.__green_fairy_query_fields_identifier__()

    quote do
      query do
        unquote_splicing(expose_statements)
        import_fields unquote(identifier)
      end
    end
  end

  # Generate query fields for expose definitions
  defp generate_expose_query_fields([]), do: nil

  defp generate_expose_query_fields(expose_fields) do
    field_asts =
      Enum.map(expose_fields, fn expose_def ->
        field_name = expose_def.field
        type_name = expose_def.type_name
        type_identifier = expose_def.type_identifier
        struct_module = expose_def.struct_module
        repo = expose_def.repo
        opts = expose_def.opts || []
        arg_type = get_field_type_from_adapter(struct_module, field_name)

        # Determine query field name
        query_field_name =
          if field_name == :id do
            Keyword.get(opts, :as, type_identifier)
          else
            # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
            Keyword.get(opts, :as, :"#{type_identifier}_by_#{field_name}")
          end

        quote do
          field unquote(query_field_name), unquote(type_identifier) do
            arg(unquote(field_name), non_null(unquote(arg_type)))

            resolve(fn _, args, ctx ->
              field_value = Map.get(args, unquote(field_name))
              struct_mod = unquote(struct_module)
              repo_mod = Map.get(ctx, :repo) || unquote(repo)

              result =
                if unquote(field_name) == :id do
                  case GreenFairy.GlobalId.decode_id(field_value) do
                    {:ok, {_, local_id}} -> repo_mod.get(struct_mod, local_id)
                    {:error, _} -> repo_mod.get(struct_mod, field_value)
                  end
                else
                  repo_mod.get_by(struct_mod, [{unquote(field_name), field_value}])
                end

              case result do
                nil -> {:error, "#{unquote(type_name)} not found"}
                record -> {:ok, record}
              end
            end)
          end
        end
      end)

    {:__block__, [], field_asts}
  end

  # Get field type from the struct's adapter
  defp get_field_type_from_adapter(nil, _field), do: :string

  defp get_field_type_from_adapter(struct_module, field) do
    adapter = GreenFairy.Adapter.find_adapter(struct_module, nil)

    if adapter && function_exported?(adapter, :field_type, 2) do
      case adapter.field_type(struct_module, field) do
        :id -> :id
        :integer -> :integer
        :string -> :string
        :boolean -> :boolean
        {:parameterized, Ecto.UUID, _} -> :id
        Ecto.UUID -> :id
        _ -> :string
      end
    else
      # Default to :id for :id field, :string otherwise
      if field == :id, do: :id, else: :string
    end
  end

  defp combine_query_blocks(inline_block, nil), do: inline_block
  defp combine_query_blocks(inline_block, {:__block__, _, []}), do: inline_block

  defp combine_query_blocks({:__block__, meta, statements}, {:__block__, _, expose_statements}) do
    {:__block__, meta, statements ++ expose_statements}
  end

  defp combine_query_blocks(single_statement, {:__block__, _, expose_statements}) do
    {:__block__, [], [single_statement | expose_statements]}
  end

  defp generate_root_from_discovered_with_expose(:query, discovered_modules, expose_ast) do
    quote do
      query do
        unquote_splicing(
          Enum.map(discovered_modules, fn module ->
            quote do
              import_fields(unquote(module).__green_fairy_query_fields_identifier__())
            end
          end)
        )

        unquote(expose_ast)
      end
    end
  end

  defp generate_root_from_inline(:query, block) do
    quote do
      query do
        unquote(block)
      end
    end
  end

  defp generate_root_from_inline(:mutation, block) do
    quote do
      mutation do
        unquote(block)
      end
    end
  end

  defp generate_root_from_inline(:subscription, block) do
    quote do
      subscription do
        unquote(block)
      end
    end
  end

  # Note: :query is handled by generate_root_from_discovered_with_expose/3
  # which supports both discovered modules and expose fields

  defp generate_root_from_discovered(:mutation, modules) do
    import_statements =
      Enum.map(modules, fn _module ->
        quote do
          import_fields :green_fairy_mutations
        end
      end)

    quote do
      mutation do
        (unquote_splicing(import_statements))
      end
    end
  end

  defp generate_root_from_discovered(:subscription, modules) do
    import_statements =
      Enum.map(modules, fn _module ->
        quote do
          import_fields :green_fairy_subscriptions
        end
      end)

    quote do
      subscription do
        (unquote_splicing(import_statements))
      end
    end
  end

  # Discover types by walking the type graph from root modules
  # Dialyzer has trouble with MapSet opaque type through recursive calls
  @dialyzer {:nowarn_function, discover_via_graph: 1}
  defp discover_via_graph(root_modules) do
    walk_type_graph(root_modules, MapSet.new())
    |> MapSet.to_list()
  end

  # Walk the type graph recursively, collecting all reachable types
  # Dialyzer has trouble tracking MapSet opaque type through recursive calls
  @dialyzer {:nowarn_function, walk_type_graph: 2}
  defp walk_type_graph([], visited), do: visited

  defp walk_type_graph([module | rest], visited) when is_atom(module) do
    if MapSet.member?(visited, module) do
      # Already visited, skip
      walk_type_graph(rest, visited)
    else
      # Mark as visited
      visited = MapSet.put(visited, module)

      # Get referenced types from this module
      referenced =
        if function_exported?(module, :__green_fairy_referenced_types__, 0) do
          module.__green_fairy_referenced_types__()
          |> Enum.map(&resolve_type_reference/1)
          |> Enum.reject(&is_nil/1)
        else
          []
        end

      # Recursively walk referenced types
      walk_type_graph(referenced ++ rest, visited)
    end
  end

  # Skip non-module references
  defp walk_type_graph([_non_module | rest], visited) do
    walk_type_graph(rest, visited)
  end

  # Resolve a type reference to a module
  # Handles both atom identifiers (:user) and module references (MyApp.Types.User)
  defp resolve_type_reference(ref) when is_atom(ref) do
    # Check if it's already a module with __green_fairy_definition__
    if Code.ensure_loaded?(ref) and function_exported?(ref, :__green_fairy_definition__, 0) do
      ref
    else
      # It's a type identifier, look it up in the registry
      GreenFairy.TypeRegistry.lookup_module(ref)
    end
  end

  # Module alias AST - expand to module atom
  defp resolve_type_reference({:__aliases__, _, _} = module_ast) do
    Macro.expand(module_ast, __ENV__)
  rescue
    _ -> nil
  end

  defp resolve_type_reference(_), do: nil

  defp generate_imports(grouped) do
    all_modules =
      (grouped[:types] || []) ++
        (grouped[:interfaces] || []) ++
        (grouped[:inputs] || []) ++
        (grouped[:enums] || []) ++
        (grouped[:unions] || []) ++
        (grouped[:scalars] || []) ++
        (grouped[:queries] || []) ++
        (grouped[:mutations] || []) ++
        (grouped[:subscriptions] || [])

    Enum.map(all_modules, fn module ->
      quote do
        import_types unquote(module)
      end
    end)
  end

  defp generate_dataloader_context([], repo, global_id) do
    # Always generate default context, plugins, and node_name for GreenFairy schemas
    # Users can override these by defining their own functions
    quote do
      # Default context that sets up an empty dataloader and includes repo for Node resolution
      def context(ctx) do
        loader = Dataloader.new()

        ctx
        |> Map.put(:loader, loader)
        |> Map.put(:repo, unquote(repo))
        |> Map.put(:global_id, unquote(global_id) || GreenFairy.GlobalId.Base64)
      end

      def plugins do
        [Absinthe.Middleware.Dataloader | Absinthe.Plugin.defaults()]
      end

      # Required for Absinthe.Subscription in distributed environments
      def node_name do
        node()
      end

      @doc false
      def __green_fairy_repo__ do
        unquote(repo)
      end

      @doc false
      def __green_fairy_global_id__ do
        unquote(global_id) || GreenFairy.GlobalId.Base64
      end
    end
  end

  defp generate_dataloader_context(opts, repo, global_id) do
    sources = Keyword.get(opts, :sources, [])

    if sources == [] do
      generate_dataloader_context([], repo, global_id)
    else
      quote do
        def context(ctx) do
          loader =
            Dataloader.new()
            |> Dataloader.add_source(:repo, Dataloader.Ecto.new(unquote(hd(sources))))

          ctx
          |> Map.put(:loader, loader)
          |> Map.put(:repo, unquote(repo))
          |> Map.put(:global_id, unquote(global_id) || GreenFairy.GlobalId.Base64)
        end

        def plugins do
          [Absinthe.Middleware.Dataloader | Absinthe.Plugin.defaults()]
        end

        # Required for Absinthe.Subscription in distributed environments
        def node_name do
          node()
        end

        @doc false
        def __green_fairy_repo__ do
          unquote(repo)
        end

        @doc false
        def __green_fairy_global_id__ do
          unquote(global_id) || GreenFairy.GlobalId.Base64
        end
      end
    end
  end

  @doc """
  Generates resolve_type function for an interface based on discovered implementors.

  This can be called manually or used by the schema to auto-generate
  resolve_type functions for interfaces.

  ## Example

      def resolve_type(value, _) do
        GreenFairy.Schema.resolve_type_for(value, %{
          MyApp.User => :user,
          MyApp.Post => :post
        })
      end

  """
  def resolve_type_for(value, struct_mapping) when is_map(value) do
    case Map.get(value, :__struct__) do
      nil -> nil
      struct_module -> Map.get(struct_mapping, struct_module)
    end
  end

  def resolve_type_for(_, _), do: nil
end
