defmodule GreenFairy.CQL.Adapters.Elasticsearch do
  @moduledoc """
  Elasticsearch adapter for CQL operations.

  Unique adapter that uses Query DSL instead of SQL - delegates to scalar implementations.
  """

  @behaviour GreenFairy.CQL.Adapter

  alias GreenFairy.CQL.ScalarMapper

  @impl true
  def sort_directions, do: [:asc, :desc, :_score, :_geo_distance]

  @impl true
  def sort_direction_enum(nil), do: :cql_sort_direction
  def sort_direction_enum(namespace), do: :"cql_#{namespace}_sort_direction"

  @impl true
  def supports_geo_ordering?, do: true

  @impl true
  def supports_priority_ordering?, do: true

  @impl true
  def capabilities do
    %{
      array_operators_require_type_cast: false,
      native_arrays: true,
      supports_json_operators: true,
      supports_full_text_search: true,
      max_in_clause_items: 65536,
      query_dsl_based: true,
      supports_fuzzy_search: true,
      supports_geo_queries: true,
      supports_nested_documents: true
    }
  end

  @impl true
  def operator_type_for(ecto_type) do
    ScalarMapper.operator_type_identifier(ecto_type, :elasticsearch)
  end

  @impl true
  def supported_operators(category, _field_type) do
    case category do
      :scalar ->
        [:_eq, :_neq, :_in, :_nin, :_is_null, :_like, :_nlike, :_ilike, :_nilike,
         :_gt, :_gte, :_lt, :_lte,
         :_starts_with, :_istarts_with, :_ends_with, :_iends_with, :_contains, :_icontains,
         # Elasticsearch-specific
         :_match, :_match_phrase, :_match_phrase_prefix, :_fuzzy, :_prefix, :_regexp, :_wildcard]

      :array ->
        [:_includes, :_excludes, :_includes_all, :_excludes_all, :_includes_any,
         :_excludes_any, :_is_empty, :_is_null]

      :json ->
        [:_contains, :_has_key, :_nested]

      _ ->
        []
    end
  end

  @impl true
  def operator_inputs do
    %{
      cql_op_id_input: scalar_operator_input(:id),
      cql_op_string_input: scalar_operator_input(:string),
      cql_op_integer_input: scalar_operator_input(:integer),
      cql_op_float_input: scalar_operator_input(:float),
      cql_op_decimal_input: scalar_operator_input(:decimal),
      cql_op_boolean_input: scalar_operator_input(:boolean),
      cql_op_date_time_input: scalar_operator_input(:utc_datetime),
      cql_op_naive_date_time_input: scalar_operator_input(:naive_datetime),
      cql_op_date_input: scalar_operator_input(:date),
      cql_op_time_input: scalar_operator_input(:time),
      cql_op_enum_input: scalar_operator_input({:parameterized, Ecto.Enum, %{}}),
      cql_op_id_array_input: scalar_operator_input({:array, :id}),
      cql_op_string_array_input: scalar_operator_input({:array, :string}),
      cql_op_integer_array_input: scalar_operator_input({:array, :integer}),
      cql_op_enum_array_input: scalar_operator_input({:array, {:parameterized, Ecto.Enum, %{}}}),
      # Generic array for unknown types
      cql_op_generic_array_input: {[:_includes, :_excludes, :_includes_all, :_excludes_all, :_includes_any, :_excludes_any, :_is_empty, :_is_null], :string, "Operators for generic array fields"}
    }
  end

  defp scalar_operator_input(ecto_type) do
    case ScalarMapper.operator_input(ecto_type, :elasticsearch) do
      nil -> {[], :string, "Not filterable"}
      result -> result
    end
  end

  @impl true
  def apply_operator(query, field, operator, value, opts) do
    field_type = Keyword.get(opts, :field_type)

    case ScalarMapper.scalar_for(field_type) do
      nil -> query
      scalar_module -> scalar_module.apply_operator(query, field, operator, value, :elasticsearch, opts)
    end
  end

  # Helper functions for Elasticsearch Query DSL initialization
  # These are used by tests and can be used by applications to start building ES queries

  @doc """
  Initializes an empty Elasticsearch Query DSL structure.

  Returns a map with the standard bool query structure.

  ## Example

      iex> Elasticsearch.init_query()
      %{
        query: %{
          bool: %{
            must: [],
            must_not: [],
            should: [],
            filter: []
          }
        }
      }
  """
  def init_query do
    %{
      query: %{
        bool: %{
          must: [],
          must_not: [],
          should: [],
          filter: []
        }
      }
    }
  end

  @doc """
  Builds an Elasticsearch Query DSL from a filter map.

  Converts a CQL-style filter map into an Elasticsearch query structure.

  ## Example

      iex> Elasticsearch.build_query(%{name: %{_eq: "John"}, age: %{_gt: 18}})
      %{query: %{bool: %{must: [...]}}}

  ## With field types

      iex> Elasticsearch.build_query(%{name: %{_eq: "John"}}, %{name: :string})
      %{query: %{bool: %{must: [...]}}}
  """
  def build_query(filters, field_types \\ %{})

  def build_query(filters, field_types) when is_map(filters) do
    query = init_query()

    Enum.reduce(filters, query, fn {field, operators}, acc ->
      Enum.reduce(operators, acc, fn {operator, value}, inner_acc ->
        field_type = Map.get(field_types, field)
        opts = if field_type, do: [field_type: field_type], else: []
        apply_operator(inner_acc, field, operator, value, opts)
      end)
    end)
  end
end
