defmodule GreenFairy.CQL.Scalars.DateTime.Exlasticsearch do
  @moduledoc """
  Exlasticsearch Query DSL implementation for DateTime operators.

  Uses Elasticsearch's native date math for period operators:
  - `now-7d` - 7 days ago
  - `now/w` - Start of current week
  - `now+1M` - 1 month from now

  ## Date Math Reference

  Units:
  - `y` - years
  - `M` - months
  - `w` - weeks
  - `d` - days
  - `h` - hours
  - `m` - minutes
  - `s` - seconds

  Rounding:
  - `now/d` - Round to start of day
  - `now/w` - Round to start of week
  - `now/M` - Round to start of month
  - `now/y` - Round to start of year
  """

  alias GreenFairy.CQL.Scalars.Integer

  def apply_operator(query, field, :_between, [start_val, end_val], opts) do
    field_path = build_field_path(field, opts)
    add_range(query, field_path, %{gte: start_val, lte: end_val})
  end

  def apply_operator(query, field, :_period, %{direction: direction, unit: unit, count: count}, opts) do
    field_path = build_field_path(field, opts)
    apply_period(query, field_path, direction, unit, count)
  end

  # Default count to 1 if not provided
  def apply_operator(query, field, :_period, %{direction: direction, unit: unit}, opts) do
    apply_operator(query, field, :_period, %{direction: direction, unit: unit, count: 1}, opts)
  end

  def apply_operator(query, field, :_current_period, %{unit: unit}, opts) do
    field_path = build_field_path(field, opts)
    apply_current_period(query, field_path, unit)
  end

  def apply_operator(query, field, operator, value, opts) do
    # Delegate standard operators to Integer.Exlasticsearch
    Integer.Exlasticsearch.apply_operator(query, field, operator, value, opts)
  end

  # Period operators: LAST N units
  defp apply_period(query, field, :last, unit, count) do
    unit_char = es_unit_char(unit)
    count_val = es_count_value(unit, count)

    add_range(query, field, %{
      gte: "now-#{count_val}#{unit_char}",
      lt: "now"
    })
  end

  # Period operators: NEXT N units
  defp apply_period(query, field, :next, unit, count) do
    unit_char = es_unit_char(unit)
    count_val = es_count_value(unit, count)

    add_range(query, field, %{
      gt: "now",
      lte: "now+#{count_val}#{unit_char}"
    })
  end

  # Current period operators
  defp apply_current_period(query, field, :hour) do
    add_range(query, field, %{
      gte: "now/h",
      lt: "now/h+1h"
    })
  end

  defp apply_current_period(query, field, :day) do
    add_range(query, field, %{
      gte: "now/d",
      lt: "now/d+1d"
    })
  end

  defp apply_current_period(query, field, :week) do
    add_range(query, field, %{
      gte: "now/w",
      lt: "now/w+1w"
    })
  end

  defp apply_current_period(query, field, :month) do
    add_range(query, field, %{
      gte: "now/M",
      lt: "now/M+1M"
    })
  end

  defp apply_current_period(query, field, :quarter) do
    # Elasticsearch doesn't have native quarter rounding
    # Use 3 months as quarter approximation
    add_range(query, field, %{
      gte: "now/M",
      lt: "now/M+3M"
    })
  end

  defp apply_current_period(query, field, :year) do
    add_range(query, field, %{
      gte: "now/y",
      lt: "now/y+1y"
    })
  end

  # Helpers

  defp build_field_path(field, opts) do
    binding = Keyword.get(opts, :binding)
    if binding, do: "#{binding}.#{field}", else: to_string(field)
  end

  defp add_range(query, field, range_params) do
    update_in(query, [:query, :bool, :must], fn must ->
      [%{range: %{field => range_params}} | must || []]
    end)
  end

  # Elasticsearch date math unit characters
  defp es_unit_char(:hour), do: "h"
  defp es_unit_char(:day), do: "d"
  defp es_unit_char(:week), do: "w"
  defp es_unit_char(:month), do: "M"
  defp es_unit_char(:quarter), do: "M"  # Quarters use months
  defp es_unit_char(:year), do: "y"

  # For quarters, multiply count by 3
  defp es_count_value(:quarter, count), do: count * 3
  defp es_count_value(_unit, count), do: count
end
