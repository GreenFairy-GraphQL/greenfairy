defmodule GreenFairy.CQL.Scalars.String.MySQL do
  @moduledoc "MySQL string operators with ILIKE emulated via LOWER()"

  import Ecto.Query, only: [where: 3]

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
     ], :string, "Operators for string fields (ILIKE emulated with LOWER())"}
  end

  def apply_operator(query, field, operator, value, opts) do
    binding = Keyword.get(opts, :binding)

    case operator do
      :_eq -> apply_eq(query, field, value, binding)
      :_ne -> apply_neq(query, field, value, binding)  # Alias for _neq
      :_neq -> apply_neq(query, field, value, binding)
      :_gt -> apply_gt(query, field, value, binding)
      :_gte -> apply_gte(query, field, value, binding)
      :_lt -> apply_lt(query, field, value, binding)
      :_lte -> apply_lte(query, field, value, binding)
      :_in -> apply_in(query, field, value, binding)
      :_nin -> apply_nin(query, field, value, binding)
      :_is_null -> apply_is_null(query, field, value, binding)
      :_like -> apply_like(query, field, value, binding)
      :_nlike -> apply_nlike(query, field, value, binding)
      :_ilike -> apply_ilike(query, field, value, binding)
      :_nilike -> apply_nilike(query, field, value, binding)
      :_starts_with -> apply_starts_with(query, field, value, binding)
      :_istarts_with -> apply_istarts_with(query, field, value, binding)
      :_ends_with -> apply_ends_with(query, field, value, binding)
      :_iends_with -> apply_iends_with(query, field, value, binding)
      :_contains -> apply_contains(query, field, value, binding)
      :_icontains -> apply_icontains(query, field, value, binding)
      _ -> query
    end
  end

  # Delegate common ANSI SQL operators to shared module
  alias GreenFairy.CQL.Scalars.CommonSQL

  defdelegate apply_eq(query, field, value, binding), to: CommonSQL
  defdelegate apply_neq(query, field, value, binding), to: CommonSQL
  defdelegate apply_gt(query, field, value, binding), to: CommonSQL
  defdelegate apply_gte(query, field, value, binding), to: CommonSQL
  defdelegate apply_lt(query, field, value, binding), to: CommonSQL
  defdelegate apply_lte(query, field, value, binding), to: CommonSQL
  defdelegate apply_in(query, field, value, binding), to: CommonSQL
  defdelegate apply_nin(query, field, value, binding), to: CommonSQL
  defdelegate apply_is_null(query, field, value, binding), to: CommonSQL
  defdelegate apply_like(query, field, pattern, binding), to: CommonSQL
  defdelegate apply_nlike(query, field, pattern, binding), to: CommonSQL

  # MySQL-specific: Emulate ILIKE with LOWER()
  def apply_ilike(query, field, pattern, nil) do
    where(query, [q], fragment("LOWER(?) LIKE LOWER(?)", field(q, ^field), ^pattern))
  end

  def apply_ilike(query, field, pattern, binding) do
    where(query, [{^binding, a}], fragment("LOWER(?) LIKE LOWER(?)", field(a, ^field), ^pattern))
  end

  def apply_nilike(query, field, pattern, nil) do
    where(query, [q], fragment("NOT (LOWER(?) LIKE LOWER(?))", field(q, ^field), ^pattern))
  end

  def apply_nilike(query, field, pattern, binding) do
    where(query, [{^binding, a}], fragment("NOT (LOWER(?) LIKE LOWER(?))", field(a, ^field), ^pattern))
  end

  def apply_istarts_with(query, field, prefix, nil) do
    pattern = "#{prefix}%"
    where(query, [q], fragment("LOWER(?) LIKE LOWER(?)", field(q, ^field), ^pattern))
  end

  def apply_istarts_with(query, field, prefix, binding) do
    pattern = "#{prefix}%"
    where(query, [{^binding, a}], fragment("LOWER(?) LIKE LOWER(?)", field(a, ^field), ^pattern))
  end

  def apply_iends_with(query, field, suffix, nil) do
    pattern = "%#{suffix}"
    where(query, [q], fragment("LOWER(?) LIKE LOWER(?)", field(q, ^field), ^pattern))
  end

  def apply_iends_with(query, field, suffix, binding) do
    pattern = "%#{suffix}"
    where(query, [{^binding, a}], fragment("LOWER(?) LIKE LOWER(?)", field(a, ^field), ^pattern))
  end

  def apply_icontains(query, field, substring, nil) do
    pattern = "%#{substring}%"
    where(query, [q], fragment("LOWER(?) LIKE LOWER(?)", field(q, ^field), ^pattern))
  end

  def apply_icontains(query, field, substring, binding) do
    pattern = "%#{substring}%"
    where(query, [{^binding, a}], fragment("LOWER(?) LIKE LOWER(?)", field(a, ^field), ^pattern))
  end

  defdelegate apply_starts_with(query, field, prefix, binding), to: CommonSQL
  defdelegate apply_ends_with(query, field, suffix, binding), to: CommonSQL
  defdelegate apply_contains(query, field, substring, binding), to: CommonSQL
end
