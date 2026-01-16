defmodule SocialNetworkWeb.GraphQL.Types.User do
  use GreenFairy.Type

  alias SocialNetworkWeb.GraphQL.Interfaces

  type "User", struct: SocialNetwork.Accounts.User do
    implements Interfaces.Node

    # CQL is automatically enabled for types with structs!
    # Authorization: admins see all fields, others see limited fields
    authorize fn _user, ctx ->
      if ctx[:current_user]?.is_admin do
        :all
      else
        [:id, :username, :display_name, :bio, :avatar_url, :inserted_at, :updated_at]
      end
    end

    field :id, non_null(:id)
    field :email, non_null(:string)
    field :username, non_null(:string)
    field :display_name, :string
    field :bio, :string
    field :avatar_url, :string

    # Association fields - automatically inferred from Ecto schema
    # Adds limit/offset pagination for has_many associations
    assoc :posts
    assoc :comments
    assoc :likes
    assoc :friendships

    # friends is a has_through association - requires custom loader
    # Using inline loader syntax for clarity
    field :friends, list_of(:user) do
      loader users, _args, _context do
        import Ecto.Query

        user_ids = Enum.map(users, & &1.id)

        # Query all friendships for these users
        friendships =
          SocialNetwork.Accounts.Friendship
          |> where([f], f.user_id in ^user_ids or f.friend_id in ^user_ids)
          |> where([f], f.status == :accepted)
          |> SocialNetwork.Repo.all()
          |> SocialNetwork.Repo.preload([:user, :friend])

        # Group friends by user
        users
        |> Enum.map(fn user ->
          friends =
            friendships
            |> Enum.filter(&(&1.user_id == user.id or &1.friend_id == user.id))
            |> Enum.map(fn friendship ->
              if friendship.user_id == user.id, do: friendship.friend, else: friendship.user
            end)

          {user, friends}
        end)
        |> Map.new()
      end
    end

    field :inserted_at, non_null(:naive_datetime)
    field :updated_at, non_null(:naive_datetime)
  end
end
