defmodule SocialNetworkWeb.GraphQL.Types.User do
  use Absinthe.Object.Type

  alias SocialNetworkWeb.GraphQL.Interfaces

  type "User", struct: SocialNetwork.Accounts.User do
    implements Interfaces.Node

    field :id, non_null(:id)
    field :email, non_null(:string)
    field :username, non_null(:string)
    field :display_name, :string
    field :bio, :string
    field :avatar_url, :string

    field :posts, list_of(:post)
    field :comments, list_of(:comment)
    field :likes, list_of(:like)
    field :friends, list_of(:user)
    field :friendships, list_of(:friendship)

    field :inserted_at, non_null(:naive_datetime)
    field :updated_at, non_null(:naive_datetime)
  end
end
