defmodule GreenFairy.CQL.AssociatedQuery do
  @moduledoc """
  Represents a nested association filter in a CQL query.

  When filtering on associated records (e.g., filter users by their
  organization's name), this struct captures the nested query information.

  ## Fields

  - `:association` - The Ecto association struct
  - `:parent_field` - The field name on the parent schema
  - `:query_definition` - The nested QueryDefinition for the association
  - `:list_module` - The CQL list module for the associated type (if any)
  - `:inject` - Optional function to inject custom query logic

  ## Example

      # Filter users where organization.name = "Acme"
      %AssociatedQuery{
        association: %Ecto.Association.BelongsTo{...},
        parent_field: :organization,
        query_definition: %QueryDefinition{
          where: %BinaryOperator{lhs: :name, operator: :eq, rhs: "Acme"}
        }
      }
  """

  alias GreenFairy.CQL.QueryDefinition

  defstruct [
    :association,
    :parent_field,
    :query_definition,
    :list_module,
    :inject
  ]

  @type t :: %__MODULE__{
          association: term() | nil,
          parent_field: atom(),
          query_definition: QueryDefinition.t(),
          list_module: module() | nil,
          inject: function() | nil
        }

  @doc """
  Creates a new AssociatedQuery.
  """
  def new(opts) do
    struct!(__MODULE__, opts)
  end

  @doc """
  Returns the related queryable module for this association.
  """
  def related_queryable(%__MODULE__{association: %{queryable: queryable}}), do: queryable
  def related_queryable(%__MODULE__{}), do: nil

  @doc """
  Returns the cardinality of this association (:one or :many).
  """
  def cardinality(%__MODULE__{association: %{cardinality: cardinality}}), do: cardinality
  def cardinality(%__MODULE__{}), do: nil
end
