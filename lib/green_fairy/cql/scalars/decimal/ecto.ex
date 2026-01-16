defmodule GreenFairy.CQL.Scalars.Decimal.Ecto do
  @moduledoc "Ecto/SQL implementation for decimal operators (delegates to Integer.Ecto)"

  def apply_operator(query, field, operator, value, opts) do
    # Decimal operations are identical to Integer for SQL databases
    GreenFairy.CQL.Scalars.Integer.Ecto.apply_operator(query, field, operator, value, opts)
  end
end
