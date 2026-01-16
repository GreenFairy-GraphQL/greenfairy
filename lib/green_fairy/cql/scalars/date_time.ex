defmodule GreenFairy.CQL.Scalars.DateTime do
  @moduledoc """
  CQL scalar for datetime fields (utc_datetime, utc_datetime_usec).

  ## Operators

  Standard comparison:
  - `:_eq` / `:_neq` - Equality/inequality
  - `:_gt` / `:_gte` / `:_lt` / `:_lte` - Temporal comparison
  - `:_in` / `:_nin` - List membership
  - `:_is_null` - Null check
  - `:_between` - Range query

  Period operators:
  - `:_period` - Relative time periods (last/next N units)
  - `:_current_period` - Current time period (today, this week, etc.)

  ## Period Operator Examples

      # Last 7 days
      %{direction: :last, unit: :day, count: 7}

      # This week
      %{unit: :week}

      # Next 3 months
      %{direction: :next, unit: :month, count: 3}

  ## Adapter Support

  - **Ecto (SQL)**: PostgreSQL, MySQL, SQLite, MSSQL with native date functions
  - **Exlasticsearch**: Uses Elasticsearch date math expressions

  ## Owned Types

  This scalar owns the following auxiliary types:
  - `GreenFairy.CQL.Scalars.DateTime.PeriodDirection` - LAST/NEXT enum
  - `GreenFairy.CQL.Scalars.DateTime.PeriodUnit` - HOUR/DAY/WEEK/MONTH/QUARTER/YEAR enum
  - `GreenFairy.CQL.Scalars.DateTime.PeriodInput` - Input for `_period` operator
  - `GreenFairy.CQL.Scalars.DateTime.CurrentPeriodInput` - Input for `_current_period` operator
  """

  @behaviour GreenFairy.CQL.Scalar

  @base_operators [:_eq, :_ne, :_neq, :_gt, :_gte, :_lt, :_lte, :_in, :_nin, :_is_null]
  @period_operators [:_between, :_period, :_current_period]

  @impl true
  def operator_input(:postgres) do
    {@base_operators ++ @period_operators, :datetime, "Operators for datetime fields with period support"}
  end

  def operator_input(:mysql) do
    {@base_operators ++ @period_operators, :datetime, "Operators for datetime fields with period support"}
  end

  def operator_input(:sqlite) do
    {@base_operators ++ @period_operators, :datetime, "Operators for datetime fields with period support"}
  end

  def operator_input(:mssql) do
    {@base_operators ++ @period_operators, :datetime, "Operators for datetime fields with period support"}
  end

  def operator_input(:elasticsearch) do
    {@base_operators ++ @period_operators, :datetime, "Operators for datetime fields with period support"}
  end

  def operator_input(_adapter) do
    {@base_operators ++ @period_operators, :datetime, "Operators for datetime fields with period support"}
  end

  @impl true
  def apply_operator(query, field, operator, value, :elasticsearch, opts) do
    __MODULE__.Exlasticsearch.apply_operator(query, field, operator, value, opts)
  end

  def apply_operator(query, field, operator, value, adapter, opts) do
    __MODULE__.Ecto.apply_operator(query, field, operator, value, Keyword.put(opts, :adapter, adapter))
  end

  @impl true
  def operator_type_identifier(_adapter), do: :cql_op_date_time_input

  @doc """
  Returns the list of auxiliary type modules owned by this scalar.

  These types are automatically discovered and registered with the schema.
  """
  def auxiliary_types do
    [
      __MODULE__.PeriodDirection,
      __MODULE__.PeriodUnit,
      __MODULE__.PeriodInput,
      __MODULE__.CurrentPeriodInput
    ]
  end
end
