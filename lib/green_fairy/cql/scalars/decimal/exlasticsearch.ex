defmodule GreenFairy.CQL.Scalars.Decimal.Exlasticsearch do
  @moduledoc "Exlasticsearch Query DSL implementation for decimal operators (delegates to Integer.Exlasticsearch)"

  def apply_operator(query, field, operator, value, opts) do
    # Decimal operations are identical to Integer for Exlasticsearch
    GreenFairy.CQL.Scalars.Integer.Exlasticsearch.apply_operator(query, field, operator, value, opts)
  end
end
