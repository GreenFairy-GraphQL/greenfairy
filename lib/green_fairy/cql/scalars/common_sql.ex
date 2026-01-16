defmodule GreenFairy.CQL.Scalars.CommonSQL do
  @moduledoc """
  Common ANSI SQL operators shared across all database adapters.

  This module provides standard SQL operations that work identically
  across PostgreSQL, MySQL, SQLite, MSSQL, and other SQL databases.
  Database-specific variations (like ILIKE emulation) are handled in
  the individual adapter modules.
  """

  import Ecto.Query, only: [where: 3]

  @doc """
  Applies equality comparison.
  Special handling for nil values uses `is_nil/1` instead of `==`.
  """
  def apply_eq(query, field, nil, nil), do: where(query, [q], is_nil(field(q, ^field)))
  def apply_eq(query, field, nil, binding), do: where(query, [{^binding, a}], is_nil(field(a, ^field)))
  def apply_eq(query, field, value, nil), do: where(query, [q], field(q, ^field) == ^value)
  def apply_eq(query, field, value, binding), do: where(query, [{^binding, a}], field(a, ^field) == ^value)

  @doc "Applies inequality comparison."
  def apply_neq(query, field, nil, nil), do: where(query, [q], not is_nil(field(q, ^field)))
  def apply_neq(query, field, nil, binding), do: where(query, [{^binding, a}], not is_nil(field(a, ^field)))
  def apply_neq(query, field, value, nil), do: where(query, [q], field(q, ^field) != ^value)
  def apply_neq(query, field, value, binding), do: where(query, [{^binding, a}], field(a, ^field) != ^value)

  @doc "Applies greater than comparison."
  def apply_gt(query, field, value, nil), do: where(query, [q], field(q, ^field) > ^value)
  def apply_gt(query, field, value, binding), do: where(query, [{^binding, a}], field(a, ^field) > ^value)

  @doc "Applies greater than or equal comparison."
  def apply_gte(query, field, value, nil), do: where(query, [q], field(q, ^field) >= ^value)
  def apply_gte(query, field, value, binding), do: where(query, [{^binding, a}], field(a, ^field) >= ^value)

  @doc "Applies less than comparison."
  def apply_lt(query, field, value, nil), do: where(query, [q], field(q, ^field) < ^value)
  def apply_lt(query, field, value, binding), do: where(query, [{^binding, a}], field(a, ^field) < ^value)

  @doc "Applies less than or equal comparison."
  def apply_lte(query, field, value, nil), do: where(query, [q], field(q, ^field) <= ^value)
  def apply_lte(query, field, value, binding), do: where(query, [{^binding, a}], field(a, ^field) <= ^value)

  @doc "Applies IN operator."
  def apply_in(query, field, values, nil) when is_list(values),
    do: where(query, [q], field(q, ^field) in ^values)

  def apply_in(query, field, values, binding) when is_list(values),
    do: where(query, [{^binding, a}], field(a, ^field) in ^values)

  @doc "Applies NOT IN operator."
  def apply_nin(query, field, values, nil) when is_list(values),
    do: where(query, [q], field(q, ^field) not in ^values)

  def apply_nin(query, field, values, binding) when is_list(values),
    do: where(query, [{^binding, a}], field(a, ^field) not in ^values)

  @doc "Applies IS NULL check."
  def apply_is_null(query, field, true, nil), do: where(query, [q], is_nil(field(q, ^field)))
  def apply_is_null(query, field, true, binding), do: where(query, [{^binding, a}], is_nil(field(a, ^field)))
  def apply_is_null(query, field, false, nil), do: where(query, [q], not is_nil(field(q, ^field)))
  def apply_is_null(query, field, false, binding), do: where(query, [{^binding, a}], not is_nil(field(a, ^field)))

  @doc "Applies LIKE pattern matching (case-sensitive)."
  def apply_like(query, field, pattern, nil), do: where(query, [q], like(field(q, ^field), ^pattern))
  def apply_like(query, field, pattern, binding), do: where(query, [{^binding, a}], like(field(a, ^field), ^pattern))

  @doc "Applies NOT LIKE pattern matching."
  def apply_nlike(query, field, pattern, nil), do: where(query, [q], not like(field(q, ^field), ^pattern))
  def apply_nlike(query, field, pattern, binding), do: where(query, [{^binding, a}], not like(field(a, ^field), ^pattern))

  @doc "Applies STARTS WITH pattern (case-sensitive)."
  def apply_starts_with(query, field, prefix, nil) do
    pattern = "#{prefix}%"
    where(query, [q], like(field(q, ^field), ^pattern))
  end

  def apply_starts_with(query, field, prefix, binding) do
    pattern = "#{prefix}%"
    where(query, [{^binding, a}], like(field(a, ^field), ^pattern))
  end

  @doc "Applies ENDS WITH pattern (case-sensitive)."
  def apply_ends_with(query, field, suffix, nil) do
    pattern = "%#{suffix}"
    where(query, [q], like(field(q, ^field), ^pattern))
  end

  def apply_ends_with(query, field, suffix, binding) do
    pattern = "%#{suffix}"
    where(query, [{^binding, a}], like(field(a, ^field), ^pattern))
  end

  @doc "Applies CONTAINS pattern (case-sensitive)."
  def apply_contains(query, field, substring, nil) do
    pattern = "%#{substring}%"
    where(query, [q], like(field(q, ^field), ^pattern))
  end

  def apply_contains(query, field, substring, binding) do
    pattern = "%#{substring}%"
    where(query, [{^binding, a}], like(field(a, ^field), ^pattern))
  end
end
