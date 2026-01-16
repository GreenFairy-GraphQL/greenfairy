defmodule GreenFairy.CQL.SortDirection do
  @moduledoc """
  Defines the sort direction enum for CQL ordering.
  """

  use GreenFairy.Enum

  enum "CqlSortDirection" do
    @desc "Sort in ascending order"
    value :asc

    @desc "Sort in descending order"
    value :desc

    @desc "Sort in ascending order, nulls first"
    value :asc_nulls_first

    @desc "Sort in ascending order, nulls last"
    value :asc_nulls_last

    @desc "Sort in descending order, nulls first"
    value :desc_nulls_first

    @desc "Sort in descending order, nulls last"
    value :desc_nulls_last
  end
end
