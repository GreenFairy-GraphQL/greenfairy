defmodule SocialNetworkWeb.GraphQL.Types.Comment do
  use Absinthe.Object.Type

  alias SocialNetworkWeb.GraphQL.Interfaces

  type "Comment", struct: SocialNetwork.Content.Comment do
    implements Interfaces.Node

    field :id, non_null(:id)
    field :body, non_null(:string)

    field :author, non_null(:user)
    field :post, non_null(:post)
    field :parent, :comment
    field :replies, list_of(:comment)
    field :likes, list_of(:like)

    field :inserted_at, non_null(:naive_datetime)
    field :updated_at, non_null(:naive_datetime)
  end
end
