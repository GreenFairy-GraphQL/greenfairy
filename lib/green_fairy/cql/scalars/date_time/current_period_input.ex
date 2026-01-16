defmodule GreenFairy.CQL.Scalars.DateTime.CurrentPeriodInput do
  @moduledoc """
  Input type for the `_current_period` operator on date/time fields.

  Allows filtering records within the current time period (today, this week, this month, etc.).

  ## Fields

  - `unit` - Time unit defining the current period (HOUR, DAY, WEEK, MONTH, QUARTER, YEAR)

  ## Examples

      # Today
      {
        _current_period: {
          unit: DAY
        }
      }

      # This week
      {
        _current_period: {
          unit: WEEK
        }
      }

      # This month
      {
        _current_period: {
          unit: MONTH
        }
      }

      # This quarter
      {
        _current_period: {
          unit: QUARTER
        }
      }

  ## Database Translation

  Each database uses native date functions to calculate the start and end of the current period:

  - **PostgreSQL**: `date_trunc('week', NOW())` to `date_trunc('week', NOW()) + INTERVAL '1 week'`
  - **MySQL**: `DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY)` to start + 1 WEEK
  - **SQLite**: `date('now', 'weekday 0', '-7 days')` to `date('now', 'weekday 0')`
  - **MSSQL**: `DATEADD(DAY, 1-DATEPART(WEEKDAY, GETDATE()), CAST(GETDATE() AS DATE))`
  - **Elasticsearch**: `field: {gte: "now/w", lt: "now/w+1w"}`

  ## Week Start Configuration

  By default, weeks start on Monday (ISO 8601). Configure via:

      config :green_fairy, week_start: :monday  # or :sunday
  """

  use GreenFairy.Input

  input "CqlCurrentPeriodInput" do
    @desc "Time unit defining the current period"
    field :unit, non_null(:cql_period_unit)
  end
end
