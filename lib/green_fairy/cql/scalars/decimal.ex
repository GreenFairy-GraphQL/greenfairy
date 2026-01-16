defmodule GreenFairy.CQL.Scalars.Decimal do
  @moduledoc """
  CQL scalar for decimal fields.

  Provides numeric comparison operators identical to Integer.

  ## Adapter Variations

  - **SQL databases (Postgres, MySQL, SQLite, MSSQL)**: Standard Ecto queries
  - **Exlasticsearch**: Query DSL with term, range, and terms queries
  """

  @behaviour GreenFairy.CQL.Scalar

  @impl true
  def operator_input(_adapter) do
    {[:_eq, :_ne, :_neq, :_gt, :_gte, :_lt, :_lte, :_in, :_nin, :_is_null], :decimal,
     "Operators for decimal fields"}
  end

  @impl true
  def apply_operator(query, field, operator, value, :elasticsearch, opts) do
    __MODULE__.Exlasticsearch.apply_operator(query, field, operator, value, opts)
  end

  def apply_operator(query, field, operator, value, _adapter, opts) do
    __MODULE__.Ecto.apply_operator(query, field, operator, value, opts)
  end

  @impl true
  def operator_type_identifier(_adapter), do: :cql_op_decimal_input
end
