defmodule GreenFairy.CQL.Adapters.Ecto do
  @moduledoc """
  Generic Ecto adapter for CQL operations.

  This adapter provides a conservative set of operators that work across
  any Ecto-compatible database. Use this as a fallback for databases without
  a specific adapter.

  ## Supported Operations

  Only standard SQL operations that work everywhere:
  - Comparison: `_eq`, `_neq`, `_gt`, `_gte`, `_lt`, `_lte`
  - Lists: `_in`, `_nin`
  - Null: `_is_null`
  - Pattern: `_like` (case-sensitive only)
  - Sort: `asc`, `desc` (no NULLS positioning)

  ## What's NOT Supported

  - `_ilike` (Postgres-specific, would need LOWER() emulation)
  - Native array operators (database-specific)
  - NULLS FIRST/LAST (not universally supported)
  - JSON operators (syntax varies widely)

  ## Usage

  This adapter is automatically selected when GreenFairy detects an unknown
  Ecto adapter. You can also configure it explicitly:

      config :green_fairy, :cql_adapter, GreenFairy.CQL.Adapters.Ecto

  """

  @behaviour GreenFairy.CQL.Adapter

  alias GreenFairy.CQL.ScalarMapper

  @impl true
  def sort_directions, do: [:asc, :desc]

  @impl true
  def sort_direction_enum(nil), do: :cql_sort_direction
  def sort_direction_enum(namespace), do: :"cql_#{namespace}_sort_direction"

  @impl true
  def supports_geo_ordering?, do: false

  @impl true
  def supports_priority_ordering?, do: false

  @impl true
  def capabilities do
    %{
      array_operators_require_type_cast: false,
      native_arrays: false,
      supports_json_operators: false,
      supports_full_text_search: false,
      max_in_clause_items: 100,
      generic_fallback: true
    }
  end

  @impl true
  def operator_type_for(ecto_type) do
    # Use generic mapping - no database-specific features
    ScalarMapper.operator_type_identifier(ecto_type, :ecto)
  end

  @impl true
  def supported_operators(category, _field_type) do
    case category do
      :scalar ->
        # Conservative set - only standard SQL
        [:_eq, :_neq, :_gt, :_gte, :_lt, :_lte, :_in, :_nin, :_is_null, :_like, :_nlike]

      :array ->
        # No native array support in generic adapter
        [:_is_null]

      :json ->
        # No JSON support - too database-specific
        []

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
      cql_op_enum_input: scalar_operator_input({:parameterized, Ecto.Enum, %{}})
      # No array inputs for generic adapter
    }
  end

  defp scalar_operator_input(ecto_type) do
    case ScalarMapper.operator_input(ecto_type, :ecto) do
      nil -> {[], :string, "Not filterable"}
      result -> result
    end
  end

  @impl true
  def apply_operator(schema_or_query, field_or_query, operator_or_field, value_or_operator, opts_or_value, maybe_opts \\ [])

  def apply_operator(query, field, operator, value, opts, []) when is_list(opts) do
    apply_operator_impl(query, field, operator, value, opts)
  end

  def apply_operator(_schema, query, field, operator, value, opts) when is_list(opts) and opts != [] do
    apply_operator_impl(query, field, operator, value, opts)
  end

  def apply_operator(_schema, query, field, operator, value, opts) when is_list(opts) do
    apply_operator_impl(query, field, operator, value, opts)
  end

  defp apply_operator_impl(query, field, operator, value, opts) do
    field_type = Keyword.get(opts, :field_type)

    case ScalarMapper.scalar_for(field_type) do
      nil -> query
      scalar_module -> scalar_module.apply_operator(query, field, operator, value, :ecto, opts)
    end
  end
end
