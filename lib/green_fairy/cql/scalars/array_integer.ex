defmodule GreenFairy.CQL.Scalars.ArrayInteger do
  @moduledoc """
  CQL scalar for integer array fields.

  ## Operators

  - `:_includes` - Array contains value
  - `:_excludes` - Array does not contain value
  - `:_includes_all` - Array contains all values
  - `:_excludes_all` - Array contains none of the values
  - `:_includes_any` - Array contains any of the values
  - `:_excludes_any` - Array does not contain all values
  - `:_is_empty` - Array is empty
  - `:_is_null` - Array is null

  ## Adapter Variations

  - **PostgreSQL**: Native array operators with integer casting
  - **MySQL/SQLite/MSSQL**: JSON-based storage (delegates to ArrayString)
  """

  @behaviour GreenFairy.CQL.Scalar

  @impl true
  def operator_input(:postgres), do: __MODULE__.Postgres.operator_input()
  def operator_input(adapter) do
    {operators, _type, _desc} = GreenFairy.CQL.Scalars.ArrayString.operator_input(adapter)
    {operators, :integer, "Operators for integer array fields"}
  end

  @impl true
  def apply_operator(query, field, operator, value, :postgres, opts) do
    __MODULE__.Postgres.apply_operator(query, field, operator, value, opts)
  end

  def apply_operator(query, field, operator, value, adapter, opts) do
    # Non-Postgres adapters use JSON storage, delegate to ArrayString
    GreenFairy.CQL.Scalars.ArrayString.apply_operator(
      query,
      field,
      operator,
      value,
      adapter,
      opts
    )
  end

  @impl true
  def operator_type_identifier(_adapter), do: :cql_op_integer_array_input
end
