defmodule Absinthe.Object.Dataloader.DynamicJoins do
  @moduledoc """
  Dynamic join chain building for partitioned dataloader queries.

  This module provides the core functionality for:
  1. Building join chains from target back to owner
  2. Creating existence subqueries for nested filtering
  3. Adding partition IDs for result grouping

  ## How Join Chains Work

  For an association like `User -> Organization`, we build:

      from o in Organization,
        join: u in User, on: u.organization_id == o.id,
        where: u.id in ^parent_ids,
        select_merge: %{partition_id_: u.organization_id}

  For nested associations like `User -> Organization -> Parent`:

      from p in Parent,
        join: o in Organization, on: o.parent_id == p.id,
        join: u in User, on: u.organization_id == o.id,
        where: u.id in ^parent_ids,
        select_merge: %{partition_id_: u.organization_id}

  ## Existence Subqueries

  For checking if related records exist (used with `_exists` operator):

      exists(
        from o in Organization,
          where: o.id == parent_as(:parent).organization_id
          and o.status == "active"
      )
  """

  import Ecto.Query

  alias Absinthe.Object.Dataloader.Partition

  @type join_info :: %{
          owner: module(),
          owner_key: atom(),
          related_key: atom(),
          where: keyword(),
          join_where: keyword()
        }

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Executes a partitioned query and groups results by partition ID.

  Returns a map of `%{partition_id => [results]}`.
  """
  def partitioned(%Partition{} = partition, parent_ids, repo) do
    %{query: query} = invert_query(partition, parent_ids)

    query
    |> apply_pagination(partition)
    |> apply_sort(partition)
    |> repo.all()
    |> apply_post_process(partition)
    |> Enum.group_by(& &1.partition_id_)
  end

  @doc """
  Builds an inverted query that joins from target back to owner.

  Returns a map with:
  - `:query` - The built query with joins and partition_id_
  - `:scope_alias` - The alias of the last join (for referencing)
  - `:scope_key` - The key field on the last join
  - `:partition` - The original partition struct
  """
  def invert_query(%Partition{} = partition, parent_ids) do
    %{query: base_query, owner: owner, field: field} = partition

    join_chain = build_join_chain(owner, field)

    {with_joins, last_alias, related_key} =
      attach_join_chain(join_chain, base_query)

    result =
      with_joins
      |> constrain_by_parent(parent_ids, last_alias, related_key)
      |> maybe_inject_custom(partition, last_alias, related_key)
      |> select_merge_partition_id(last_alias, related_key)

    %{
      partition: partition,
      query: result,
      scope_alias: last_alias,
      scope_key: related_key
    }
  end

  @doc """
  Creates an existence subquery for nested association filtering.

  Used with the `_exists` operator to check if related records exist
  matching certain criteria.

  ## Parameters

  - `partition` - The Partition struct with query and association info
  - `parent_alias` - The alias to reference the parent record

  ## Example

      partition = %Partition{
        query: from(o in Organization, where: o.status == "active"),
        owner: User,
        queryable: Organization,
        field: :organization
      }

      subquery = existence_subquery(partition, :parent)
      # Creates: exists(from o in Organization, where: o.id == parent_as(:parent).organization_id and o.status == "active")
  """
  def existence_subquery(%Partition{} = partition, parent_alias) do
    owner_key = Partition.owner_key(partition)
    existence_subquery(partition, parent_alias, owner_key)
  end

  @doc """
  Creates an existence subquery with explicit owner key.
  """
  def existence_subquery(%Partition{} = partition, parent_alias, owner_key) do
    %{query: base_query, owner: owner, field: field} = partition

    join_chain = build_join_chain(owner, field)

    {with_joins, last_alias, related_key} =
      attach_join_chain(join_chain, base_query)

    with_joins
    |> constrain_by_exists(parent_alias, owner_key, related_key, last_alias)
    |> select([], 1)
  end

  # ============================================================================
  # Join Chain Building
  # ============================================================================

  @doc false
  def build_join_chain(owner, field) do
    case owner.__schema__(:association, field) do
      nil ->
        raise ArgumentError, "Association #{field} not found on #{inspect(owner)}"

      %Ecto.Association.BelongsTo{} = assoc ->
        [extract_join_info(assoc)]

      %Ecto.Association.Has{} = assoc ->
        [extract_join_info(assoc)]

      %Ecto.Association.HasThrough{through: through} ->
        # For has_through, we need to build the full chain
        build_through_chain(owner, through)

      %Ecto.Association.ManyToMany{} = assoc ->
        # Many-to-many requires two joins (through the join table)
        split_many_to_many(assoc)

      assoc ->
        [extract_join_info(assoc)]
    end
  end

  defp extract_join_info(%{owner: owner, owner_key: owner_key, related_key: related_key} = assoc) do
    %{
      owner: owner,
      owner_key: owner_key,
      related_key: related_key,
      where: Map.get(assoc, :where, []),
      join_where: Map.get(assoc, :join_where, [])
    }
  end

  defp extract_join_info(%{owner: owner, related_key: related_key} = assoc) do
    # For belongs_to, owner_key is the foreign key on the owner
    owner_key = Map.get(assoc, :owner_key, :id)

    %{
      owner: owner,
      owner_key: owner_key,
      related_key: related_key,
      where: Map.get(assoc, :where, []),
      join_where: []
    }
  end

  defp build_through_chain(owner, [first_assoc | rest]) do
    case owner.__schema__(:association, first_assoc) do
      nil ->
        raise ArgumentError, "Association #{first_assoc} not found on #{inspect(owner)}"

      %{related: related} = assoc ->
        [extract_join_info(assoc) | build_through_rest(related, rest)]
    end
  end

  defp build_through_rest(_owner, []), do: []

  defp build_through_rest(owner, [assoc_name | rest]) do
    case owner.__schema__(:association, assoc_name) do
      nil ->
        raise ArgumentError, "Association #{assoc_name} not found on #{inspect(owner)}"

      %{related: related} = assoc ->
        [extract_join_info(assoc) | build_through_rest(related, rest)]
    end
  end

  defp split_many_to_many(%Ecto.Association.ManyToMany{
         owner: owner,
         join_through: join_through,
         join_keys: [{owner_join_key, owner_key}, {related_join_key, related_key}],
         where: where,
         join_where: join_where
       }) do
    # First join: owner -> join_table
    join_table_info = %{
      owner: owner,
      owner_key: owner_key,
      related_key: owner_join_key,
      where: [],
      join_where: join_where
    }

    # Second join: join_table -> related
    related_info = %{
      owner: join_through,
      owner_key: related_join_key,
      related_key: related_key,
      where: where,
      join_where: []
    }

    [join_table_info, related_info]
  end

  # ============================================================================
  # Join Chain Attachment
  # ============================================================================

  defp attach_join_chain(assocs, query, count \\ 0)

  # Base case: last association in chain
  defp attach_join_chain([%{related_key: related_key} = assoc], query, count) do
    filtered_query = handle_filtered_joins(query, assoc, count)
    {filtered_query, previous_alias(count), related_key}
  end

  # Recursive case: more associations to process
  defp attach_join_chain(
         [%{owner: owner, related_key: related_key, owner_key: owner_key} = assoc | rest],
         query,
         count
       ) do
    new_alias = current_alias(count)

    new_query =
      if count > 0 do
        previous = previous_alias(count)

        join(query, :inner, [{^previous, c}], o in ^owner,
          on: field(o, ^owner_key) == field(c, ^related_key),
          as: ^new_alias
        )
      else
        join(query, :inner, [c], o in ^owner,
          on: field(o, ^owner_key) == field(c, ^related_key),
          as: ^new_alias
        )
      end

    filtered_query = handle_filtered_joins(new_query, assoc, count)
    attach_join_chain(rest, filtered_query, count + 1)
  end

  # ============================================================================
  # Filtering
  # ============================================================================

  defp handle_filtered_joins(query, %{where: filters}, count) when is_list(filters) and filters != [] do
    join_alias = previous_alias(count)
    Enum.reduce(filters, query, &filter_where(&1, join_alias, &2))
  end

  defp handle_filtered_joins(query, %{join_where: filters}, count) when is_list(filters) and filters != [] do
    join_alias = current_alias(count)
    Enum.reduce(filters, query, &filter_where(&1, join_alias, &2))
  end

  defp handle_filtered_joins(query, _assoc, _count), do: query

  defp filter_where({field_name, nil}, nil, query) do
    where(query, [q], is_nil(field(q, ^field_name)))
  end

  defp filter_where({field_name, nil}, join_alias, query) do
    where(query, [{^join_alias, q}], is_nil(field(q, ^field_name)))
  end

  defp filter_where({field_name, {:not, value}}, nil, query) do
    where(query, [q], field(q, ^field_name) != ^value)
  end

  defp filter_where({field_name, {:not, value}}, join_alias, query) do
    where(query, [{^join_alias, q}], field(q, ^field_name) != ^value)
  end

  defp filter_where({field_name, value}, nil, query) do
    where(query, [q], field(q, ^field_name) == ^value)
  end

  defp filter_where({field_name, value}, join_alias, query) do
    where(query, [{^join_alias, q}], field(q, ^field_name) == ^value)
  end

  # ============================================================================
  # Constraints
  # ============================================================================

  defp constrain_by_parent(query, parent_ids, nil, related_key) do
    where(query, [q], field(q, ^related_key) in ^parent_ids)
  end

  defp constrain_by_parent(query, parent_ids, last_alias, related_key) do
    where(query, [{^last_alias, q}], field(q, ^related_key) in ^parent_ids)
  end

  defp constrain_by_exists(query, parent_alias, owner_key, related_key, nil) do
    where(query, [q], field(parent_as(^parent_alias), ^owner_key) == field(q, ^related_key))
  end

  defp constrain_by_exists(query, parent_alias, owner_key, related_key, last_alias) do
    where(
      query,
      [{^last_alias, q}],
      field(parent_as(^parent_alias), ^owner_key) == field(q, ^related_key)
    )
  end

  # ============================================================================
  # Partition ID
  # ============================================================================

  defp select_merge_partition_id(query, nil, related_key) do
    select_merge(query, [q], %{partition_id_: field(q, ^related_key)})
  end

  defp select_merge_partition_id(query, last_alias, related_key) do
    select_merge(query, [{^last_alias, q}], %{partition_id_: field(q, ^related_key)})
  end

  # ============================================================================
  # Pagination & Sorting
  # ============================================================================

  defp apply_pagination(query, %Partition{connection_args: args}) do
    query
    |> maybe_limit(args[:limit] || args[:first])
    |> maybe_offset(args[:offset])
  end

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, limit), do: limit(query, ^limit)

  defp maybe_offset(query, nil), do: query
  defp maybe_offset(query, offset), do: offset(query, ^offset)

  defp apply_sort(query, %Partition{sort: []}), do: query

  defp apply_sort(query, %Partition{sort: sorts}) do
    Enum.reduce(sorts, query, fn {direction, dynamic_expr}, q ->
      order_by(q, ^[{direction, dynamic_expr}])
    end)
  end

  # ============================================================================
  # Custom Injection & Post-Processing
  # ============================================================================

  defp maybe_inject_custom(query, %Partition{custom_inject: nil}, _alias, _key), do: query

  defp maybe_inject_custom(query, %Partition{custom_inject: inject}, scope_alias, scope_key) do
    inject.(query, scope_alias, scope_key)
  end

  defp apply_post_process(results, %Partition{post_process: nil}), do: results
  defp apply_post_process(results, %Partition{post_process: func}), do: func.(results)

  # ============================================================================
  # Helpers
  # ============================================================================

  # Predefined join aliases to avoid runtime atom creation.
  # Max depth of 20 should cover any reasonable join chain.
  @join_aliases Enum.map(0..20, &:"__join_#{&1}")

  defp current_alias(count) when count >= 0 and count <= 20 do
    Enum.at(@join_aliases, count)
  end

  defp current_alias(_count), do: nil

  defp previous_alias(count) when count > 0 and count <= 21 do
    Enum.at(@join_aliases, count - 1)
  end

  defp previous_alias(_count), do: nil
end
