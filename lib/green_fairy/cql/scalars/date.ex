defmodule GreenFairy.CQL.Scalars.Date do
  @moduledoc """
  CQL scalar for date fields.
  """

  @behaviour GreenFairy.CQL.Scalar

  @impl true
  def operator_input(adapter) do
    {operators, _type, description} = GreenFairy.CQL.Scalars.DateTime.operator_input(adapter)
    {operators, :date, description}
  end

  @impl true
  def apply_operator(query, field, operator, value, adapter, opts) do
    GreenFairy.CQL.Scalars.DateTime.apply_operator(query, field, operator, value, adapter, opts)
  end

  @impl true
  def operator_type_identifier(_adapter), do: :cql_op_date_input
end
