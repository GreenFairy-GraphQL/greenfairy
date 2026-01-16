defmodule GreenFairy.CQL.Scalars.DateTime.Ecto do
  @moduledoc """
  Ecto/SQL implementation for DateTime operators.

  Supports standard comparison operators plus special period operators:
  - `_between` - Range query
  - `_period` - Relative time periods (last/next N units)
  - `_current_period` - Current time period (today, this week, etc.)

  ## Database Support

  Works across Postgres, MySQL, SQLite, and MSSQL using adapter-specific
  date functions.
  """

  import Ecto.Query, only: [where: 3]

  alias GreenFairy.CQL.Scalars.Integer

  def apply_operator(query, field, :_between, [start_val, end_val], opts) do
    binding = Keyword.get(opts, :binding)
    apply_between(query, field, start_val, end_val, binding)
  end

  def apply_operator(query, field, :_period, %{direction: direction, unit: unit, count: count}, opts) do
    binding = Keyword.get(opts, :binding)
    adapter = Keyword.get(opts, :adapter, :postgres)
    apply_period(query, field, direction, unit, count, adapter, binding)
  end

  # Default count to 1 if not provided
  def apply_operator(query, field, :_period, %{direction: direction, unit: unit}, opts) do
    apply_operator(query, field, :_period, %{direction: direction, unit: unit, count: 1}, opts)
  end

  def apply_operator(query, field, :_current_period, %{unit: unit}, opts) do
    binding = Keyword.get(opts, :binding)
    adapter = Keyword.get(opts, :adapter, :postgres)
    apply_current_period(query, field, unit, adapter, binding)
  end

  def apply_operator(query, field, operator, value, opts) do
    # Reuse integer comparison logic for dates
    Integer.apply_operator(query, field, operator, value, Keyword.get(opts, :adapter, :postgres), opts)
  end

  # _between implementation
  defp apply_between(query, field, start_val, end_val, nil) do
    where(query, [q], fragment("? BETWEEN ? AND ?", field(q, ^field), ^start_val, ^end_val))
  end

  defp apply_between(query, field, start_val, end_val, binding) do
    where(
      query,
      [{^binding, a}],
      fragment("? BETWEEN ? AND ?", field(a, ^field), ^start_val, ^end_val)
    )
  end

  # _period implementation - dispatches to adapter-specific functions
  defp apply_period(query, field, direction, unit, count, :postgres, binding) do
    apply_period_postgres(query, field, direction, unit, count, binding)
  end

  defp apply_period(query, field, direction, unit, count, :mysql, binding) do
    apply_period_mysql(query, field, direction, unit, count, binding)
  end

  defp apply_period(query, field, direction, unit, count, :sqlite, binding) do
    apply_period_sqlite(query, field, direction, unit, count, binding)
  end

  defp apply_period(query, field, direction, unit, count, :mssql, binding) do
    apply_period_mssql(query, field, direction, unit, count, binding)
  end

  defp apply_period(query, field, direction, unit, count, _adapter, binding) do
    # Default to Postgres behavior for unknown adapters
    apply_period_postgres(query, field, direction, unit, count, binding)
  end

  # _current_period implementation - dispatches to adapter-specific functions
  defp apply_current_period(query, field, unit, :postgres, binding) do
    apply_current_period_postgres(query, field, unit, binding)
  end

  defp apply_current_period(query, field, unit, :mysql, binding) do
    apply_current_period_mysql(query, field, unit, binding)
  end

  defp apply_current_period(query, field, unit, :sqlite, binding) do
    apply_current_period_sqlite(query, field, unit, binding)
  end

  defp apply_current_period(query, field, unit, :mssql, binding) do
    apply_current_period_mssql(query, field, unit, binding)
  end

  defp apply_current_period(query, field, unit, _adapter, binding) do
    # Default to Postgres behavior for unknown adapters
    apply_current_period_postgres(query, field, unit, binding)
  end

  # PostgreSQL period operators
  defp apply_period_postgres(query, field, :last, unit, count, binding) do
    interval = interval_string(unit, count)

    if binding do
      where(query, [{^binding, q}],
        fragment("? >= CURRENT_TIMESTAMP - INTERVAL ? AND ? < CURRENT_TIMESTAMP",
          field(q, ^field), ^interval, field(q, ^field)))
    else
      where(query, [q],
        fragment("? >= CURRENT_TIMESTAMP - INTERVAL ? AND ? < CURRENT_TIMESTAMP",
          field(q, ^field), ^interval, field(q, ^field)))
    end
  end

  defp apply_period_postgres(query, field, :next, unit, count, binding) do
    interval = interval_string(unit, count)

    if binding do
      where(query, [{^binding, q}],
        fragment("? > CURRENT_TIMESTAMP AND ? <= CURRENT_TIMESTAMP + INTERVAL ?",
          field(q, ^field), field(q, ^field), ^interval))
    else
      where(query, [q],
        fragment("? > CURRENT_TIMESTAMP AND ? <= CURRENT_TIMESTAMP + INTERVAL ?",
          field(q, ^field), field(q, ^field), ^interval))
    end
  end

  defp apply_current_period_postgres(query, field, unit, binding) do
    trunc_unit = postgres_trunc_unit(unit)
    interval = interval_string(unit, 1)

    if binding do
      where(query, [{^binding, q}],
        fragment("? >= date_trunc(?, CURRENT_TIMESTAMP) AND ? < date_trunc(?, CURRENT_TIMESTAMP) + INTERVAL ?",
          field(q, ^field), ^trunc_unit, field(q, ^field), ^trunc_unit, ^interval))
    else
      where(query, [q],
        fragment("? >= date_trunc(?, CURRENT_TIMESTAMP) AND ? < date_trunc(?, CURRENT_TIMESTAMP) + INTERVAL ?",
          field(q, ^field), ^trunc_unit, field(q, ^field), ^trunc_unit, ^interval))
    end
  end

  # MySQL period operators
  defp apply_period_mysql(query, field, :last, unit, count, binding) do
    {unit_str, unit_val} = mysql_interval_parts(unit, count)

    if binding do
      where(query, [{^binding, q}],
        fragment("? >= DATE_SUB(NOW(), INTERVAL ? ?) AND ? < NOW()",
          field(q, ^field), ^unit_val, ^unit_str, field(q, ^field)))
    else
      where(query, [q],
        fragment("? >= DATE_SUB(NOW(), INTERVAL ? ?) AND ? < NOW()",
          field(q, ^field), ^unit_val, ^unit_str, field(q, ^field)))
    end
  end

  defp apply_period_mysql(query, field, :next, unit, count, binding) do
    {unit_str, unit_val} = mysql_interval_parts(unit, count)

    if binding do
      where(query, [{^binding, q}],
        fragment("? > NOW() AND ? <= DATE_ADD(NOW(), INTERVAL ? ?)",
          field(q, ^field), field(q, ^field), ^unit_val, ^unit_str))
    else
      where(query, [q],
        fragment("? > NOW() AND ? <= DATE_ADD(NOW(), INTERVAL ? ?)",
          field(q, ^field), field(q, ^field), ^unit_val, ^unit_str))
    end
  end

  defp apply_current_period_mysql(query, field, :hour, binding) do
    if binding do
      where(query, [{^binding, q}],
        fragment("? >= DATE_FORMAT(NOW(), '%Y-%m-%d %H:00:00') AND ? < DATE_ADD(DATE_FORMAT(NOW(), '%Y-%m-%d %H:00:00'), INTERVAL 1 HOUR)",
          field(q, ^field), field(q, ^field)))
    else
      where(query, [q],
        fragment("? >= DATE_FORMAT(NOW(), '%Y-%m-%d %H:00:00') AND ? < DATE_ADD(DATE_FORMAT(NOW(), '%Y-%m-%d %H:00:00'), INTERVAL 1 HOUR)",
          field(q, ^field), field(q, ^field)))
    end
  end

  defp apply_current_period_mysql(query, field, :day, binding) do
    if binding do
      where(query, [{^binding, q}],
        fragment("? >= CURDATE() AND ? < DATE_ADD(CURDATE(), INTERVAL 1 DAY)",
          field(q, ^field), field(q, ^field)))
    else
      where(query, [q],
        fragment("? >= CURDATE() AND ? < DATE_ADD(CURDATE(), INTERVAL 1 DAY)",
          field(q, ^field), field(q, ^field)))
    end
  end

  defp apply_current_period_mysql(query, field, :week, binding) do
    week_start = mysql_week_start_offset()

    if binding do
      where(query, [{^binding, q}],
        fragment("? >= DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) - ? DAY) AND ? < DATE_ADD(DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) - ? DAY), INTERVAL 1 WEEK)",
          field(q, ^field), ^week_start, field(q, ^field), ^week_start))
    else
      where(query, [q],
        fragment("? >= DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) - ? DAY) AND ? < DATE_ADD(DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) - ? DAY), INTERVAL 1 WEEK)",
          field(q, ^field), ^week_start, field(q, ^field), ^week_start))
    end
  end

  defp apply_current_period_mysql(query, field, :month, binding) do
    if binding do
      where(query, [{^binding, q}],
        fragment("? >= DATE_FORMAT(NOW(), '%Y-%m-01') AND ? < DATE_ADD(DATE_FORMAT(NOW(), '%Y-%m-01'), INTERVAL 1 MONTH)",
          field(q, ^field), field(q, ^field)))
    else
      where(query, [q],
        fragment("? >= DATE_FORMAT(NOW(), '%Y-%m-01') AND ? < DATE_ADD(DATE_FORMAT(NOW(), '%Y-%m-01'), INTERVAL 1 MONTH)",
          field(q, ^field), field(q, ^field)))
    end
  end

  defp apply_current_period_mysql(query, field, :quarter, binding) do
    if binding do
      where(query, [{^binding, q}],
        fragment("? >= MAKEDATE(YEAR(NOW()), 1) + INTERVAL QUARTER(NOW())-1 QUARTER AND ? < MAKEDATE(YEAR(NOW()), 1) + INTERVAL QUARTER(NOW()) QUARTER",
          field(q, ^field), field(q, ^field)))
    else
      where(query, [q],
        fragment("? >= MAKEDATE(YEAR(NOW()), 1) + INTERVAL QUARTER(NOW())-1 QUARTER AND ? < MAKEDATE(YEAR(NOW()), 1) + INTERVAL QUARTER(NOW()) QUARTER",
          field(q, ^field), field(q, ^field)))
    end
  end

  defp apply_current_period_mysql(query, field, :year, binding) do
    if binding do
      where(query, [{^binding, q}],
        fragment("? >= DATE_FORMAT(NOW(), '%Y-01-01') AND ? < DATE_ADD(DATE_FORMAT(NOW(), '%Y-01-01'), INTERVAL 1 YEAR)",
          field(q, ^field), field(q, ^field)))
    else
      where(query, [q],
        fragment("? >= DATE_FORMAT(NOW(), '%Y-01-01') AND ? < DATE_ADD(DATE_FORMAT(NOW(), '%Y-01-01'), INTERVAL 1 YEAR)",
          field(q, ^field), field(q, ^field)))
    end
  end

  # SQLite period operators
  defp apply_period_sqlite(query, field, :last, unit, count, binding) do
    modifier = sqlite_modifier(unit, count, :subtract)

    if binding do
      where(query, [{^binding, q}],
        fragment("? >= datetime('now', ?) AND ? < datetime('now')",
          field(q, ^field), ^modifier, field(q, ^field)))
    else
      where(query, [q],
        fragment("? >= datetime('now', ?) AND ? < datetime('now')",
          field(q, ^field), ^modifier, field(q, ^field)))
    end
  end

  defp apply_period_sqlite(query, field, :next, unit, count, binding) do
    modifier = sqlite_modifier(unit, count, :add)

    if binding do
      where(query, [{^binding, q}],
        fragment("? > datetime('now') AND ? <= datetime('now', ?)",
          field(q, ^field), field(q, ^field), ^modifier))
    else
      where(query, [q],
        fragment("? > datetime('now') AND ? <= datetime('now', ?)",
          field(q, ^field), field(q, ^field), ^modifier))
    end
  end

  defp apply_current_period_sqlite(query, field, unit, binding) do
    {start_mod, end_mod} = sqlite_current_period_modifiers(unit)

    if binding do
      where(query, [{^binding, q}],
        fragment("? >= datetime('now', ?) AND ? < datetime('now', ?)",
          field(q, ^field), ^start_mod, field(q, ^field), ^end_mod))
    else
      where(query, [q],
        fragment("? >= datetime('now', ?) AND ? < datetime('now', ?)",
          field(q, ^field), ^start_mod, field(q, ^field), ^end_mod))
    end
  end

  # MSSQL period operators
  defp apply_period_mssql(query, field, :last, unit, count, binding) do
    {datepart, count_val} = mssql_datepart(unit, count)

    if binding do
      where(query, [{^binding, q}],
        fragment("? >= DATEADD(?, ?, GETDATE()) AND ? < GETDATE()",
          field(q, ^field), ^datepart, ^(-count_val), field(q, ^field)))
    else
      where(query, [q],
        fragment("? >= DATEADD(?, ?, GETDATE()) AND ? < GETDATE()",
          field(q, ^field), ^datepart, ^(-count_val), field(q, ^field)))
    end
  end

  defp apply_period_mssql(query, field, :next, unit, count, binding) do
    {datepart, count_val} = mssql_datepart(unit, count)

    if binding do
      where(query, [{^binding, q}],
        fragment("? > GETDATE() AND ? <= DATEADD(?, ?, GETDATE())",
          field(q, ^field), field(q, ^field), ^datepart, ^count_val))
    else
      where(query, [q],
        fragment("? > GETDATE() AND ? <= DATEADD(?, ?, GETDATE())",
          field(q, ^field), field(q, ^field), ^datepart, ^count_val))
    end
  end

  defp apply_current_period_mssql(query, field, unit, binding) do
    {start_expr, end_expr} = mssql_current_period_expressions(unit)

    if binding do
      where(query, [{^binding, q}],
        fragment("? >= ? AND ? < ?",
          field(q, ^field), ^start_expr, field(q, ^field), ^end_expr))
    else
      where(query, [q],
        fragment("? >= ? AND ? < ?",
          field(q, ^field), ^start_expr, field(q, ^field), ^end_expr))
    end
  end

  # Helper functions

  defp interval_string(:hour, count), do: "#{count} hours"
  defp interval_string(:day, count), do: "#{count} days"
  defp interval_string(:week, count), do: "#{count} weeks"
  defp interval_string(:month, count), do: "#{count} months"
  defp interval_string(:quarter, count), do: "#{count * 3} months"
  defp interval_string(:year, count), do: "#{count} years"

  defp postgres_trunc_unit(:hour), do: "hour"
  defp postgres_trunc_unit(:day), do: "day"
  defp postgres_trunc_unit(:week), do: "week"
  defp postgres_trunc_unit(:month), do: "month"
  defp postgres_trunc_unit(:quarter), do: "quarter"
  defp postgres_trunc_unit(:year), do: "year"

  defp mysql_interval_parts(:hour, count), do: {"HOUR", count}
  defp mysql_interval_parts(:day, count), do: {"DAY", count}
  defp mysql_interval_parts(:week, count), do: {"WEEK", count}
  defp mysql_interval_parts(:month, count), do: {"MONTH", count}
  defp mysql_interval_parts(:quarter, count), do: {"QUARTER", count}
  defp mysql_interval_parts(:year, count), do: {"YEAR", count}

  defp mysql_week_start_offset do
    # MySQL WEEKDAY: 0=Monday, 6=Sunday
    # Config: :monday (default) = 0, :sunday = 1
    case Application.get_env(:green_fairy, :week_start, :monday) do
      :sunday -> 1
      _ -> 0
    end
  end

  defp sqlite_modifier(:hour, count, :subtract), do: "-#{count} hours"
  defp sqlite_modifier(:day, count, :subtract), do: "-#{count} days"
  defp sqlite_modifier(:week, count, :subtract), do: "-#{count * 7} days"
  defp sqlite_modifier(:month, count, :subtract), do: "-#{count} months"
  defp sqlite_modifier(:quarter, count, :subtract), do: "-#{count * 3} months"
  defp sqlite_modifier(:year, count, :subtract), do: "-#{count} years"
  defp sqlite_modifier(:hour, count, :add), do: "+#{count} hours"
  defp sqlite_modifier(:day, count, :add), do: "+#{count} days"
  defp sqlite_modifier(:week, count, :add), do: "+#{count * 7} days"
  defp sqlite_modifier(:month, count, :add), do: "+#{count} months"
  defp sqlite_modifier(:quarter, count, :add), do: "+#{count * 3} months"
  defp sqlite_modifier(:year, count, :add), do: "+#{count} years"

  defp sqlite_current_period_modifiers(:hour) do
    {"start of hour", "+1 hour"}
  end

  defp sqlite_current_period_modifiers(:day) do
    {"start of day", "+1 day"}
  end

  defp sqlite_current_period_modifiers(:week) do
    # SQLite: 0=Sunday. Adjust for Monday start if configured
    offset = case Application.get_env(:green_fairy, :week_start, :monday) do
      :sunday -> "-6 days"
      _ -> "weekday 1', '-7 days"  # Monday
    end
    {offset, "weekday 1"}
  end

  defp sqlite_current_period_modifiers(:month) do
    {"start of month", "+1 month"}
  end

  defp sqlite_current_period_modifiers(:quarter) do
    # Calculate start of quarter
    {"start of year', '+((CAST(strftime('%m', 'now') AS INTEGER) - 1) / 3) * 3 months",
     "start of year', '+((CAST(strftime('%m', 'now') AS INTEGER) - 1) / 3 + 1) * 3 months"}
  end

  defp sqlite_current_period_modifiers(:year) do
    {"start of year", "+1 year"}
  end

  defp mssql_datepart(:hour, count), do: {"HOUR", count}
  defp mssql_datepart(:day, count), do: {"DAY", count}
  defp mssql_datepart(:week, count), do: {"WEEK", count}
  defp mssql_datepart(:month, count), do: {"MONTH", count}
  defp mssql_datepart(:quarter, count), do: {"QUARTER", count}
  defp mssql_datepart(:year, count), do: {"YEAR", count}

  defp mssql_current_period_expressions(:hour) do
    {"DATEADD(HOUR, DATEDIFF(HOUR, 0, GETDATE()), 0)",
     "DATEADD(HOUR, DATEDIFF(HOUR, 0, GETDATE()) + 1, 0)"}
  end

  defp mssql_current_period_expressions(:day) do
    {"CAST(GETDATE() AS DATE)",
     "DATEADD(DAY, 1, CAST(GETDATE() AS DATE))"}
  end

  defp mssql_current_period_expressions(:week) do
    # MSSQL: @@DATEFIRST configures week start. Default to Monday (1)
    week_start = case Application.get_env(:green_fairy, :week_start, :monday) do
      :sunday -> 7
      _ -> 1
    end

    {"DATEADD(DAY, #{week_start} - DATEPART(WEEKDAY, GETDATE()), CAST(GETDATE() AS DATE))",
     "DATEADD(WEEK, 1, DATEADD(DAY, #{week_start} - DATEPART(WEEKDAY, GETDATE()), CAST(GETDATE() AS DATE)))"}
  end

  defp mssql_current_period_expressions(:month) do
    {"DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)",
     "DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) + 1, 0)"}
  end

  defp mssql_current_period_expressions(:quarter) do
    {"DATEADD(QUARTER, DATEDIFF(QUARTER, 0, GETDATE()), 0)",
     "DATEADD(QUARTER, DATEDIFF(QUARTER, 0, GETDATE()) + 1, 0)"}
  end

  defp mssql_current_period_expressions(:year) do
    {"DATEADD(YEAR, DATEDIFF(YEAR, 0, GETDATE()), 0)",
     "DATEADD(YEAR, DATEDIFF(YEAR, 0, GETDATE()) + 1, 0)"}
  end
end
