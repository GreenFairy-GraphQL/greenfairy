defmodule GreenFairy.CQL.Scalars.Integer do
  @moduledoc """
  CQL scalar for integer fields.

  Provides numeric comparison operators.

  ## Operators

  - `:_eq` / `:_neq` - Equality/inequality
  - `:_gt` / `:_gte` / `:_lt` / `:_lte` - Numeric comparison
  - `:_in` / `:_nin` - List membership
  - `:_is_null` - Null check

  ## Adapter Variations

  - **SQL databases (Postgres, MySQL, SQLite, MSSQL)**: Standard Ecto queries
  - **Exlasticsearch**: Query DSL with term, range, and terms queries
  """

  @behaviour GreenFairy.CQL.Scalar

  @impl true
  def operator_input(_adapter) do
    {[:_eq, :_ne, :_neq, :_gt, :_gte, :_lt, :_lte, :_in, :_nin, :_is_null], :integer,
     "Operators for integer fields"}
  end

  @impl true
  def apply_operator(query, field, operator, value, :elasticsearch, opts) do
    __MODULE__.Exlasticsearch.apply_operator(query, field, operator, value, opts)
  end

  def apply_operator(query, field, operator, value, _adapter, opts) do
    __MODULE__.Ecto.apply_operator(query, field, operator, value, opts)
  end

  @impl true
  def operator_type_identifier(_adapter), do: :cql_op_integer_input
end
