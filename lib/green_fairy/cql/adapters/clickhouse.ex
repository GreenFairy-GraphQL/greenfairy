defmodule GreenFairy.CQL.Adapters.ClickHouse do
  @moduledoc """
  ClickHouse adapter for CQL operations.

  Supports the `ecto_ch` adapter (https://github.com/plausible/ecto_ch).

  ## Features

  - Standard comparison operators
  - Native array support via `has()`, `hasAll()`, `hasAny()` functions
  - Case-insensitive matching via `ilike()` function (ClickHouse 21.12+)
  - NULLS FIRST/LAST support via `nullsFirst`/`nullsLast`

  ## ClickHouse-Specific Behavior

  - Arrays are first-class citizens with efficient operations
  - Boolean columns are typically stored as UInt8 (0/1)
  - Date/DateTime handling differs from standard SQL
  - No native JSON containment operators (use JSONExtract functions)

  ## Usage

  Configure your Ecto repo to use `ecto_ch`:

      # In your repo
      defmodule MyApp.ClickHouseRepo do
        use Ecto.Repo, otp_app: :my_app, adapter: Ecto.Adapters.ClickHouse
      end

  GreenFairy will auto-detect the adapter, or configure explicitly:

      config :green_fairy, :cql_adapter, GreenFairy.CQL.Adapters.ClickHouse

  """

  @behaviour GreenFairy.CQL.Adapter

  alias GreenFairy.CQL.ScalarMapper

  @impl true
  def sort_directions do
    [:asc, :desc, :asc_nulls_first, :asc_nulls_last, :desc_nulls_first, :desc_nulls_last]
  end

  @impl true
  def sort_direction_enum(nil), do: :cql_sort_direction
  def sort_direction_enum(namespace), do: :"cql_#{namespace}_sort_direction"

  @impl true
  def supports_geo_ordering?, do: false

  @impl true
  def supports_priority_ordering?, do: true

  @impl true
  def capabilities do
    %{
      array_operators_require_type_cast: false,
      native_arrays: true,
      supports_json_operators: false,  # Use JSONExtract* functions manually
      supports_full_text_search: false,
      max_in_clause_items: 10000,
      emulated_ilike: false,  # Native ilike() function
      column_oriented: true
    }
  end

  @impl true
  def operator_type_for(ecto_type) do
    ScalarMapper.operator_type_identifier(ecto_type, :clickhouse)
  end

  @impl true
  def supported_operators(category, _field_type) do
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
          :_includes,       # has(array, element)
          :_excludes,       # NOT has(array, element)
          :_includes_all,   # hasAll(array, elements)
          :_excludes_all,   # NOT hasAll(...)
          :_includes_any,   # hasAny(array, elements)
          :_excludes_any,   # NOT hasAny(...)
          :_is_empty,       # empty(array)
          :_is_null
        ]

      :json ->
        # ClickHouse uses JSONExtract* functions, not operators
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
      cql_op_enum_input: scalar_operator_input({:parameterized, Ecto.Enum, %{}}),
      # Arrays
      cql_op_id_array_input: scalar_operator_input({:array, :id}),
      cql_op_string_array_input: scalar_operator_input({:array, :string}),
      cql_op_integer_array_input: scalar_operator_input({:array, :integer}),
      cql_op_enum_array_input: scalar_operator_input({:array, {:parameterized, Ecto.Enum, %{}}})
    }
  end

  defp scalar_operator_input(ecto_type) do
    case ScalarMapper.operator_input(ecto_type, :clickhouse) do
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
      scalar_module -> scalar_module.apply_operator(query, field, operator, value, :clickhouse, opts)
    end
  end
end
