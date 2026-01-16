defmodule GreenFairy.CQL.Scalars.Coordinates.Generic do
  @moduledoc "Generic coordinates operators (equality only)"

  import Ecto.Query, only: [where: 3]

  def operator_input do
    {[
       :_eq,
       :_ne,
       :_neq,
       :_is_null
     ], :coordinates, "Basic coordinate operators (equality only)"}
  end

  def apply_operator(query, field, :_eq, value, opts) do
    binding = Keyword.get(opts, :binding)

    if binding do
      where(query, [{^binding, q}], field(q, ^field) == ^value)
    else
      where(query, [q], field(q, ^field) == ^value)
    end
  end

  # Alias for _neq
  def apply_operator(query, field, :_ne, value, opts) do
    apply_operator(query, field, :_neq, value, opts)
  end

  def apply_operator(query, field, :_neq, value, opts) do
    binding = Keyword.get(opts, :binding)

    if binding do
      where(query, [{^binding, q}], field(q, ^field) != ^value)
    else
      where(query, [q], field(q, ^field) != ^value)
    end
  end

  def apply_operator(query, field, :_is_null, true, opts) do
    binding = Keyword.get(opts, :binding)

    if binding do
      where(query, [{^binding, q}], is_nil(field(q, ^field)))
    else
      where(query, [q], is_nil(field(q, ^field)))
    end
  end

  def apply_operator(query, field, :_is_null, false, opts) do
    binding = Keyword.get(opts, :binding)

    if binding do
      where(query, [{^binding, q}], not is_nil(field(q, ^field)))
    else
      where(query, [q], not is_nil(field(q, ^field)))
    end
  end

  def apply_operator(query, _field, _operator, _value, _opts), do: query
end
