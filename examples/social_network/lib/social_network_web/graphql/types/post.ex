defmodule SocialNetworkWeb.GraphQL.Types.Post do
  use GreenFairy.Type

  alias SocialNetworkWeb.GraphQL.Interfaces

  type "Post", struct: SocialNetwork.Content.Post do
    implements Interfaces.Node

    # CQL is automatically enabled for types with structs!
    # Authorization: all users can see all post fields
    authorize fn _post, _ctx ->
      :all
    end

    field :id, non_null(:id)
    field :body, non_null(:string)
    field :media_url, :string
    field :visibility, :post_visibility

    # Association fields - automatically inferred from Ecto schema
    assoc :author
    assoc :comments
    assoc :likes

    field :inserted_at, non_null(:naive_datetime)
    field :updated_at, non_null(:naive_datetime)
  end
end
