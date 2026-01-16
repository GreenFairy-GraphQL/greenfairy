defmodule GreenFairy.CQL.Scalars.Time do
  @moduledoc """
  CQL scalar for time fields (time, time_usec).
  """

  @behaviour GreenFairy.CQL.Scalar

  @impl true
  def operator_input(_adapter) do
    {[:_eq, :_ne, :_neq, :_gt, :_gte, :_lt, :_lte, :_in, :_nin, :_is_null], :time,
     "Operators for time fields"}
  end

  @impl true
  def apply_operator(query, field, operator, value, adapter, opts) do
    GreenFairy.CQL.Scalars.Integer.apply_operator(query, field, operator, value, adapter, opts)
  end

  @impl true
  def operator_type_identifier(_adapter), do: :cql_op_time_input
end
