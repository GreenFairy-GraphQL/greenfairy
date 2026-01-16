defmodule GreenFairy.CQL.Scalars.ArrayString.Ecto do
  @moduledoc """
  Generic Ecto array operators.

  Provides minimal array support for unknown databases.
  Only supports null checking - no containment operators since
  array syntax varies too much across databases.
  """

  import Ecto.Query, only: [where: 3]

  def operator_input do
    {[:_is_null], :string,
     "Operators for string array fields (generic - limited support)"}
  end

  def apply_operator(query, field, operator, value, opts) do
    binding = Keyword.get(opts, :binding)

    case operator do
      :_is_null -> apply_is_null(query, field, value, binding)
      # Other operators not supported in generic adapter
      _ -> query
    end
  end

  defp apply_is_null(query, field, true, nil), do: where(query, [q], is_nil(field(q, ^field)))
  defp apply_is_null(query, field, true, binding), do: where(query, [{^binding, a}], is_nil(field(a, ^field)))
  defp apply_is_null(query, field, false, nil), do: where(query, [q], not is_nil(field(q, ^field)))
  defp apply_is_null(query, field, false, binding), do: where(query, [{^binding, a}], not is_nil(field(a, ^field)))
end
