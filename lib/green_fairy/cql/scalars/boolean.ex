defmodule GreenFairy.CQL.Scalars.Boolean do
  @moduledoc """
  CQL scalar for boolean fields.

  ## Operators

  - `:_eq` / `:_neq` - Equality/inequality
  - `:_is_null` - Null check

  ## Adapter Variations

  - **SQL databases (Postgres, MySQL, SQLite, MSSQL)**: Standard Ecto queries
  - **Exlasticsearch**: Query DSL with term queries
  """

  @behaviour GreenFairy.CQL.Scalar

  @impl true
  def operator_input(_adapter) do
    {[:_eq, :_ne, :_neq, :_is_null], :boolean, "Operators for boolean fields"}
  end

  @impl true
  def apply_operator(query, field, operator, value, :elasticsearch, opts) do
    __MODULE__.Exlasticsearch.apply_operator(query, field, operator, value, opts)
  end

  def apply_operator(query, field, operator, value, _adapter, opts) do
    __MODULE__.Ecto.apply_operator(query, field, operator, value, opts)
  end

  @impl true
  def operator_type_identifier(_adapter), do: :cql_op_boolean_input
end
