defmodule GreenFairy.CQL.Scalars.ArrayString.Postgres do
  @moduledoc "PostgreSQL native array operators"

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
     ], :string, "Operators for string array fields"}
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

  defp apply_includes(query, field, value, nil) do
    where(query, [q], fragment("? = ANY(?)", ^value, field(q, ^field)))
  end

  defp apply_includes(query, field, value, binding) do
    where(query, [{^binding, a}], fragment("? = ANY(?)", ^value, field(a, ^field)))
  end

  defp apply_excludes(query, field, value, nil) do
    where(query, [q], fragment("? != ALL(?)", ^value, field(q, ^field)))
  end

  defp apply_excludes(query, field, value, binding) do
    where(query, [{^binding, a}], fragment("? != ALL(?)", ^value, field(a, ^field)))
  end

  defp apply_includes_all(query, field, values, nil) when is_list(values) do
    where(query, [q], fragment("? @> ?::text[]", field(q, ^field), ^values))
  end

  defp apply_includes_all(query, field, values, binding) when is_list(values) do
    where(query, [{^binding, a}], fragment("? @> ?::text[]", field(a, ^field), ^values))
  end

  defp apply_excludes_all(query, field, values, nil) when is_list(values) do
    where(query, [q], fragment("NOT (? && ?::text[])", field(q, ^field), ^values))
  end

  defp apply_excludes_all(query, field, values, binding) when is_list(values) do
    where(query, [{^binding, a}], fragment("NOT (? && ?::text[])", field(a, ^field), ^values))
  end

  defp apply_includes_any(query, field, values, nil) when is_list(values) do
    where(query, [q], fragment("? && ?::text[]", field(q, ^field), ^values))
  end

  defp apply_includes_any(query, field, values, binding) when is_list(values) do
    where(query, [{^binding, a}], fragment("? && ?::text[]", field(a, ^field), ^values))
  end

  defp apply_excludes_any(query, field, values, nil) when is_list(values) do
    where(query, [q], fragment("NOT (? @> ?::text[])", field(q, ^field), ^values))
  end

  defp apply_excludes_any(query, field, values, binding) when is_list(values) do
    where(query, [{^binding, a}], fragment("NOT (? @> ?::text[])", field(a, ^field), ^values))
  end

  defp apply_is_empty(query, field, true, nil) do
    where(
      query,
      [q],
      fragment(
        "(array_length(?, 1) IS NULL OR ? = ARRAY[]::text[])",
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
        "(array_length(?, 1) IS NULL OR ? = ARRAY[]::text[])",
        field(a, ^field),
        field(a, ^field)
      )
    )
  end

  defp apply_is_empty(query, field, false, nil) do
    where(query, [q], fragment("array_length(?, 1) > 0", field(q, ^field)))
  end

  defp apply_is_empty(query, field, false, binding) do
    where(query, [{^binding, a}], fragment("array_length(?, 1) > 0", field(a, ^field)))
  end

  defp apply_is_null(query, field, true, nil), do: where(query, [q], is_nil(field(q, ^field)))

  defp apply_is_null(query, field, true, binding),
    do: where(query, [{^binding, a}], is_nil(field(a, ^field)))

  defp apply_is_null(query, field, false, nil),
    do: where(query, [q], not is_nil(field(q, ^field)))

  defp apply_is_null(query, field, false, binding),
    do: where(query, [{^binding, a}], not is_nil(field(a, ^field)))
end
