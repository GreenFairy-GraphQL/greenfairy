defmodule SocialNetworkWeb.GraphQL.Types.Friendship do
  use GreenFairy.Type

  alias SocialNetworkWeb.GraphQL.Interfaces

  type "Friendship", struct: SocialNetwork.Accounts.Friendship do
    implements Interfaces.Node

    field :id, non_null(:id)
    field :status, :friendship_status

    # Association fields - automatically inferred from Ecto schema
    assoc :user
    assoc :friend

    field :inserted_at, non_null(:naive_datetime)
    field :updated_at, non_null(:naive_datetime)
  end
end
