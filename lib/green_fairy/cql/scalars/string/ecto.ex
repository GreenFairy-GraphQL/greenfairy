defmodule GreenFairy.CQL.Scalars.String.Ecto do
  @moduledoc """
  Generic Ecto string operators.

  Only includes standard SQL operators that work across all databases.
  No ILIKE or case-insensitive operators (too database-specific to emulate safely).
  """

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
       :_starts_with,
       :_ends_with,
       :_contains
     ], :string, "Operators for string fields (generic SQL)"}
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
      :_starts_with -> CommonSQL.apply_starts_with(query, field, value, binding)
      :_ends_with -> CommonSQL.apply_ends_with(query, field, value, binding)
      :_contains -> CommonSQL.apply_contains(query, field, value, binding)
      _ -> query
    end
  end
end
