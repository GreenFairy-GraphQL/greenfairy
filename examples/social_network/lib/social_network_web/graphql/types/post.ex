defmodule SocialNetworkWeb.GraphQL.Types.Post do
  use Absinthe.Object.Type

  alias SocialNetworkWeb.GraphQL.Interfaces

  type "Post", struct: SocialNetwork.Content.Post do
    implements Interfaces.Node

    field :id, non_null(:id)
    field :body, non_null(:string)
    field :media_url, :string
    field :visibility, :post_visibility

    field :author, non_null(:user)
    field :comments, list_of(:comment)
    field :likes, list_of(:like)

    field :inserted_at, non_null(:naive_datetime)
    field :updated_at, non_null(:naive_datetime)
  end
end
