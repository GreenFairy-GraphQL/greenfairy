defmodule SocialNetworkWeb.GraphQL.Types.Comment do
  use GreenFairy.Type

  alias SocialNetworkWeb.GraphQL.Interfaces

  type "Comment", struct: SocialNetwork.Content.Comment do
    implements Interfaces.Node

    # CQL is automatically enabled for types with structs!
    # Authorization: all users can see all comment fields
    authorize fn _comment, _ctx ->
      :all
    end

    field :id, non_null(:id)
    field :body, non_null(:string)

    # Association fields - automatically inferred from Ecto schema
    assoc :author
    assoc :post
    assoc :parent
    assoc :replies
    assoc :likes

    field :inserted_at, non_null(:naive_datetime)
    field :updated_at, non_null(:naive_datetime)
  end
end
