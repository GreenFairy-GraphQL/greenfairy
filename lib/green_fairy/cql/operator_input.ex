defmodule GreenFairy.CQL.OperatorInput do
  @moduledoc """
  Alias for GreenFairy.CQL.Schema.OperatorInput for backwards compatibility.

  This module re-exports all functions from the Schema.OperatorInput module.
  """

  defdelegate type_for(type), to: GreenFairy.CQL.Schema.OperatorInput
  defdelegate array_type_for(type), to: GreenFairy.CQL.Schema.OperatorInput
  defdelegate scalar_for(type), to: GreenFairy.CQL.Schema.OperatorInput
  defdelegate operator_types(), to: GreenFairy.CQL.Schema.OperatorInput
  defdelegate generate_all(opts \\ []), to: GreenFairy.CQL.Schema.OperatorInput
  defdelegate operator_category(identifier), to: GreenFairy.CQL.Schema.OperatorInput
  defdelegate generate_input(identifier, operators, scalar_type, description), to: GreenFairy.CQL.Schema.OperatorInput
end
