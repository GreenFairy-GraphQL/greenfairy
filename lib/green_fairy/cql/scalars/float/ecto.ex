defmodule GreenFairy.CQL.Scalars.Float.Ecto do
  @moduledoc "Ecto/SQL implementation for float operators (delegates to Integer.Ecto)"

  def apply_operator(query, field, operator, value, opts) do
    # Float operations are identical to Integer for SQL databases
    GreenFairy.CQL.Scalars.Integer.Ecto.apply_operator(query, field, operator, value, opts)
  end
end
