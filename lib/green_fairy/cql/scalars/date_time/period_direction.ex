defmodule GreenFairy.CQL.Scalars.DateTime.PeriodDirection do
  @moduledoc """
  Enum for period direction in date/time filtering.

  Used with the `_period` operator to specify whether to filter
  records in the past (LAST) or future (NEXT).

  ## Values

  - `:last` - Filter records in the past relative to now
  - `:next` - Filter records in the future relative to now

  ## Example

      # Last 7 days
      %{direction: :last, unit: :day, count: 7}

      # Next 3 months
      %{direction: :next, unit: :month, count: 3}
  """

  use GreenFairy.Enum

  enum "CqlPeriodDirection" do
    value :last, description: "Filter records in the past"
    value :next, description: "Filter records in the future"
  end
end
