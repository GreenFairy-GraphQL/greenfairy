defmodule GreenFairy.CQL.Scalars.String.ClickHouse do
  @moduledoc """
  ClickHouse string operators.

  ClickHouse has native `ilike()` function (since 21.12+) for case-insensitive matching.
  """

  import Ecto.Query, only: [where: 3]

  alias GreenFairy.CQL.Scalars.CommonSQL

  def operator_input do
    {[
       :_eq,
       :_ne,
       :_neq,
       :_gt,
       :_gte,
       :_lt,
       :_lte,
       :_in,
       :_nin,
       :_is_null,
       :_like,
       :_nlike,
       :_ilike,
       :_nilike,
       :_starts_with,
       :_istarts_with,
       :_ends_with,
       :_iends_with,
       :_contains,
       :_icontains
     ], :string, "Operators for string fields (ClickHouse)"}
  end

  def apply_operator(query, field, operator, value, opts) do
    binding = Keyword.get(opts, :binding)

    case operator do
      :_eq -> CommonSQL.apply_eq(query, field, value, binding)
      :_ne -> CommonSQL.apply_neq(query, field, value, binding)
      :_neq -> CommonSQL.apply_neq(query, field, value, binding)
      :_gt -> CommonSQL.apply_gt(query, field, value, binding)
      :_gte -> CommonSQL.apply_gte(query, field, value, binding)
      :_lt -> CommonSQL.apply_lt(query, field, value, binding)
      :_lte -> CommonSQL.apply_lte(query, field, value, binding)
      :_in -> CommonSQL.apply_in(query, field, value, binding)
      :_nin -> CommonSQL.apply_nin(query, field, value, binding)
      :_is_null -> CommonSQL.apply_is_null(query, field, value, binding)
      :_like -> CommonSQL.apply_like(query, field, value, binding)
      :_nlike -> CommonSQL.apply_nlike(query, field, value, binding)
      :_ilike -> apply_ilike(query, field, value, binding)
      :_nilike -> apply_nilike(query, field, value, binding)
      :_starts_with -> CommonSQL.apply_starts_with(query, field, value, binding)
      :_istarts_with -> apply_istarts_with(query, field, value, binding)
      :_ends_with -> CommonSQL.apply_ends_with(query, field, value, binding)
      :_iends_with -> apply_iends_with(query, field, value, binding)
      :_contains -> CommonSQL.apply_contains(query, field, value, binding)
      :_icontains -> apply_icontains(query, field, value, binding)
      _ -> query
    end
  end

  # ClickHouse native ilike() function
  def apply_ilike(query, field, pattern, nil) do
    where(query, [q], fragment("ilike(?, ?)", field(q, ^field), ^pattern))
  end

  def apply_ilike(query, field, pattern, binding) do
    where(query, [{^binding, a}], fragment("ilike(?, ?)", field(a, ^field), ^pattern))
  end

  def apply_nilike(query, field, pattern, nil) do
    where(query, [q], fragment("NOT ilike(?, ?)", field(q, ^field), ^pattern))
  end

  def apply_nilike(query, field, pattern, binding) do
    where(query, [{^binding, a}], fragment("NOT ilike(?, ?)", field(a, ^field), ^pattern))
  end

  def apply_istarts_with(query, field, prefix, nil) do
    pattern = "#{prefix}%"
    where(query, [q], fragment("ilike(?, ?)", field(q, ^field), ^pattern))
  end

  def apply_istarts_with(query, field, prefix, binding) do
    pattern = "#{prefix}%"
    where(query, [{^binding, a}], fragment("ilike(?, ?)", field(a, ^field), ^pattern))
  end

  def apply_iends_with(query, field, suffix, nil) do
    pattern = "%#{suffix}"
    where(query, [q], fragment("ilike(?, ?)", field(q, ^field), ^pattern))
  end

  def apply_iends_with(query, field, suffix, binding) do
    pattern = "%#{suffix}"
    where(query, [{^binding, a}], fragment("ilike(?, ?)", field(a, ^field), ^pattern))
  end

  def apply_icontains(query, field, substring, nil) do
    pattern = "%#{substring}%"
    where(query, [q], fragment("ilike(?, ?)", field(q, ^field), ^pattern))
  end

  def apply_icontains(query, field, substring, binding) do
    pattern = "%#{substring}%"
    where(query, [{^binding, a}], fragment("ilike(?, ?)", field(a, ^field), ^pattern))
  end
end
