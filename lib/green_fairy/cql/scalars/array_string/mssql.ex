defmodule GreenFairy.CQL.Scalars.ArrayString.MSSQL do
  @moduledoc "MSSQL OPENJSON array support"

  import Ecto.Query, only: [where: 3]

  def operator_input do
    {[:_includes, :_excludes, :_includes_any, :_is_empty, :_is_null], :string,
     "Operators for JSON string array fields (SQL Server 2016+)"}
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
    where(
      query,
      [q],
      fragment(
        "EXISTS (SELECT 1 FROM OPENJSON(?) WHERE value = ?)",
        field(q, ^field),
        ^value
      )
    )
  end

  defp apply_includes(query, field, value, binding) do
    where(
      query,
      [{^binding, a}],
      fragment(
        "EXISTS (SELECT 1 FROM OPENJSON(?) WHERE value = ?)",
        field(a, ^field),
        ^value
      )
    )
  end

  defp apply_excludes(query, field, value, nil) do
    where(
      query,
      [q],
      fragment(
        "NOT EXISTS (SELECT 1 FROM OPENJSON(?) WHERE value = ?)",
        field(q, ^field),
        ^value
      )
    )
  end

  defp apply_excludes(query, field, value, binding) do
    where(
      query,
      [{^binding, a}],
      fragment(
        "NOT EXISTS (SELECT 1 FROM OPENJSON(?) WHERE value = ?)",
        field(a, ^field),
        ^value
      )
    )
  end

  defp apply_includes_any(query, field, values, nil) when is_list(values) do
    where(
      query,
      [q],
      fragment(
        "EXISTS (SELECT 1 FROM OPENJSON(?) AS arr INNER JOIN OPENJSON(?) AS vals ON arr.value = vals.value)",
        field(q, ^field),
        ^Jason.encode!(values)
      )
    )
  end

  defp apply_includes_any(query, field, values, binding) when is_list(values) do
    where(
      query,
      [{^binding, a}],
      fragment(
        "EXISTS (SELECT 1 FROM OPENJSON(?) AS arr INNER JOIN OPENJSON(?) AS vals ON arr.value = vals.value)",
        field(a, ^field),
        ^Jason.encode!(values)
      )
    )
  end

  defp apply_is_empty(query, field, true, nil) do
    where(
      query,
      [q],
      fragment(
        "(? IS NULL OR NOT EXISTS (SELECT 1 FROM OPENJSON(?)))",
        field(q, ^field),
        field(q, ^field)
      )
    )
  end

  defp apply_is_empty(query, field, true, binding) do
    where(
      query,
      [{^binding, a}],
      fragment(
        "(? IS NULL OR NOT EXISTS (SELECT 1 FROM OPENJSON(?)))",
        field(a, ^field),
        field(a, ^field)
      )
    )
  end

  defp apply_is_empty(query, field, false, nil) do
    where(
      query,
      [q],
      fragment("EXISTS (SELECT 1 FROM OPENJSON(?))", field(q, ^field))
    )
  end

  defp apply_is_empty(query, field, false, binding) do
    where(
      query,
      [{^binding, a}],
      fragment("EXISTS (SELECT 1 FROM OPENJSON(?))", field(a, ^field))
    )
  end

  defp apply_is_null(query, field, true, nil), do: where(query, [q], is_nil(field(q, ^field)))

  defp apply_is_null(query, field, true, binding),
    do: where(query, [{^binding, a}], is_nil(field(a, ^field)))

  defp apply_is_null(query, field, false, nil),
    do: where(query, [q], not is_nil(field(q, ^field)))

  defp apply_is_null(query, field, false, binding),
    do: where(query, [{^binding, a}], not is_nil(field(a, ^field)))
end
