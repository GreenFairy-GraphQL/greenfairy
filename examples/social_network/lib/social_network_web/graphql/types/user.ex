defmodule SocialNetworkWeb.GraphQL.Types.User do
  use GreenFairy.Type

  import Ecto.Query

  alias SocialNetworkWeb.GraphQL.Interfaces

  type "User", struct: SocialNetwork.Accounts.User do
    implements Interfaces.Node

    # Expose this type as a query field - auto-generates: user(id: ID!): User
    expose :id

    # CQL is automatically enabled for types with structs!
    # Authorization: admins see all fields, others see limited fields
    authorize fn _user, ctx ->
      current_user = ctx[:current_user]

      if current_user && current_user.is_admin do
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

    # Example 1: Simple boolean filter with custom constraint
    # Filters users based on whether they have filled out their bio
    filter :has_bio, :boolean,
      apply: fn query, op, value, _ctx ->
        case {op, value} do
          {:eq, true} ->
            {:ok, where(query, [u], not is_nil(u.bio) and u.bio != "")}

          {:eq, false} ->
            {:ok, where(query, [u], is_nil(u.bio) or u.bio == "")}

          _ ->
            {:ok, query}
        end
      end,
      description: "Filter users by whether they have a bio"

    # Example 2: Custom string filter with prefix matching
    # More flexible than the standard _starts_with operator
    filter :username_starts_with, :string,
      apply: fn query, op, value, _ctx ->
        case op do
          :eq ->
            # Custom logic: case-insensitive prefix match
            pattern = "#{String.downcase(value)}%"
            {:ok, where(query, [u], like(fragment("LOWER(?)", u.username), ^pattern))}

          :contains ->
            # Also support contains for this filter
            pattern = "%#{String.downcase(value)}%"
            {:ok, where(query, [u], like(fragment("LOWER(?)", u.username), ^pattern))}

          _ ->
            {:ok, query}
        end
      end,
      description: "Case-insensitive username prefix filter"

    # Example 3: Subquery-based filter for checking friendships
    # Demonstrates how to filter based on related data
    filter :has_friends, :boolean,
      apply: fn query, op, value, _ctx ->
        case {op, value} do
          {:eq, true} ->
            # User has at least one accepted friendship
            subquery =
              SocialNetwork.Accounts.Friendship
              |> where([f], f.user_id == parent_as(:user).id or f.friend_id == parent_as(:user).id)
              |> where([f], f.status == :accepted)
              |> select([f], f.id)
              |> limit(1)

            {:ok, from(u in query, as: :user, where: exists(subquery))}

          {:eq, false} ->
            # User has no accepted friendships
            subquery =
              SocialNetwork.Accounts.Friendship
              |> where([f], f.user_id == parent_as(:user).id or f.friend_id == parent_as(:user).id)
              |> where([f], f.status == :accepted)
              |> select([f], f.id)
              |> limit(1)

            {:ok, from(u in query, as: :user, where: not exists(subquery))}

          _ ->
            {:ok, query}
        end
      end,
      description: "Filter users by whether they have any accepted friendships"

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
