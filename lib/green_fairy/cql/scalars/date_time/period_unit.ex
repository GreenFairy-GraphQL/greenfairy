defmodule GreenFairy.CQL.Scalars.DateTime.PeriodUnit do
  @moduledoc """
  Enum for time period units in date/time filtering.

  Used with `_period` and `_current_period` operators to specify
  the granularity of time-based filtering.

  ## Values

  - `:hour` - Hour period
  - `:day` - Day period
  - `:week` - Week period (Monday to Sunday by default, configurable)
  - `:month` - Calendar month period
  - `:quarter` - Quarter period (3 months: Q1=Jan-Mar, Q2=Apr-Jun, Q3=Jul-Sep, Q4=Oct-Dec)
  - `:year` - Calendar year period

  ## Examples

      # Current week
      %{unit: :week}

      # Last 30 days
      %{direction: :last, unit: :day, count: 30}

      # This quarter
      %{unit: :quarter}
  """

  use GreenFairy.Enum

  enum "CqlPeriodUnit" do
    value :hour, description: "Hour period"
    value :day, description: "Day period"
    value :week, description: "Week period"
    value :month, description: "Month period"
    value :quarter, description: "Quarter period (3 months)"
    value :year, description: "Year period"
  end
end
