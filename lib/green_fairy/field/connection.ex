defmodule GreenFairy.Field.Connection do
  @moduledoc """
  Connection support for Relay-style pagination.

  This module provides macros for defining connections with
  auto-generated Connection and Edge types.

  ## Usage

      type "User", struct: MyApp.User do
        connection :friends, MyApp.GraphQL.Types.User do
          edge do
            field :friendship_date, :datetime
          end
          field :total_count, :integer
        end
      end

  """

  @doc """
  Generates a connection field with auto-generated Connection and Edge types.

  ## Options

  - `:node` - The node type identifier (defaults to the type_module's identifier)
  - `:resolve` - Custom resolver function

  """
  defmacro connection(field_name, type_module_or_opts \\ [], do: block) do
    {type_module, opts} =
      case type_module_or_opts do
        opts when is_list(opts) -> {nil, opts}
        module -> {module, []}
      end

    quote do
      require GreenFairy.Field.Connection

      GreenFairy.Field.Connection.__define_connection__(
        unquote(field_name),
        unquote(type_module),
        unquote(opts),
        unquote(Macro.escape(block))
      )
    end
  end

  @doc false
  defmacro __define_connection__(field_name, type_module, opts, block) do
    env = __CALLER__

    type_module_expanded =
      if type_module do
        Macro.expand(type_module, env)
      else
        nil
      end

    type_identifier =
      if type_module_expanded do
        type_module_expanded.__green_fairy_identifier__()
      else
        opts[:node]
      end

    connection_name = :"#{field_name}_connection"
    edge_name = :"#{field_name}_edge"

    # Parse the block to extract edge definition, extra fields, custom resolver, and aggregates
    {edge_block, connection_fields, custom_resolver, aggregates} = parse_connection_block(block)

    # Store the connection definition for deferred generation in __before_compile__
    connection_def = %{
      field_name: field_name,
      type_identifier: type_identifier,
      type_module: type_module_expanded,
      connection_name: connection_name,
      edge_name: edge_name,
      edge_block: edge_block,
      connection_fields: connection_fields,
      custom_resolver: custom_resolver,
      aggregates: aggregates
    }

    quote do
      # Store connection definition for deferred type generation
      @green_fairy_connections unquote(Macro.escape(connection_def))

      # Only emit the field reference inline - types are generated in __before_compile__
      field unquote(field_name), unquote(connection_name) do
        arg :first, :integer
        arg :after, :string
        arg :last, :integer
        arg :before, :string

        # Add CQL filter and order args automatically
        # The type will be determined from the node type's CQL config
        unquote(build_cql_args(type_module_expanded, type_identifier))

        # Add automatic resolver for association connections
        unquote(build_connection_resolver(field_name, type_module_expanded, custom_resolver, aggregates))
      end
    end
  end

  # Build CQL args (where and orderBy) for the connection
  defp build_cql_args(type_module, _type_identifier) when not is_nil(type_module) do
    quote do
      # Dynamically determine filter/order input types from the node type
      # These will be generated when the schema compiles
      if Code.ensure_loaded?(unquote(type_module)) and
         function_exported?(unquote(type_module), :__cql_filter_input_identifier__, 0) do
        filter_type = unquote(type_module).__cql_filter_input_identifier__()
        arg :where, filter_type
      end

      if Code.ensure_loaded?(unquote(type_module)) and
         function_exported?(unquote(type_module), :__cql_order_input_identifier__, 0) do
        order_type = unquote(type_module).__cql_order_input_identifier__()
        arg :order_by, list_of(order_type)
      end
    end
  end

  defp build_cql_args(_type_module, _type_identifier), do: nil

  # Build automatic resolver for association connections
  # If custom_resolver is provided, use that instead
  defp build_connection_resolver(_field_name, _type_module, custom_resolver, _aggregates)
       when not is_nil(custom_resolver) do
    # Custom resolver provided - use it
    custom_resolver
  end

  defp build_connection_resolver(field_name, type_module, _custom_resolver, aggregates)
       when not is_nil(type_module) do
    # No custom resolver - try to detect association and auto-generate resolver
    aggregates_escaped = Macro.escape(aggregates)

    quote do
      # This will be evaluated in the context of the type module
      # We check at runtime if field_name is an association
      struct_module = __green_fairy_struct__()

      if struct_module && Code.ensure_loaded?(struct_module) &&
           function_exported?(struct_module, :__schema__, 2) do
        case struct_module.__schema__(:association, unquote(field_name)) do
          nil ->
            # Not an association - user must provide custom resolver
            nil

          %Ecto.Association.HasThrough{} ->
            # has_through not supported
            nil

          assoc ->
            # Found association - use automatic resolver with parent filtering
            resolve(fn parent, args, resolution ->
              repo = resolution.context[:repo]

              # Extract related_key from association
              related_key =
                case assoc do
                  %{related_key: key} -> key
                  %{related: related} -> hd(related.__schema__(:primary_key))
                end

              if repo do
                opts = [
                  repo: repo,
                  owner_key: assoc.owner_key,
                  related_key: related_key,
                  queryable: unquote(type_module).__green_fairy_struct__(),
                  type_module: unquote(type_module)
                ]

                # Add aggregates if present
                opts = if unquote(aggregates_escaped) do
                  Keyword.put(opts, :aggregates, unquote(aggregates_escaped))
                else
                  opts
                end

                GreenFairy.Field.ConnectionResolver.resolve_association_connection(
                  parent,
                  args,
                  resolution,
                  opts
                )
              else
                {:error, "No repo in context. Add repo: YourRepo to context."}
              end
            end)
        end
      else
        # No struct module - user must provide custom resolver
        nil
      end
    end
  end

  defp build_connection_resolver(_field_name, _type_module, _custom_resolver, _aggregates) do
    # No type module and no custom resolver - will need manual resolver
    nil
  end

  @doc """
  Generates the edge and connection object types from stored connection definitions.

  Called from Type.__before_compile__ to generate types at module top-level.
  """
  def generate_connection_types(connections) do
    Enum.flat_map(connections, fn conn ->
      edge_type = generate_edge_type(conn)
      connection_type = generate_connection_type(conn)

      # Generate aggregate types if aggregates are defined
      aggregate_types = if conn.aggregates do
        # Extract type name from connection name
        # e.g., :engagements_connection -> "engagement"
        type_name = conn.field_name |> Atom.to_string() |> String.trim_trailing("s")

        alias GreenFairy.Field.ConnectionAggregate
        ConnectionAggregate.generate_aggregate_types(
          conn.connection_name,
          type_name,
          conn.aggregates
        )
      else
        []
      end

      [edge_type, connection_type | aggregate_types]
    end)
  end

  defp generate_edge_type(conn) do
    edge_name = conn.edge_name
    type_identifier = conn.type_identifier
    edge_block = conn.edge_block

    quote do
      Absinthe.Schema.Notation.object unquote(edge_name) do
        field :node, unquote(type_identifier)
        field :cursor, non_null(:string)
        unquote(edge_block)
      end
    end
  end

  defp generate_connection_type(conn) do
    connection_name = conn.connection_name
    edge_name = conn.edge_name
    type_identifier = conn.type_identifier
    connection_fields = conn.connection_fields
    aggregates = conn.aggregates

    # Generate aggregate field if aggregates are defined
    aggregate_field = if aggregates do
      type_name = conn.field_name |> Atom.to_string() |> String.trim_trailing("s")
      aggregate_type = :"#{type_name}_aggregate"

      quote do
        # Aggregate field with deferred loading support
        @desc "Aggregate values across all items (ignoring pagination)"
        field :aggregate, unquote(aggregate_type) do
          resolve(fn parent, _, _ ->
            alias GreenFairy.Field.ConnectionAggregate

            sum_result = if parent[:_sum_fns] do
              Map.new(parent._sum_fns, fn {field, fn_value} ->
                {field, if(is_function(fn_value, 0), do: fn_value.(), else: fn_value)}
              end)
            else
              parent[:sum]
            end

            avg_result = if parent[:_avg_fns] do
              Map.new(parent._avg_fns, fn {field, fn_value} ->
                {field, if(is_function(fn_value, 0), do: fn_value.(), else: fn_value)}
              end)
            else
              parent[:avg]
            end

            min_result = if parent[:_min_fns] do
              Map.new(parent._min_fns, fn {field, fn_value} ->
                {field, if(is_function(fn_value, 0), do: fn_value.(), else: fn_value)}
              end)
            else
              parent[:min]
            end

            max_result = if parent[:_max_fns] do
              Map.new(parent._max_fns, fn {field, fn_value} ->
                {field, if(is_function(fn_value, 0), do: fn_value.(), else: fn_value)}
              end)
            else
              parent[:max]
            end

            result = %{}
            result = if sum_result && map_size(sum_result) > 0, do: Map.put(result, :sum, sum_result), else: result
            result = if avg_result && map_size(avg_result) > 0, do: Map.put(result, :avg, avg_result), else: result
            result = if min_result && map_size(min_result) > 0, do: Map.put(result, :min, min_result), else: result
            result = if max_result && map_size(max_result) > 0, do: Map.put(result, :max, max_result), else: result

            {:ok, if(map_size(result) > 0, do: result, else: nil)}
          end)
        end
      end
    else
      nil
    end

    quote do
      Absinthe.Schema.Notation.object unquote(connection_name) do
        field :edges, list_of(unquote(edge_name))
        field :page_info, non_null(:page_info)

        # GitHub-style nodes shortcut - direct access to nodes without edges
        @desc "Flattened list of nodes (GitHub-style shortcut)"
        field :nodes, list_of(unquote(type_identifier))

        # Total count of items (ignoring pagination)
        # Uses deferred loading - only executes count query if field is requested
        @desc "Total count of items matching the query (ignoring pagination)"
        field :total_count, :integer do
          resolve(fn
            # Deferred loading - function present
            %{_total_count_fn: count_fn}, _, _ when is_function(count_fn, 0) ->
              {:ok, count_fn.()}

            # Eager loading - value already computed
            %{total_count: count}, _, _ ->
              {:ok, count}

            # Fallback - no count available
            _, _, _ ->
              {:ok, nil}
          end)
        end

        # Exists - whether any items match the query
        # Uses deferred loading - only executes exists query if field is requested
        @desc "Whether any items match the query"
        field :exists, :boolean do
          resolve(fn
            # Deferred loading - function present
            %{_exists_fn: exists_fn}, _, _ when is_function(exists_fn, 0) ->
              {:ok, exists_fn.()}

            # Eager loading - value already computed
            %{exists: exists}, _, _ ->
              {:ok, exists}

            # Fallback - check edges
            %{edges: edges}, _, _ ->
              {:ok, length(edges) > 0}

            # Default fallback
            _, _, _ ->
              {:ok, false}
          end)
        end

        unquote(aggregate_field)

        unquote(connection_fields)
      end
    end
  end

  # Parse the connection block to extract edge definition, extra connection fields, custom resolver, and aggregates
  @doc false
  def parse_connection_block(nil), do: {nil, nil, nil, nil}

  def parse_connection_block({:__block__, _, statements}) do
    # Split statements into edge, resolver, aggregate, and other
    {edge_blocks, rest} =
      Enum.split_with(statements, fn
        {:edge, _, _} -> true
        _ -> false
      end)

    {aggregate_blocks, rest} =
      Enum.split_with(rest, fn
        {:aggregate, _, _} -> true
        _ -> false
      end)

    {resolver_blocks, connection_field_statements} =
      Enum.split_with(rest, fn
        {:resolve, _, _} -> true
        {:loader, _, _} -> true
        _ -> false
      end)

    edge_block =
      case edge_blocks do
        [{:edge, _, [[do: block]]} | _] -> block
        [{:edge, _, [_, [do: block]]} | _] -> block
        _ -> nil
      end

    custom_resolver =
      case resolver_blocks do
        [{:resolve, _, _} = resolve_call | _] -> resolve_call
        [{:loader, _, _} = loader_call | _] -> loader_call
        _ -> nil
      end

    aggregates =
      case aggregate_blocks do
        [{:aggregate, _, [[do: block]]} | _] ->
          alias GreenFairy.Field.ConnectionAggregate
          ConnectionAggregate.parse_aggregate_block(block)
        _ -> nil
      end

    connection_fields =
      case connection_field_statements do
        [] -> nil
        stmts -> {:__block__, [], stmts}
      end

    {edge_block, connection_fields, custom_resolver, aggregates}
  end

  def parse_connection_block({:edge, _, [[do: block]]}) do
    {block, nil, nil, nil}
  end

  def parse_connection_block({:resolve, _, _} = resolve_call) do
    {nil, nil, resolve_call, nil}
  end

  def parse_connection_block({:loader, _, _} = loader_call) do
    {nil, nil, loader_call, nil}
  end

  def parse_connection_block(other) do
    {nil, other, nil, nil}
  end

  @doc """
  Creates a connection result from a list of items.

  ## Examples

      GreenFairy.Field.Connection.from_list(users, args)

  ## Options

  - `:cursor_fn` - Function to generate cursors (default: index-based)
  - `:total_count` - Total count of items before pagination (default: length of items before pagination)
  - `:deferred` - Use deferred loading for totalCount and exists (default: false)

  ## Deferred Loading

  When `:deferred` is true, totalCount and exists are returned as functions
  that execute only when those fields are requested in the GraphQL query.
  This avoids expensive COUNT queries when not needed.

  """
  def from_list(items, args, opts \\ []) do
    cursor_fn = Keyword.get(opts, :cursor_fn, &default_cursor/2)
    deferred = Keyword.get(opts, :deferred, false)
    first = Map.get(args, :first)
    last = Map.get(args, :last)
    after_cursor = Map.get(args, :after)
    before_cursor = Map.get(args, :before)

    # Apply cursor-based filtering
    items =
      items
      |> maybe_filter_after(after_cursor, cursor_fn)
      |> maybe_filter_before(before_cursor, cursor_fn)

    total = length(items)

    # Apply pagination limits
    {items, has_previous, has_next} =
      case {first, last} do
        {nil, nil} ->
          {items, false, false}

        {first, nil} when is_integer(first) ->
          has_next = total > first
          {Enum.take(items, first), false, has_next}

        {nil, last} when is_integer(last) ->
          has_previous = total > last
          items = Enum.take(items, -last)
          {items, has_previous, false}

        {first, last} when is_integer(first) and is_integer(last) ->
          # First takes precedence
          has_next = total > first
          {Enum.take(items, first), false, has_next}
      end

    # Build edges with cursors
    edges =
      items
      |> Enum.with_index()
      |> Enum.map(fn {item, idx} ->
        %{
          node: item,
          cursor: cursor_fn.(item, idx)
        }
      end)

    # Build page info
    page_info = %{
      has_next_page: has_next,
      has_previous_page: has_previous,
      start_cursor: List.first(edges)[:cursor],
      end_cursor: List.last(edges)[:cursor]
    }

    # Build nodes list (GitHub-style shortcut)
    nodes = Enum.map(edges, & &1.node)

    # Build result with deferred or eager loading
    result =
      if deferred do
        # Allow override of total_count for cases where we know the full count
        total_count_fn = Keyword.get(opts, :total_count_fn, fn -> total end)
        exists_fn = Keyword.get(opts, :exists_fn, fn -> total > 0 end)

        %{
          edges: edges,
          page_info: page_info,
          nodes: nodes,
          _total_count_fn: total_count_fn,
          _exists_fn: exists_fn
        }
      else
        # Eager loading (backwards compatible)
        total_count = Keyword.get(opts, :total_count, total)

        %{
          edges: edges,
          page_info: page_info,
          nodes: nodes,
          total_count: total_count,
          exists: total_count > 0
        }
      end

    # Add aggregates if present
    result = if aggregates = Keyword.get(opts, :aggregates) do
      Map.merge(result, aggregates)
    else
      result
    end

    {:ok, result}
  end

  @doc """
  Creates a connection result from an Ecto query.

  This function handles cursor-based pagination for Ecto queries.

  ## Options

  - `:cursor_fn` - Function to generate cursors (default: index-based)
  - `:count_query` - Custom query for counting (default: uses the same query)
  - `:deferred` - Use deferred loading for totalCount and exists (default: false)

  ## Deferred Loading

  When `:deferred` is true, the count query is wrapped in a function and only
  executed when the totalCount or exists field is requested. This significantly
  improves performance for large datasets when those fields aren't needed.

  """
  def from_query(query, repo, args, opts \\ []) do
    cursor_fn = Keyword.get(opts, :cursor_fn, &default_cursor/2)
    count_query = Keyword.get(opts, :count_query, query)
    deferred = Keyword.get(opts, :deferred, false)
    aggregates = Keyword.get(opts, :aggregates)
    _first = Map.get(args, :first)
    _last = Map.get(args, :last)
    _after_cursor = Map.get(args, :after)
    _before_cursor = Map.get(args, :before)

    # Fetch items for edges
    items = repo.all(query)

    # Build options for from_list
    from_list_opts = [cursor_fn: cursor_fn, deferred: deferred]

    from_list_opts =
      if deferred do
        # Create deferred count function
        import Ecto.Query, only: [exclude: 2]

        total_count_fn = fn ->
          count_query |> exclude(:preload) |> exclude(:order_by) |> repo.aggregate(:count, :id)
        end

        exists_fn = fn ->
          count_query |> exclude(:preload) |> exclude(:order_by) |> repo.exists?()
        end

        from_list_opts
        |> Keyword.put(:total_count_fn, total_count_fn)
        |> Keyword.put(:exists_fn, exists_fn)
      else
        # Eager loading - compute now
        import Ecto.Query, only: [exclude: 2]
        total_count = count_query |> exclude(:preload) |> exclude(:order_by) |> repo.aggregate(:count, :id)
        Keyword.put(from_list_opts, :total_count, total_count)
      end

    # Compute aggregates if specified
    from_list_opts = if aggregates do
      alias GreenFairy.Field.ConnectionAggregate

      aggregate_results = ConnectionAggregate.compute_aggregates(count_query,
        repo: repo,
        aggregates: aggregates,
        deferred: deferred
      )

      Keyword.put(from_list_opts, :aggregates, aggregate_results)
    else
      from_list_opts
    end

    from_list(items, args, from_list_opts)
  end

  # Default cursor function using Base64 encoding of index
  defp default_cursor(_item, idx) do
    Base.encode64("cursor:#{idx}")
  end

  defp maybe_filter_after(items, nil, _cursor_fn), do: items

  defp maybe_filter_after(items, cursor, cursor_fn) do
    items
    |> Enum.with_index()
    |> Enum.drop_while(fn {item, idx} -> cursor_fn.(item, idx) != cursor end)
    |> Enum.drop(1)
    |> Enum.map(fn {item, _idx} -> item end)
  end

  defp maybe_filter_before(items, nil, _cursor_fn), do: items

  defp maybe_filter_before(items, cursor, cursor_fn) do
    items
    |> Enum.with_index()
    |> Enum.take_while(fn {item, idx} -> cursor_fn.(item, idx) != cursor end)
    |> Enum.map(fn {item, _idx} -> item end)
  end
end
