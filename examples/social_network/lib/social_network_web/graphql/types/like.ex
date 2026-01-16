defmodule SocialNetworkWeb.GraphQL.Types.Like do
  use GreenFairy.Type

  import Absinthe.Resolution.Helpers, only: [dataloader: 1]

  alias SocialNetworkWeb.GraphQL.Interfaces

  type "Like", struct: SocialNetwork.Content.Like do
    implements Interfaces.Node

    field :id, non_null(:id)

    field :user, non_null(:user) do
      resolve dataloader(:repo)
    end

    field :post, :post do
      resolve dataloader(:repo)
    end

    field :comment, :comment do
      resolve dataloader(:repo)
    end

    field :inserted_at, non_null(:naive_datetime)
    field :updated_at, non_null(:naive_datetime)
  end
end
