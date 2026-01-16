defmodule GreenFairy.CQL.OrderInput do
  @moduledoc """
  Defines standard order input type for CQL ordering.
  """

  use GreenFairy.Input

  input "CqlOrderStandardInput" do
    @desc "Sort direction"
    field :direction, non_null(:cql_sort_direction)

    @desc "Priority for multi-field sorting (lower number = higher priority)"
    field :priority, :integer
  end
end
