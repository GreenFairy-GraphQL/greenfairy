defmodule GreenFairy.CQL.Scalars.Float.Exlasticsearch do
  @moduledoc "Exlasticsearch Query DSL implementation for float operators (delegates to Integer.Exlasticsearch)"

  def apply_operator(query, field, operator, value, opts) do
    # Float operations are identical to Integer for Exlasticsearch
    GreenFairy.CQL.Scalars.Integer.Exlasticsearch.apply_operator(query, field, operator, value, opts)
  end
end
