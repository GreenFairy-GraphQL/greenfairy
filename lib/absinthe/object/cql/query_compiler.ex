defmodule Absinthe.Object.CQL.QueryCompiler do
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

  alias Absinthe.Object.CQL.Operators.Exists
  alias Absinthe.Object.Dataloader.{DynamicJoins, Partition}

  @comparison_operators [:_eq, :_ne, :_gt, :_gte, :_lt, :_lte]
  @list_operators [:_in, :_nin]
  @string_operators [:_like, :_ilike, :_nlike, :_nilike]
  @null_operators [:_is_null]
  @logical_operators [:_and, :_or, :_not]

  @type filter_input :: map()
  @type compile_result :: {:ok, Ecto.Query.t()} | {:error, String.t()}

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Compiles a CQL filter input into an Ecto query.

  ## Parameters

  - `query` - Base Ecto query
  - `filter` - CQL filter input map
  - `schema` - The schema module for the query's root type
  - `opts` - Options:
    - `:parent_alias` - Alias to use for parent references (default: nil)

  ## Returns

  `{:ok, query}` with conditions applied, or `{:error, message}` on validation failure.

  ## Example

      iex> filter = %{name: %{_eq: "Alice"}, organization: %{status: %{_eq: "active"}}}
      iex> QueryCompiler.compile(User, filter, MyApp.User)
      {:ok, #Ecto.Query<...>}
  """
  def compile(query, filter, schema, opts \\ [])
  def compile(query, nil, _schema, _opts), do: {:ok, query}
  def compile(query, filter, _schema, _opts) when filter == %{}, do: {:ok, query}

  def compile(query, filter, schema, opts) do
    with :ok <- Exists.validate_exists_usage(filter, opts) do
      compiled = compile_filter(query, filter, schema, opts)
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

  defp compile_filter(query, nil, _schema, _opts), do: query
  defp compile_filter(query, filter, _schema, _opts) when filter == %{}, do: query

  defp compile_filter(query, filter, schema, opts) when is_map(filter) do
    Enum.reduce(filter, query, fn {key, value}, acc ->
      compile_condition(acc, key, value, schema, opts)
    end)
  end

  # Logical operators
  defp compile_condition(query, :_and, filters, schema, opts) when is_list(filters) do
    case Exists.validate_exists_in_logical_operator(filters, :_and) do
      :ok ->
        Enum.reduce(filters, query, fn filter, acc ->
          compile_filter(acc, filter, schema, opts)
        end)

      {:error, _msg} ->
        query
    end
  end

  defp compile_condition(query, :_or, filters, schema, opts) when is_list(filters) do
    case Exists.validate_exists_in_logical_operator(filters, :_or) do
      :ok ->
        dynamics =
          Enum.map(filters, fn filter ->
            build_dynamic_for_filter(filter, schema, opts)
          end)

        combined = Enum.reduce(dynamics, fn d, acc -> dynamic([q], ^acc or ^d) end)
        where(query, ^combined)

      {:error, _msg} ->
        query
    end
  end

  defp compile_condition(query, :_not, filter, schema, opts) when is_map(filter) do
    subquery_dynamic = build_dynamic_for_filter(filter, schema, opts)
    where(query, ^dynamic([q], not (^subquery_dynamic)))
  end

  # Exists operator (only valid in nested context)
  defp compile_condition(query, :_exists, _value, _schema, _opts) do
    # _exists at top level is invalid; validation catches this
    query
  end

  # Field conditions
  defp compile_condition(query, field, operators, schema, opts) when is_map(operators) do
    if association?(schema, field) do
      compile_association_filter(query, field, operators, schema, opts)
    else
      compile_field_operators(query, field, operators, schema, opts)
    end
  end

  defp compile_condition(query, _field, _value, _schema, _opts) do
    query
  end

  # ============================================================================
  # Association Filtering
  # ============================================================================

  defp compile_association_filter(query, field, filter, schema, opts) do
    assoc = schema.__schema__(:association, field)

    if Map.has_key?(filter, :_exists) do
      # Handle _exists operator
      compile_exists(query, field, filter[:_exists], schema, assoc, opts)
    else
      # Build existence subquery for nested conditions
      compile_nested_filter(query, field, filter, schema, assoc, opts)
    end
  end

  defp compile_exists(query, field, exists_value, schema, assoc, opts) do
    partition = build_partition_for_exists(field, schema, assoc)
    parent_alias = Keyword.get(opts, :parent_alias, :parent)

    subquery = DynamicJoins.existence_subquery(partition, parent_alias)

    if exists_value do
      from q in query, as: ^parent_alias, where: exists(subquery(subquery))
    else
      from q in query, as: ^parent_alias, where: not exists(subquery(subquery))
    end
  end

  defp compile_nested_filter(query, field, filter, schema, assoc, opts) do
    # Build a partition with the nested filter conditions applied
    related = assoc.related
    nested_opts = Keyword.put(opts, :is_nested, true)

    base_query = from(r in related)
    filtered_query = compile_filter(base_query, filter, related, nested_opts)

    partition = %Partition{
      query: filtered_query,
      owner: schema,
      queryable: related,
      field: field
    }

    parent_alias = Keyword.get(opts, :parent_alias, :parent)
    subquery = DynamicJoins.existence_subquery(partition, parent_alias)

    from q in query, as: ^parent_alias, where: exists(subquery(subquery))
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
  # Field Operators
  # ============================================================================

  defp compile_field_operators(query, field, operators, _schema, _opts) when is_map(operators) do
    Enum.reduce(operators, query, fn {op, value}, acc ->
      apply_operator(acc, field, op, value)
    end)
  end

  # Comparison operators
  defp apply_operator(query, field, :_eq, nil) do
    where(query, [q], is_nil(field(q, ^field)))
  end

  defp apply_operator(query, field, :_eq, value) do
    where(query, [q], field(q, ^field) == ^value)
  end

  defp apply_operator(query, field, :_ne, nil) do
    where(query, [q], not is_nil(field(q, ^field)))
  end

  defp apply_operator(query, field, :_ne, value) do
    where(query, [q], field(q, ^field) != ^value)
  end

  defp apply_operator(query, field, :_gt, value) do
    where(query, [q], field(q, ^field) > ^value)
  end

  defp apply_operator(query, field, :_gte, value) do
    where(query, [q], field(q, ^field) >= ^value)
  end

  defp apply_operator(query, field, :_lt, value) do
    where(query, [q], field(q, ^field) < ^value)
  end

  defp apply_operator(query, field, :_lte, value) do
    where(query, [q], field(q, ^field) <= ^value)
  end

  # List operators
  defp apply_operator(query, field, :_in, values) when is_list(values) do
    where(query, [q], field(q, ^field) in ^values)
  end

  defp apply_operator(query, field, :_nin, values) when is_list(values) do
    where(query, [q], field(q, ^field) not in ^values)
  end

  # String operators
  defp apply_operator(query, field, :_like, value) do
    where(query, [q], like(field(q, ^field), ^value))
  end

  defp apply_operator(query, field, :_ilike, value) do
    where(query, [q], ilike(field(q, ^field), ^value))
  end

  defp apply_operator(query, field, :_nlike, value) do
    where(query, [q], not like(field(q, ^field), ^value))
  end

  defp apply_operator(query, field, :_nilike, value) do
    where(query, [q], not ilike(field(q, ^field), ^value))
  end

  # Null check operator
  defp apply_operator(query, field, :_is_null, true) do
    where(query, [q], is_nil(field(q, ^field)))
  end

  defp apply_operator(query, field, :_is_null, false) do
    where(query, [q], not is_nil(field(q, ^field)))
  end

  # Unknown operator - pass through
  defp apply_operator(query, _field, _op, _value) do
    query
  end

  # ============================================================================
  # Dynamic Building (for _or)
  # ============================================================================

  defp build_dynamic_for_filter(filter, schema, opts) do
    Enum.reduce(filter, dynamic(true), fn {key, value}, acc ->
      condition = build_dynamic_condition(key, value, schema, opts)
      dynamic([q], ^acc and ^condition)
    end)
  end

  defp build_dynamic_condition(field, operators, schema, _opts) when is_map(operators) do
    if association?(schema, field) do
      # For associations in _or, we need to handle specially
      # This is a simplified version - full implementation would use subqueries
      dynamic(true)
    else
      Enum.reduce(operators, dynamic(true), fn {op, value}, acc ->
        condition = build_operator_dynamic(field, op, value)
        dynamic([q], ^acc and ^condition)
      end)
    end
  end

  defp build_dynamic_condition(_field, _value, _schema, _opts) do
    dynamic(true)
  end

  defp build_operator_dynamic(field, :_eq, nil), do: dynamic([q], is_nil(field(q, ^field)))
  defp build_operator_dynamic(field, :_eq, value), do: dynamic([q], field(q, ^field) == ^value)
  defp build_operator_dynamic(field, :_ne, nil), do: dynamic([q], not is_nil(field(q, ^field)))
  defp build_operator_dynamic(field, :_ne, value), do: dynamic([q], field(q, ^field) != ^value)
  defp build_operator_dynamic(field, :_gt, value), do: dynamic([q], field(q, ^field) > ^value)
  defp build_operator_dynamic(field, :_gte, value), do: dynamic([q], field(q, ^field) >= ^value)
  defp build_operator_dynamic(field, :_lt, value), do: dynamic([q], field(q, ^field) < ^value)
  defp build_operator_dynamic(field, :_lte, value), do: dynamic([q], field(q, ^field) <= ^value)

  defp build_operator_dynamic(field, :_in, values) when is_list(values) do
    dynamic([q], field(q, ^field) in ^values)
  end

  defp build_operator_dynamic(field, :_nin, values) when is_list(values) do
    dynamic([q], field(q, ^field) not in ^values)
  end

  defp build_operator_dynamic(field, :_like, value), do: dynamic([q], like(field(q, ^field), ^value))
  defp build_operator_dynamic(field, :_ilike, value), do: dynamic([q], ilike(field(q, ^field), ^value))
  defp build_operator_dynamic(field, :_is_null, true), do: dynamic([q], is_nil(field(q, ^field)))
  defp build_operator_dynamic(field, :_is_null, false), do: dynamic([q], not is_nil(field(q, ^field)))
  defp build_operator_dynamic(_field, _op, _value), do: dynamic(true)

  # ============================================================================
  # Helpers
  # ============================================================================

  defp association?(schema, field) do
    case schema.__schema__(:association, field) do
      nil -> false
      _ -> true
    end
  end

  @doc """
  Returns list of supported comparison operators.
  """
  def comparison_operators, do: @comparison_operators

  @doc """
  Returns list of supported list operators.
  """
  def list_operators, do: @list_operators

  @doc """
  Returns list of supported string operators.
  """
  def string_operators, do: @string_operators

  @doc """
  Returns list of supported null operators.
  """
  def null_operators, do: @null_operators

  @doc """
  Returns list of supported logical operators.
  """
  def logical_operators, do: @logical_operators

  @doc """
  Returns all supported operators.
  """
  def all_operators do
    @comparison_operators ++ @list_operators ++ @string_operators ++ @null_operators ++ @logical_operators
  end
end
