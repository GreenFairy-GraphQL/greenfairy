defmodule GreenFairy.CQL.Scalars.ID do
  @moduledoc """
  CQL scalar for ID fields (UUID, integer primary keys, etc.).

  ## Operators

  - `:_eq` / `:_neq` - Equality/inequality
  - `:_in` / `:_nin` - List membership
  - `:_is_null` - Null check

  Note: IDs don't support comparison operators like _gt, _lt.

  ## Adapter Variations

  - **SQL databases (Postgres, MySQL, SQLite, MSSQL)**: Standard Ecto queries
  - **Exlasticsearch**: Query DSL with term and terms queries
  """

  @behaviour GreenFairy.CQL.Scalar

  @impl true
  def operator_input(_adapter) do
    {[:_eq, :_ne, :_neq, :_in, :_nin, :_is_null], :id, "Operators for ID fields"}
  end

  @impl true
  def apply_operator(query, field, operator, value, :elasticsearch, opts) do
    __MODULE__.Exlasticsearch.apply_operator(query, field, operator, value, opts)
  end

  def apply_operator(query, field, operator, value, _adapter, opts) do
    __MODULE__.Ecto.apply_operator(query, field, operator, value, opts)
  end

  @impl true
  def operator_type_identifier(_adapter), do: :cql_op_id_input
end
