defmodule Absinthe.Object.CQL.QueryDefinition do
  @moduledoc """
  Represents a complete CQL query definition with filters and ordering.

  This is the intermediate representation between GraphQL input and
  the final Ecto query. It captures both `where` filters and `order_by`
  clauses in a structured format.

  ## Fields

  - `:where` - The filter expression (BinaryOperator, UnaryOperator, AssociatedQuery)
  - `:order_by` - List of order terms (OrderOperator, AssociatedOrder)

  ## Example

      %QueryDefinition{
        where: %BinaryOperator{
          lhs: %Field{name: :status},
          operator: :eq,
          rhs: %Value{data: "active"}
        },
        order_by: [
          %OrderOperator{field: :name, direction: :asc},
          %OrderOperator{field: :created_at, direction: :desc}
        ]
      }
  """

  defstruct where: nil, order_by: []

  @type t :: %__MODULE__{
          where: term() | nil,
          order_by: [term()]
        }

  @doc """
  Creates a new QueryDefinition.
  """
  def new(opts \\ []) do
    struct!(__MODULE__, opts)
  end

  @doc """
  Checks if the query definition has any filters.
  """
  def has_where?(%__MODULE__{where: nil}), do: false
  def has_where?(%__MODULE__{}), do: true

  @doc """
  Checks if the query definition has any ordering.
  """
  def has_order_by?(%__MODULE__{order_by: []}), do: false
  def has_order_by?(%__MODULE__{}), do: true

  @doc """
  Returns true if the query definition is empty (no filters or ordering).
  """
  def empty?(%__MODULE__{} = qd) do
    not has_where?(qd) and not has_order_by?(qd)
  end
end
