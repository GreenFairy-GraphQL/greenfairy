defmodule SocialNetworkWeb.GraphQL.Types.Like do
  use Absinthe.Object.Type

  alias SocialNetworkWeb.GraphQL.Interfaces

  type "Like", struct: SocialNetwork.Content.Like do
    implements Interfaces.Node

    field :id, non_null(:id)

    field :user, non_null(:user)
    field :post, :post
    field :comment, :comment

    field :inserted_at, non_null(:naive_datetime)
    field :updated_at, non_null(:naive_datetime)
  end
end
