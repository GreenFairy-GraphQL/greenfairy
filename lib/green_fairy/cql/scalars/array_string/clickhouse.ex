defmodule GreenFairy.CQL.Scalars.ArrayString.ClickHouse do
  @moduledoc """
  ClickHouse array operators for string arrays.

  Uses ClickHouse's native array functions:
  - `has(array, element)` - contains element
  - `hasAll(array, elements)` - contains all elements
  - `hasAny(array, elements)` - contains any element
  - `empty(array)` - array is empty
  """

  import Ecto.Query, only: [where: 3]

  def operator_input do
    {[
       :_includes,
       :_excludes,
       :_includes_all,
       :_excludes_all,
       :_includes_any,
       :_excludes_any,
       :_is_empty,
       :_is_null
     ], :string, "Operators for string array fields (ClickHouse)"}
  end

  def apply_operator(query, field, operator, value, opts) do
    binding = Keyword.get(opts, :binding)

    case operator do
      :_includes -> apply_includes(query, field, value, binding)
      :_excludes -> apply_excludes(query, field, value, binding)
      :_includes_all -> apply_includes_all(query, field, value, binding)
      :_excludes_all -> apply_excludes_all(query, field, value, binding)
      :_includes_any -> apply_includes_any(query, field, value, binding)
      :_excludes_any -> apply_excludes_any(query, field, value, binding)
      :_is_empty -> apply_is_empty(query, field, value, binding)
      :_is_null -> apply_is_null(query, field, value, binding)
      _ -> query
    end
  end

  # has(array, element)
  defp apply_includes(query, field, value, nil) do
    where(query, [q], fragment("has(?, ?)", field(q, ^field), ^value))
  end

  defp apply_includes(query, field, value, binding) do
    where(query, [{^binding, a}], fragment("has(?, ?)", field(a, ^field), ^value))
  end

  # NOT has(array, element)
  defp apply_excludes(query, field, value, nil) do
    where(query, [q], fragment("NOT has(?, ?)", field(q, ^field), ^value))
  end

  defp apply_excludes(query, field, value, binding) do
    where(query, [{^binding, a}], fragment("NOT has(?, ?)", field(a, ^field), ^value))
  end

  # hasAll(array, elements)
  defp apply_includes_all(query, field, values, nil) when is_list(values) do
    where(query, [q], fragment("hasAll(?, ?)", field(q, ^field), ^values))
  end

  defp apply_includes_all(query, field, values, binding) when is_list(values) do
    where(query, [{^binding, a}], fragment("hasAll(?, ?)", field(a, ^field), ^values))
  end

  # NOT hasAll(array, elements) - excludes all means contains none
  defp apply_excludes_all(query, field, values, nil) when is_list(values) do
    where(query, [q], fragment("NOT hasAny(?, ?)", field(q, ^field), ^values))
  end

  defp apply_excludes_all(query, field, values, binding) when is_list(values) do
    where(query, [{^binding, a}], fragment("NOT hasAny(?, ?)", field(a, ^field), ^values))
  end

  # hasAny(array, elements)
  defp apply_includes_any(query, field, values, nil) when is_list(values) do
    where(query, [q], fragment("hasAny(?, ?)", field(q, ^field), ^values))
  end

  defp apply_includes_any(query, field, values, binding) when is_list(values) do
    where(query, [{^binding, a}], fragment("hasAny(?, ?)", field(a, ^field), ^values))
  end

  # NOT hasAll - excludes any means does not contain all
  defp apply_excludes_any(query, field, values, nil) when is_list(values) do
    where(query, [q], fragment("NOT hasAll(?, ?)", field(q, ^field), ^values))
  end

  defp apply_excludes_any(query, field, values, binding) when is_list(values) do
    where(query, [{^binding, a}], fragment("NOT hasAll(?, ?)", field(a, ^field), ^values))
  end

  # empty(array)
  defp apply_is_empty(query, field, true, nil) do
    where(query, [q], fragment("empty(?)", field(q, ^field)))
  end

  defp apply_is_empty(query, field, true, binding) do
    where(query, [{^binding, a}], fragment("empty(?)", field(a, ^field)))
  end

  defp apply_is_empty(query, field, false, nil) do
    where(query, [q], fragment("notEmpty(?)", field(q, ^field)))
  end

  defp apply_is_empty(query, field, false, binding) do
    where(query, [{^binding, a}], fragment("notEmpty(?)", field(a, ^field)))
  end

  # IS NULL / IS NOT NULL
  defp apply_is_null(query, field, true, nil), do: where(query, [q], is_nil(field(q, ^field)))
  defp apply_is_null(query, field, true, binding), do: where(query, [{^binding, a}], is_nil(field(a, ^field)))
  defp apply_is_null(query, field, false, nil), do: where(query, [q], not is_nil(field(q, ^field)))
  defp apply_is_null(query, field, false, binding), do: where(query, [{^binding, a}], not is_nil(field(a, ^field)))
end
