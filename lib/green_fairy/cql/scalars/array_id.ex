defmodule GreenFairy.CQL.Scalars.ArrayID do
  @moduledoc """
  CQL scalar for ID array fields (UUIDs, etc.).
  """

  @behaviour GreenFairy.CQL.Scalar

  @impl true
  def operator_input(adapter) do
    {operators, _type, _desc} = GreenFairy.CQL.Scalars.ArrayString.operator_input(adapter)
    {operators, :id, "Operators for ID array fields"}
  end

  @impl true
  def apply_operator(query, field, operator, value, adapter, opts) do
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
  def operator_type_identifier(_adapter), do: :cql_op_id_array_input
end
