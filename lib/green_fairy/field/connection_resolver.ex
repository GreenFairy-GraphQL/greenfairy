defmodule GreenFairy.Field.ConnectionResolver do
  @moduledoc """
  Automatic resolver for connection fields with parent filtering.

  This module provides default resolvers for connections that automatically:
  - Filter by parent when accessed through an association
  - Apply CQL where filters
  - Apply CQL orderBy sorting
  - Handle cursor-based pagination
  - Return connection results with nodes, totalCount, and exists

  ## Usage

  Connections automatically use this resolver unless you provide a custom one:

      type "User" do
        # Automatic parent filtering - filters posts by user_id
        connection :posts, Post
      end

  For custom logic with parent access:

      type "User" do
        connection :nearby_gigs, Gig do
          loader fn parents, args, ctx ->
            # parents is list of User structs
            # Custom logic here
          end
        end
      end

  """

  alias GreenFairy.Field.Connection
  # TODO: QueryBuilder module needs to be implemented
  # alias GreenFairy.Extensions.CQL.QueryBuilder
  import Ecto.Query, only: [from: 2, where: 3]

  @doc """
  Default resolver for association-based connections.

  Automatically filters by parent and applies CQL filters/ordering.

  Uses deferred loading for totalCount and exists to avoid expensive
  queries when those fields aren't requested.

  ## Parameters

  - `parent` - The parent object (e.g., User struct)
  - `args` - Connection args (first, after, where, orderBy, etc.)
  - `resolution` - Absinthe resolution with context, repo, etc.
  - `opts` - Options including:
    - `:repo` - Ecto repo module
    - `:owner_key` - Parent's key field (e.g., :id)
    - `:related_key` - Child's foreign key (e.g., :user_id)
    - `:queryable` - Base queryable (module or Ecto query)

  """
  def resolve_association_connection(parent, args, resolution, opts) do
    repo = opts[:repo] || get_repo_from_context(resolution.context)
    owner_key = opts[:owner_key] || :id
    related_key = opts[:related_key]
    queryable = opts[:queryable]
    type_module = opts[:type_module]
    aggregates = opts[:aggregates]

    unless repo do
      {:error, "No repo configured for connection. Pass :repo option or set in context."}
    end

    unless related_key do
      {:error, "No related_key provided for association connection"}
    end

    unless queryable do
      {:error, "No queryable provided for connection"}
    end

    # Get parent's key value
    parent_value = Map.get(parent, owner_key)

    # Build base query filtered by parent
    base_query =
      queryable
      |> build_parent_filter(related_key, parent_value)
      |> apply_cql_where(args[:where], type_module)
      |> apply_cql_order_by(args[:order_by], type_module)

    # Build connection options
    connection_opts = [deferred: true]
    connection_opts = if aggregates, do: Keyword.put(connection_opts, :aggregates, aggregates), else: connection_opts

    # Execute connection query with deferred count/exists/aggregates
    Connection.from_query(base_query, repo, args, connection_opts)
  end

  @doc """
  Batch resolver for association-based connections using DataLoader.

  Efficiently loads connections for multiple parents in a single batch.

  ## Parameters

  - `parents` - List of parent objects
  - `args` - Connection args
  - `resolution` - Absinthe resolution
  - `opts` - Same as resolve_association_connection/4

  ## Returns

  Map of parent -> connection result
  """
  def batch_resolve_association_connection(parents, args, resolution, opts) do
    repo = opts[:repo] || get_repo_from_context(resolution.context)
    owner_key = opts[:owner_key] || :id
    related_key = opts[:related_key]
    queryable = opts[:queryable]
    type_module = opts[:type_module]

    unless repo do
      {:error, "No repo configured for connection"}
    end

    # Build map of parent values
    parents_by_value = Map.new(parents, fn p -> {Map.get(p, owner_key), p} end)
    parent_values = Map.keys(parents_by_value)

    # Build base query for all parents
    base_query =
      from(q in queryable,
        where: field(q, ^related_key) in ^parent_values
      )
      |> apply_cql_where(args[:where], type_module)
      |> apply_cql_order_by(args[:order_by], type_module)

    # Fetch all items
    items = repo.all(base_query)

    # Group by parent
    items_by_parent =
      items
      |> Enum.group_by(fn item -> Map.get(item, related_key) end)
      |> Map.new(fn {parent_value, items} ->
        parent = parents_by_value[parent_value]
        connection = Connection.from_list(items, args, total_count: length(items))
        {parent, connection}
      end)

    # Ensure all parents have a connection result (even if empty)
    Map.new(parents, fn parent ->
      parent_value = Map.get(parent, owner_key)
      connection = Map.get(items_by_parent, parent_value, empty_connection())
      {parent, connection}
    end)
  end

  # Build parent filter clause
  defp build_parent_filter(query, related_key, parent_value) do
    where(query, [q], field(q, ^related_key) == ^parent_value)
  end

  # Apply CQL where filters to query
  defp apply_cql_where(query, nil, _type_module), do: query

  defp apply_cql_where(query, where_input, type_module) when is_map(where_input) do
    # TODO: Implement QueryBuilder.apply_where/3
    # QueryBuilder.apply_where(query, where_input, type_module)
    _ = {where_input, type_module}  # Silence unused warning
    query
  end

  # Apply CQL order_by to query
  defp apply_cql_order_by(query, nil, _type_module), do: query

  defp apply_cql_order_by(query, order_inputs, type_module) when is_list(order_inputs) do
    # TODO: Implement QueryBuilder.apply_order_by/3
    # QueryBuilder.apply_order_by(query, order_inputs, type_module)
    _ = {order_inputs, type_module}  # Silence unused warning
    query
  end

  defp apply_cql_order_by(query, _, _type_module), do: query

  # Get repo from context
  defp get_repo_from_context(context) do
    context[:repo] || context[:current_repo] || nil
  end

  # Empty connection result
  defp empty_connection do
    {:ok,
     %{
       edges: [],
       page_info: %{
         has_next_page: false,
         has_previous_page: false,
         start_cursor: nil,
         end_cursor: nil
       },
       nodes: [],
       total_count: 0,
       exists: false
     }}
  end
end
