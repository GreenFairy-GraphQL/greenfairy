defmodule GreenFairy.CQL.Adapters.Postgres do
  @moduledoc """
  PostgreSQL adapter for CQL operations.

  This adapter delegates all operator logic to scalar-specific implementations,
  providing only PostgreSQL-specific metadata and capabilities.

  ## Features

  - Full NULLS FIRST/LAST sort positioning
  - Native array operators (@>, &&)
  - Native ILIKE for case-insensitive matching
  - PostGIS geo ordering support
  - CASE-based priority ordering
  - BETWEEN operator for date ranges

  ## Architecture

  This adapter is a thin wrapper that:
  1. Declares PostgreSQL capabilities
  2. Delegates operator implementations to scalar modules
  3. Each scalar owns its PostgreSQL-specific logic

  Example: String operators are implemented in `GreenFairy.CQL.Scalars.String.Postgres`
  """

  @behaviour GreenFairy.CQL.Adapter

  alias GreenFairy.CQL.ScalarMapper

  # ============================================================================
  # Adapter Metadata
  # ============================================================================

  @impl true
  def sort_directions do
    [:asc, :desc, :asc_nulls_first, :asc_nulls_last, :desc_nulls_first, :desc_nulls_last]
  end

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
      array_operators_require_type_cast: true,
      native_arrays: true,
      supports_json_operators: true,
      supports_full_text_search: true,
      max_in_clause_items: 10000
    }
  end

  # ============================================================================
  # Type Mapping - Delegates to ScalarMapper
  # ============================================================================

  @impl true
  def operator_type_for(ecto_type) do
    ScalarMapper.operator_type_identifier(ecto_type, :postgres)
  end

  # ============================================================================
  # Operator Support - Queries scalars for their operators
  # ============================================================================

  @impl true
  def supported_operators(category, _field_type) do
    # This is now derived from scalar definitions
    # For now, return sensible defaults based on category
    case category do
      :scalar ->
        [
          :_eq,
          :_neq,
          :_gt,
          :_gte,
          :_lt,
          :_lte,
          :_in,
          :_nin,
          :_is_null,
          :_like,
          :_nlike,
          :_ilike,
          :_nilike,
          :_starts_with,
          :_istarts_with,
          :_ends_with,
          :_iends_with,
          :_contains,
          :_icontains
        ]

      :array ->
        [
          :_includes,
          :_excludes,
          :_includes_all,
          :_excludes_all,
          :_includes_any,
          :_excludes_any,
          :_is_empty,
          :_is_null
        ]

      :json ->
        [:_contains, :_contained_by, :_has_key, :_has_keys, :_has_any_keys]

      _ ->
        []
    end
  end

  # ============================================================================
  # Operator Input Generation - Delegates to Scalars
  # ============================================================================

  @impl true
  def operator_inputs do
    %{
      # Scalars
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
      # Arrays
      cql_op_id_array_input: scalar_operator_input({:array, :id}),
      cql_op_string_array_input: scalar_operator_input({:array, :string}),
      cql_op_integer_array_input: scalar_operator_input({:array, :integer}),
      cql_op_enum_array_input: scalar_operator_input({:array, {:parameterized, Ecto.Enum, %{}}}),
      # Generic array for unknown types
      cql_op_generic_array_input: {[:_includes, :_excludes, :_is_empty, :_is_null], :string, "Operators for generic array fields"}
    }
  end

  defp scalar_operator_input(ecto_type) do
    case ScalarMapper.operator_input(ecto_type, :postgres) do
      nil -> {[], :string, "Not filterable"}
      result -> result
    end
  end

  # ============================================================================
  # Operator Application - Delegates to Scalars
  # ============================================================================

  @impl true
  # Accept both 5-arg (direct call) and 6-arg (via primary adapter) forms
  def apply_operator(schema_or_query, field_or_query, operator_or_field, value_or_operator, opts_or_value, maybe_opts \\ [])

  # 5-arg form: (query, field, operator, value, opts) - direct call (tests)
  # When called with 5 args, maybe_opts defaults to []
  def apply_operator(query, field, operator, value, opts, []) when is_list(opts) do
    apply_operator_impl(query, field, operator, value, opts)
  end

  # 6-arg form: (schema, query, field, operator, value, opts) - called via primary adapter (Ecto)
  # When called with 6 explicit args, opts is the 6th argument (not the default)
  def apply_operator(_schema, query, field, operator, value, opts) when is_list(opts) and opts != [] do
    apply_operator_impl(query, field, operator, value, opts)
  end

  # 6-arg form with empty opts list - need to handle this case too
  def apply_operator(_schema, query, field, operator, value, opts) when is_list(opts) do
    apply_operator_impl(query, field, operator, value, opts)
  end

  defp apply_operator_impl(query, field, operator, value, opts) do
    field_type = Keyword.get(opts, :field_type)

    case ScalarMapper.scalar_for(field_type) do
      nil ->
        # Field type not filterable, return query unchanged
        query

      scalar_module ->
        # Delegate to the scalar implementation
        scalar_module.apply_operator(query, field, operator, value, :postgres, opts)
    end
  end
end
