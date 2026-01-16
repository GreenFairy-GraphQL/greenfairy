defmodule GreenFairy.CQL.Scalars.DateTime.PeriodInput do
  @moduledoc """
  Input type for the `_period` operator on date/time fields.

  Allows filtering records by relative time periods (last N or next N units).

  ## Fields

  - `direction` - Whether to look in the past (LAST) or future (NEXT)
  - `unit` - Time unit (HOUR, DAY, WEEK, MONTH, QUARTER, YEAR)
  - `count` - Number of units (default: 1)

  ## Examples

      # Last 7 days
      {
        _period: {
          direction: LAST,
          unit: DAY,
          count: 7
        }
      }

      # Next 3 months
      {
        _period: {
          direction: NEXT,
          unit: MONTH,
          count: 3
        }
      }

      # Last hour (count defaults to 1)
      {
        _period: {
          direction: LAST,
          unit: HOUR
        }
      }

  ## Database Translation

  - **PostgreSQL**: `field >= NOW() - INTERVAL '7 days' AND field < NOW()`
  - **MySQL**: `field >= DATE_SUB(NOW(), INTERVAL 7 DAY) AND field < NOW()`
  - **SQLite**: `field >= datetime('now', '-7 days') AND field < datetime('now')`
  - **MSSQL**: `field >= DATEADD(DAY, -7, GETDATE()) AND field < GETDATE()`
  - **Elasticsearch**: `field: {gte: "now-7d", lt: "now"}`
  """

  use GreenFairy.Input

  input "CqlPeriodInput" do
    @desc "Direction: LAST (past) or NEXT (future)"
    field :direction, non_null(:cql_period_direction)

    @desc "Time unit"
    field :unit, non_null(:cql_period_unit)

    @desc "Number of units (default: 1)"
    field :count, :integer, default_value: 1
  end
end
