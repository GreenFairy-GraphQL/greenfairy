defmodule GreenFairy.CQL.QueryCompiler do
  @moduledoc """
  Compiles CQL filter inputs into Ecto queries.

  This module transforms nested filter input maps into Ecto query conditions,
  handling:
  - Standard field operators (_eq, _ne, _gt, _lt, etc.)
  - Logical operators (_and, _or, _not)
  - Nested association filters
  - The `_exists` operator for association existence checks

  ## How It Works

  Given a filter like:

      %{
        name: %{_eq: "Alice"},
        organization: %{
          status: %{_eq: "active"}
        }
      }

  The compiler:
  1. Processes top-level field conditions directly
  2. Detects nested association filters
  3. Builds existence subqueries for nested conditions
  4. Combines all conditions into a single query

  ## Transparent Operation

  The compiler automatically detects which fields are associations by checking
  the schema's association metadata. No configuration required.
  """

  import Ecto.Query

  alias GreenFairy.CQL.Operators.Exists
  alias GreenFairy.Dataloader.{DynamicJoins, Partition}

  @type filter_input :: map()
  @type compile_result :: {:ok, Ecto.Query.t()} | {:error, String.t()}

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Compiles a CQL filter input into an Ecto query using the adapter system.

  ## Parameters

  - `query` - Base Ecto query
  - `filter` - CQL filter input map
  - `schema` - The schema module for the query's root type
  - `opts` - Options:
    - `:adapter` - The CQL adapter module (required)
    - `:parent_alias` - Alias to use for parent references (default: nil)
    - `:binding` - Query binding for associations (default: nil)

  ## Returns

  `{:ok, query}` with conditions applied, or `{:error, message}` on validation failure.

  ## Example

      iex> filter = %{name: %{_eq: "Alice"}, organization: %{status: %{_eq: "active"}}}
      iex> QueryCompiler.compile(query, filter, MyApp.User, adapter: PostgresAdapter)
      {:ok, #Ecto.Query<...>}
  """
  def compile(query, filter, schema, opts \\ [])
  def compile(query, nil, _schema, _opts), do: {:ok, query}
  def compile(query, filter, _schema, _opts) when filter == %{}, do: {:ok, query}

  def compile(query, filter, schema, opts) do
    adapter = Keyword.fetch!(opts, :adapter)

    with :ok <- Exists.validate_exists_usage(filter, opts) do
      compiled = compile_filter(query, filter, schema, adapter, opts)
      {:ok, compiled}
    end
  end

  @doc """
  Compiles a CQL filter input, raising on validation errors.
  """
  def compile!(query, filter, schema, opts \\ []) do
    case compile(query, filter, schema, opts) do
      {:ok, result} -> result
      {:error, message} -> raise ArgumentError, message
    end
  end

  # ============================================================================
  # Filter Compilation
  # ============================================================================

  defp compile_filter(query, nil, _schema, _adapter, _opts), do: query
  defp compile_filter(query, filter, _schema, _adapter, _opts) when filter == %{}, do: query

  defp compile_filter(query, filter, schema, adapter, opts) when is_map(filter) do
    Enum.reduce(filter, query, fn {key, value}, acc ->
      compile_condition(acc, key, value, schema, adapter, opts)
    end)
  end

  # Logical operators
  defp compile_condition(query, :_and, filters, schema, adapter, opts) when is_list(filters) do
    case Exists.validate_exists_in_logical_operator(filters, :_and) do
      :ok ->
        Enum.reduce(filters, query, fn filter, acc ->
          compile_filter(acc, filter, schema, adapter, opts)
        end)

      {:error, _msg} ->
        query
    end
  end

  defp compile_condition(query, :_or, filters, schema, adapter, opts) when is_list(filters) do
    case Exists.validate_exists_in_logical_operator(filters, :_or) do
      :ok ->
        dynamics =
          Enum.map(filters, fn filter ->
            build_dynamic_for_filter(filter, schema, adapter, opts)
          end)

        combined = Enum.reduce(dynamics, fn d, acc -> dynamic([q], ^acc or ^d) end)
        where(query, ^combined)

      {:error, _msg} ->
        query
    end
  end

  defp compile_condition(query, :_not, filter, schema, adapter, opts) when is_map(filter) do
    # Check if the filter contains association fields that need special handling
    assoc_fields = filter |> Map.keys() |> Enum.filter(&association?(schema, &1))
    regular_fields = (Map.keys(filter) -- assoc_fields) -- [:_and, :_or, :_not]

    cond do
      # If only association filters, use NOT EXISTS for each
      regular_fields == [] and assoc_fields != [] ->
        Enum.reduce(assoc_fields, query, fn field, acc ->
          assoc_filter = Map.get(filter, field)
          compile_not_association_filter(acc, field, assoc_filter, schema, adapter, opts)
        end)

      # If only regular fields, use dynamic NOT
      assoc_fields == [] ->
        subquery_dynamic = build_dynamic_for_filter(filter, schema, adapter, opts)
        where(query, ^dynamic([q], not (^subquery_dynamic)))

      # Mixed case: handle associations with NOT EXISTS, regular with dynamic
      true ->
        # First apply NOT EXISTS for associations
        query =
          Enum.reduce(assoc_fields, query, fn field, acc ->
            assoc_filter = Map.get(filter, field)
            compile_not_association_filter(acc, field, assoc_filter, schema, adapter, opts)
          end)

        # Then apply dynamic NOT for regular fields
        regular_filter = Map.take(filter, regular_fields)

        if map_size(regular_filter) > 0 do
          subquery_dynamic = build_dynamic_for_filter(regular_filter, schema, adapter, opts)
          where(query, ^dynamic([q], not (^subquery_dynamic)))
        else
          query
        end
    end
  end

  # Exists operator (only valid in nested context)
  defp compile_condition(query, :_exists, _value, _schema, _adapter, _opts) do
    # _exists at top level is invalid; validation catches this
    query
  end

  # Field conditions
  defp compile_condition(query, field, operators, schema, adapter, opts) when is_map(operators) do
    if association?(schema, field) do
      compile_association_filter(query, field, operators, schema, adapter, opts)
    else
      compile_field_operators(query, field, operators, schema, adapter, opts)
    end
  end

  defp compile_condition(query, _field, _value, _schema, _adapter, _opts) do
    query
  end

  # ============================================================================
  # Association Filtering
  # ============================================================================

  defp compile_association_filter(query, field, filter, schema, adapter, opts) do
    assoc = schema.__schema__(:association, field)

    if Map.has_key?(filter, :_exists) do
      # Handle _exists operator
      compile_exists(query, field, filter[:_exists], schema, assoc, opts)
    else
      # Build existence subquery for nested conditions
      compile_nested_filter(query, field, filter, schema, assoc, adapter, opts)
    end
  end

  defp compile_exists(query, field, exists_value, schema, assoc, opts) do
    partition = build_partition_for_exists(field, schema, assoc)
    parent_alias = Keyword.get(opts, :parent_alias, :parent)

    subquery = DynamicJoins.existence_subquery(partition, parent_alias)

    if exists_value do
      from(q in query, as: ^parent_alias, where: exists(subquery(subquery)))
    else
      from(q in query, as: ^parent_alias, where: not exists(subquery(subquery)))
    end
  end

  defp compile_nested_filter(query, field, filter, schema, assoc, adapter, opts) do
    # Build a partition with the nested filter conditions applied
    related = assoc.related
    nested_opts = Keyword.put(opts, :is_nested, true)

    base_query = from(r in related)
    filtered_query = compile_filter(base_query, filter, related, adapter, nested_opts)

    partition = %Partition{
      query: filtered_query,
      owner: schema,
      queryable: related,
      field: field
    }

    parent_alias = Keyword.get(opts, :parent_alias, :parent)
    subquery = DynamicJoins.existence_subquery(partition, parent_alias)

    from(q in query, as: ^parent_alias, where: exists(subquery(subquery)))
  end

  # Compile NOT association filter - uses NOT EXISTS subquery
  defp compile_not_association_filter(query, field, filter, schema, adapter, opts) do
    assoc = schema.__schema__(:association, field)
    related = assoc.related
    nested_opts = Keyword.put(opts, :is_nested, true)

    base_query = from(r in related)
    filtered_query = compile_filter(base_query, filter, related, adapter, nested_opts)

    partition = %Partition{
      query: filtered_query,
      owner: schema,
      queryable: related,
      field: field
    }

    parent_alias = Keyword.get(opts, :parent_alias, :parent)
    subquery = DynamicJoins.existence_subquery(partition, parent_alias)

    from(q in query, as: ^parent_alias, where: not exists(subquery(subquery)))
  end

  defp build_partition_for_exists(field, schema, assoc) do
    related = assoc.related
    base_query = from(r in related)

    %Partition{
      query: base_query,
      owner: schema,
      queryable: related,
      field: field
    }
  end

  # ============================================================================
  # Field Operators - Delegated to Adapter
  # ============================================================================

  defp compile_field_operators(query, field, operators, schema, adapter, opts) when is_map(operators) do
    binding = Keyword.get(opts, :binding)
    # Look up field type from the schema - this is required for scalar delegation
    field_type = schema.__schema__(:type, field)

    Enum.reduce(operators, query, fn {op, value}, acc ->
      # Delegate ALL operator logic to the adapter
      # Primary adapter (Ecto/ES) will detect and delegate to the appropriate sub-adapter
      adapter.apply_operator(schema, acc, field, op, value, binding: binding, field_type: field_type)
    end)
  end

  # ============================================================================
  # Dynamic Building (for _or)
  # ============================================================================
  # IMPORTANT: For _or clauses, we need to build subqueries for each condition
  # and combine them. This allows adapter-specific operators to work correctly.

  defp build_dynamic_for_filter(filter, schema, adapter, opts) do
    # For each filter condition, compile it into a separate subquery
    # and combine the results with OR
    #
    # NOTE: This is a simplified implementation that handles basic field operators.
    # For full adapter support in _or clauses, we would need to build separate
    # queries for each condition and combine them at the query level rather than
    # the dynamic level.
    Enum.reduce(filter, dynamic(true), fn {key, value}, acc ->
      condition = build_dynamic_condition(key, value, schema, adapter, opts)
      dynamic([q], ^acc and ^condition)
    end)
  end

  # Handle nested _and within _or
  defp build_dynamic_condition(:_and, filters, schema, adapter, opts) when is_list(filters) do
    dynamics =
      Enum.map(filters, fn filter ->
        build_dynamic_for_filter(filter, schema, adapter, opts)
      end)

    Enum.reduce(dynamics, dynamic(true), fn d, acc -> dynamic([q], ^acc and ^d) end)
  end

  # Handle nested _or within _or (though rare)
  defp build_dynamic_condition(:_or, filters, schema, adapter, opts) when is_list(filters) do
    dynamics =
      Enum.map(filters, fn filter ->
        build_dynamic_for_filter(filter, schema, adapter, opts)
      end)

    Enum.reduce(dynamics, dynamic(false), fn d, acc -> dynamic([q], ^acc or ^d) end)
  end

  # Handle nested _not within _or
  defp build_dynamic_condition(:_not, filter, schema, adapter, opts) when is_map(filter) do
    inner = build_dynamic_for_filter(filter, schema, adapter, opts)
    dynamic([q], not (^inner))
  end

  defp build_dynamic_condition(field, operators, schema, _adapter, _opts) when is_map(operators) do
    if association?(schema, field) do
      # For associations in _or, we need to handle specially
      # This is a simplified version - full implementation would use subqueries
      dynamic(true)
    else
      # For regular fields, we need to build dynamics from adapter operations
      # However, adapters work with queries, not dynamics
      # This is a limitation that needs architectural consideration
      # For now, fall back to basic operators
      Enum.reduce(operators, dynamic(true), fn {op, value}, acc ->
        condition = build_basic_operator_dynamic(field, op, value)
        dynamic([q], ^acc and ^condition)
      end)
    end
  end

  defp build_dynamic_condition(_field, _value, _schema, _adapter, _opts) do
    dynamic(true)
  end

  # Basic operator dynamics - used only in _or clauses as a fallback
  # This is a limitation: adapters can't inject dynamics directly
  defp build_basic_operator_dynamic(field, :_eq, nil), do: dynamic([q], is_nil(field(q, ^field)))
  defp build_basic_operator_dynamic(field, :_eq, value), do: dynamic([q], field(q, ^field) == ^value)
  defp build_basic_operator_dynamic(field, :_ne, nil), do: dynamic([q], not is_nil(field(q, ^field)))
  defp build_basic_operator_dynamic(field, :_ne, value), do: dynamic([q], field(q, ^field) != ^value)
  defp build_basic_operator_dynamic(field, :_gt, value), do: dynamic([q], field(q, ^field) > ^value)
  defp build_basic_operator_dynamic(field, :_gte, value), do: dynamic([q], field(q, ^field) >= ^value)
  defp build_basic_operator_dynamic(field, :_lt, value), do: dynamic([q], field(q, ^field) < ^value)
  defp build_basic_operator_dynamic(field, :_lte, value), do: dynamic([q], field(q, ^field) <= ^value)

  defp build_basic_operator_dynamic(field, :_in, values) when is_list(values) do
    dynamic([q], field(q, ^field) in ^values)
  end

  defp build_basic_operator_dynamic(field, :_nin, values) when is_list(values) do
    dynamic([q], field(q, ^field) not in ^values)
  end

  defp build_basic_operator_dynamic(field, :_like, value), do: dynamic([q], like(field(q, ^field), ^value))
  defp build_basic_operator_dynamic(field, :_ilike, value), do: dynamic([q], ilike(field(q, ^field), ^value))
  defp build_basic_operator_dynamic(field, :_is_null, true), do: dynamic([q], is_nil(field(q, ^field)))
  defp build_basic_operator_dynamic(field, :_is_null, false), do: dynamic([q], not is_nil(field(q, ^field)))

  # String operators
  defp build_basic_operator_dynamic(field, :_contains, value) do
    pattern = "%#{value}%"
    dynamic([q], like(field(q, ^field), ^pattern))
  end

  defp build_basic_operator_dynamic(field, :_icontains, value) do
    pattern = "%#{value}%"
    dynamic([q], ilike(field(q, ^field), ^pattern))
  end

  defp build_basic_operator_dynamic(field, :_starts_with, value) do
    pattern = "#{value}%"
    dynamic([q], like(field(q, ^field), ^pattern))
  end

  defp build_basic_operator_dynamic(field, :_istarts_with, value) do
    pattern = "#{value}%"
    dynamic([q], ilike(field(q, ^field), ^pattern))
  end

  defp build_basic_operator_dynamic(field, :_ends_with, value) do
    pattern = "%#{value}"
    dynamic([q], like(field(q, ^field), ^pattern))
  end

  defp build_basic_operator_dynamic(field, :_iends_with, value) do
    pattern = "%#{value}"
    dynamic([q], ilike(field(q, ^field), ^pattern))
  end

  # Fallback for unknown operators
  defp build_basic_operator_dynamic(_field, _op, _value), do: dynamic(true)

  # ============================================================================
  # Helpers
  # ============================================================================

  defp association?(schema, field) do
    case schema.__schema__(:association, field) do
      nil -> false
      _ -> true
    end
  end
end
