defmodule GreenFairy.CQL.Scalars.Enum do
  @moduledoc """
  CQL scalar for enum fields (Ecto.Enum and EctoEnum).

  ## Operators

  - `:_eq` / `:_neq` - Equality/inequality
  - `:_in` / `:_nin` - List membership
  - `:_is_null` - Null check

  Note: Enums don't support comparison operators like _gt, _lt.
  """

  @behaviour GreenFairy.CQL.Scalar

  @impl true
  def operator_input(_adapter) do
    {[:_eq, :_ne, :_neq, :_in, :_nin, :_is_null], :string, "Operators for enum fields"}
  end

  @impl true
  def apply_operator(query, field, operator, value, adapter, opts) do
    # Enum operations are identical to ID operations
    GreenFairy.CQL.Scalars.ID.apply_operator(query, field, operator, value, adapter, opts)
  end

  @impl true
  def operator_type_identifier(_adapter), do: :cql_op_enum_input
end
