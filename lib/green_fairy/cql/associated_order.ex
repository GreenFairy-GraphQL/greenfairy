defmodule GreenFairy.CQL.AssociatedOrder do
  @moduledoc """
  Represents a nested association order in a CQL query.

  When ordering by associated records (e.g., order users by their
  organization's name), this struct captures the nested order information.

  ## Fields

  - `:association` - The Ecto association struct
  - `:parent_field` - The field name on the parent schema
  - `:order_term` - The OrderOperator or nested AssociatedOrder
  - `:list_module` - The CQL list module for the associated type (if any)
  - `:inject` - Optional function to inject custom query logic

  ## Example

      # Order users by organization.name ASC
      %AssociatedOrder{
        association: %Ecto.Association.BelongsTo{...},
        parent_field: :organization,
        order_term: %OrderOperator{field: :name, direction: :asc}
      }

  ## Deeply Nested Ordering

  Order terms can be recursively nested for deep association ordering:

      # Order users by organization.parent_org.name ASC
      %AssociatedOrder{
        parent_field: :organization,
        order_term: %AssociatedOrder{
          parent_field: :parent_org,
          order_term: %OrderOperator{field: :name, direction: :asc}
        }
      }
  """

  alias GreenFairy.CQL.OrderOperator

  defstruct [
    :association,
    :parent_field,
    :order_term,
    :list_module,
    :inject
  ]

  @type t :: %__MODULE__{
          association: term() | nil,
          parent_field: atom(),
          order_term: OrderOperator.t() | t(),
          list_module: module() | nil,
          inject: function() | nil
        }

  @doc """
  Creates a new AssociatedOrder.
  """
  def new(opts) do
    struct!(__MODULE__, opts)
  end

  @doc """
  Returns the cardinality of this association (:one or :many).
  """
  def cardinality(%__MODULE__{association: %{cardinality: cardinality}}), do: cardinality
  def cardinality(%__MODULE__{}), do: nil

  @doc """
  Checks if ordering by this association is allowed.

  By default, only :one cardinality associations can be ordered.
  :many associations require explicit allow_in_order_by flag.
  """
  def orderable?(%__MODULE__{} = assoc_order, opts \\ []) do
    allow_many = Keyword.get(opts, :allow_in_order_by, false)

    case cardinality(assoc_order) do
      :one -> true
      :many -> allow_many
      nil -> true
    end
  end
end
