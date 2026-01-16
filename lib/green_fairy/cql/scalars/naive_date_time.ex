defmodule GreenFairy.CQL.Scalars.NaiveDateTime do
  @moduledoc """
  CQL scalar for naive datetime fields (naive_datetime, naive_datetime_usec).
  """

  @behaviour GreenFairy.CQL.Scalar

  @impl true
  def operator_input(adapter) do
    {operators, _type, description} = GreenFairy.CQL.Scalars.DateTime.operator_input(adapter)
    {operators, :naive_datetime, description}
  end

  @impl true
  def apply_operator(query, field, operator, value, adapter, opts) do
    GreenFairy.CQL.Scalars.DateTime.apply_operator(query, field, operator, value, adapter, opts)
  end

  @impl true
  def operator_type_identifier(_adapter), do: :cql_op_naive_date_time_input
end
