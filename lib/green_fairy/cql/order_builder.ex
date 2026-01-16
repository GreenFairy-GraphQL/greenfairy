defmodule GreenFairy.CQL.OrderBuilder do
  @moduledoc """
  Builds Ecto order_by clauses from CQL order input.

  Transforms CQL order specifications into Ecto query order_by clauses,
  supporting simple field ordering, direction modifiers, and null positioning.

  ## Input Format

  Order input is a list of field-direction maps:

      [
        %{name: %{direction: :asc}},
        %{age: %{direction: :desc}}
      ]

  ## Example

      iex> order = [%{name: %{direction: :asc}}]
      iex> OrderBuilder.apply_order(query, order, User)
      #Ecto.Query<from u in User, order_by: [asc: u.name]>
  """

  import Ecto.Query
  alias GreenFairy.CQL.OrderOperator

  @doc """
  Applies CQL order specifications to an Ecto query.

  ## Parameters

  - `query` - Base Ecto query
  - `order_specs` - List of order specification maps
  - `schema` - The schema module for field lookups (optional)
  - `opts` - Additional options (optional)

  ## Returns

  The ordered Ecto query.
  """
  def apply_order(query, order_specs, _schema \\ nil, _opts \\ [])
  def apply_order(query, nil, _schema, _opts), do: query
  def apply_order(query, [], _schema, _opts), do: query

  def apply_order(query, order_specs, schema, opts) when is_list(order_specs) do
    # Parse order specs into OrderOperator structs
    order_operators =
      order_specs
      |> Enum.flat_map(&parse_order_spec/1)
      |> Enum.reject(&is_nil/1)

    # Build all order expressions at once
    if Enum.empty?(order_operators) do
      query
    else
      order_exprs =
        Enum.map(order_operators, fn op ->
          build_order_expr(op, schema, opts)
        end)

      # Apply all order expressions in a single order_by
      order_by(query, [q], ^order_exprs)
    end
  end

  # Parse a single order spec (e.g., %{name: %{direction: :asc}})
  defp parse_order_spec(spec) when is_map(spec) do
    spec
    |> Enum.map(fn {field, args} ->
      # Skip logical operators and non-field keys
      if field in [:_and, :_or, :_not] or not is_atom(field) do
        nil
      else
        parse_field_order(field, args)
      end
    end)
  end

  defp parse_order_spec(_), do: []

  # Parse field order arguments
  defp parse_field_order(field, args) when is_map(args) do
    OrderOperator.from_input(field, args)
  end

  defp parse_field_order(field, direction) when is_atom(direction) do
    OrderOperator.from_input(field, %{direction: direction})
  end

  defp parse_field_order(_, _), do: nil

  # Build a single order expression (to be used in order_by)
  defp build_order_expr(%OrderOperator{} = op, _schema, _opts) do
    field = op.field
    direction = OrderOperator.to_ecto_direction(op.direction)

    {direction, dynamic([q], field(q, ^field))}
  end
end
