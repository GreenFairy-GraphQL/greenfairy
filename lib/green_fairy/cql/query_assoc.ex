defmodule GreenFairy.CQL.QueryAssoc do
  @moduledoc """
  Represents a queryable association in a CQL type definition.

  This struct captures metadata about an association that can be filtered
  or ordered in CQL queries, including cardinality validation and nested
  filtering rules.

  ## Fields

  - `:field` - The field name exposed in GraphQL (atom)
  - `:association` - The Ecto association struct
  - `:related_queryable` - The related Ecto schema module
  - `:query_field` - The actual association name on the schema
  - `:description` - Association description for documentation
  - `:allow_in_order_by` - Allow ordering by :many associations
  - `:allow_has_through` - Allow HasThrough associations
  - `:inject` - Custom function to inject query logic

  ## Cardinality Rules

  - `:one` associations (belongs_to, has_one) can always be filtered/ordered
  - `:many` associations (has_many, many_to_many) can only be filtered by default
  - Set `allow_in_order_by: true` to enable ordering by :many associations

  ## Example

      %QueryAssoc{
        field: :organization,
        association: %Ecto.Association.BelongsTo{...},
        related_queryable: MyApp.Organization,
        description: "The user's organization"
      }
  """

  defstruct [
    :field,
    :association,
    :related_queryable,
    :query_field,
    :description,
    :inject,
    allow_in_order_by: false,
    allow_has_through: false
  ]

  @type t :: %__MODULE__{
          field: atom(),
          association: term(),
          related_queryable: module(),
          query_field: atom(),
          description: String.t() | nil,
          allow_in_order_by: boolean(),
          allow_has_through: boolean(),
          inject: function() | nil
        }

  @doc """
  Creates a new QueryAssoc from options.

  ## Options

  - `:queryable` - Required. The parent Ecto schema module.
  - `:field` - Required. The association field name.
  - `:as` - Optional alias for the field in GraphQL.
  - `:description` - Optional description.
  - `:allow_in_order_by` - Allow ordering by :many associations.
  - `:allow_has_through` - Allow HasThrough associations.
  - `:inject` - Custom function to inject query logic.

  ## Example

      QueryAssoc.new(
        queryable: MyApp.User,
        field: :organization,
        description: "The user's organization"
      )
  """
  def new(opts) do
    queryable = Keyword.fetch!(opts, :queryable)
    field = Keyword.fetch!(opts, :field)
    field_alias = Keyword.get(opts, :as, field)
    allow_has_through = Keyword.get(opts, :allow_has_through, false)

    Code.ensure_compiled(queryable)

    association = fetch_association!(queryable, field, allow_has_through)
    related_queryable = get_related_queryable(association)

    struct!(__MODULE__,
      field: field_alias,
      query_field: field,
      association: association,
      related_queryable: related_queryable,
      description: Keyword.get(opts, :description),
      allow_in_order_by: Keyword.get(opts, :allow_in_order_by, false),
      allow_has_through: allow_has_through,
      inject: Keyword.get(opts, :inject)
    )
  end

  defp fetch_association!(queryable, field, allow_has_through) do
    case queryable.__schema__(:association, field) do
      nil ->
        raise ArgumentError,
              "Association `#{field}` not found in #{inspect(queryable)}"

      %Ecto.Association.HasThrough{} = assoc ->
        unless allow_has_through do
          raise ArgumentError,
                "HasThrough associations are not supported by default. " <>
                  "Set allow_has_through: true for `#{field}` in #{inspect(queryable)}"
        end

        assoc

      assoc ->
        assoc
    end
  end

  defp get_related_queryable(%Ecto.Association.HasThrough{through: through, owner: owner}) do
    # For HasThrough, traverse the association chain to get the final queryable
    # e.g., has_many :posts, through: [:user, :posts] -> get User, then Posts
    traverse_through(owner, through)
  end

  defp get_related_queryable(%{queryable: queryable}), do: queryable

  defp traverse_through(owner, [assoc_name | rest]) do
    case owner.__schema__(:association, assoc_name) do
      nil ->
        raise ArgumentError,
              "Association `#{assoc_name}` not found in #{inspect(owner)} during HasThrough traversal"

      %Ecto.Association.HasThrough{} = nested ->
        traverse_through(nested.owner, nested.through ++ rest)

      assoc ->
        if rest == [] do
          assoc.queryable
        else
          traverse_through(assoc.queryable, rest)
        end
    end
  end

  @doc """
  Returns the cardinality of the association (:one or :many).
  """
  def cardinality(%__MODULE__{association: %{cardinality: c}}), do: c

  @doc """
  Checks if the association can be used in ORDER BY.

  :one associations can always be ordered.
  :many associations require allow_in_order_by: true.
  """
  def orderable?(%__MODULE__{allow_in_order_by: true}), do: true
  def orderable?(%__MODULE__{association: %{cardinality: :one}}), do: true
  def orderable?(%__MODULE__{}), do: false

  @doc """
  Checks if the association can be used in WHERE filters.

  All associations can be filtered by default.
  """
  def filterable?(%__MODULE__{}), do: true
end
