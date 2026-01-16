defmodule GreenFairy.CQL.Scalars.ArrayString.MySQL do
  @moduledoc "MySQL JSON-based array operators"

  import Ecto.Query, only: [where: 3]

  def operator_input do
    {[:_includes, :_excludes, :_includes_any, :_is_empty, :_is_null], :string,
     "Operators for JSON string array fields (MySQL 8.0+)"}
  end

  def apply_operator(query, field, operator, value, opts) do
    binding = Keyword.get(opts, :binding)

    case operator do
      :_includes -> apply_includes(query, field, value, binding)
      :_excludes -> apply_excludes(query, field, value, binding)
      :_includes_any -> apply_includes_any(query, field, value, binding)
      :_is_empty -> apply_is_empty(query, field, value, binding)
      :_is_null -> apply_is_null(query, field, value, binding)
      _ -> query
    end
  end

  defp apply_includes(query, field, value, nil) do
    where(query, [q], fragment("JSON_CONTAINS(?, JSON_QUOTE(?))", field(q, ^field), ^value))
  end

  defp apply_includes(query, field, value, binding) do
    where(
      query,
      [{^binding, a}],
      fragment("JSON_CONTAINS(?, JSON_QUOTE(?))", field(a, ^field), ^value)
    )
  end

  defp apply_excludes(query, field, value, nil) do
    where(
      query,
      [q],
      fragment("NOT JSON_CONTAINS(?, JSON_QUOTE(?))", field(q, ^field), ^value)
    )
  end

  defp apply_excludes(query, field, value, binding) do
    where(
      query,
      [{^binding, a}],
      fragment("NOT JSON_CONTAINS(?, JSON_QUOTE(?))", field(a, ^field), ^value)
    )
  end

  defp apply_includes_any(query, field, values, nil) when is_list(values) do
    where(
      query,
      [q],
      fragment("JSON_OVERLAPS(?, CAST(? AS JSON))", field(q, ^field), ^Jason.encode!(values))
    )
  end

  defp apply_includes_any(query, field, values, binding) when is_list(values) do
    where(
      query,
      [{^binding, a}],
      fragment("JSON_OVERLAPS(?, CAST(? AS JSON))", field(a, ^field), ^Jason.encode!(values))
    )
  end

  defp apply_is_empty(query, field, true, nil) do
    where(
      query,
      [q],
      fragment("(? IS NULL OR JSON_LENGTH(?) = 0)", field(q, ^field), field(q, ^field))
    )
  end

  defp apply_is_empty(query, field, true, binding) do
    where(
      query,
      [{^binding, a}],
      fragment("(? IS NULL OR JSON_LENGTH(?) = 0)", field(a, ^field), field(a, ^field))
    )
  end

  defp apply_is_empty(query, field, false, nil) do
    where(query, [q], fragment("JSON_LENGTH(?) > 0", field(q, ^field)))
  end

  defp apply_is_empty(query, field, false, binding) do
    where(query, [{^binding, a}], fragment("JSON_LENGTH(?) > 0", field(a, ^field)))
  end

  defp apply_is_null(query, field, true, nil), do: where(query, [q], is_nil(field(q, ^field)))

  defp apply_is_null(query, field, true, binding),
    do: where(query, [{^binding, a}], is_nil(field(a, ^field)))

  defp apply_is_null(query, field, false, nil),
    do: where(query, [q], not is_nil(field(q, ^field)))

  defp apply_is_null(query, field, false, binding),
    do: where(query, [{^binding, a}], not is_nil(field(a, ^field)))
end
