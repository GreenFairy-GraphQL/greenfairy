defmodule GreenFairy.CQL.Scalars.ID.Ecto do
  @moduledoc "Ecto/SQL implementation for ID operators"

  import Ecto.Query, only: [where: 3]

  def apply_operator(query, field, operator, value, opts) do
    binding = Keyword.get(opts, :binding)

    case operator do
      :_eq -> apply_eq(query, field, value, binding)
      :_ne -> apply_neq(query, field, value, binding)  # Alias for _neq
      :_neq -> apply_neq(query, field, value, binding)
      :_in -> apply_in(query, field, value, binding)
      :_nin -> apply_nin(query, field, value, binding)
      :_is_null -> apply_is_null(query, field, value, binding)
      _ -> query
    end
  end

  defp apply_eq(query, field, value, nil), do: where(query, [q], field(q, ^field) == ^value)

  defp apply_eq(query, field, value, binding),
    do: where(query, [{^binding, a}], field(a, ^field) == ^value)

  defp apply_neq(query, field, value, nil), do: where(query, [q], field(q, ^field) != ^value)

  defp apply_neq(query, field, value, binding),
    do: where(query, [{^binding, a}], field(a, ^field) != ^value)

  defp apply_in(query, field, values, nil) when is_list(values),
    do: where(query, [q], field(q, ^field) in ^values)

  defp apply_in(query, field, values, binding) when is_list(values),
    do: where(query, [{^binding, a}], field(a, ^field) in ^values)

  defp apply_nin(query, field, values, nil) when is_list(values),
    do: where(query, [q], field(q, ^field) not in ^values)

  defp apply_nin(query, field, values, binding) when is_list(values),
    do: where(query, [{^binding, a}], field(a, ^field) not in ^values)

  defp apply_is_null(query, field, true, nil), do: where(query, [q], is_nil(field(q, ^field)))

  defp apply_is_null(query, field, true, binding),
    do: where(query, [{^binding, a}], is_nil(field(a, ^field)))

  defp apply_is_null(query, field, false, nil),
    do: where(query, [q], not is_nil(field(q, ^field)))

  defp apply_is_null(query, field, false, binding),
    do: where(query, [{^binding, a}], not is_nil(field(a, ^field)))
end
