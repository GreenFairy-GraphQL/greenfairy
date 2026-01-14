defmodule SocialNetworkWeb.GraphQL.Schema do
  use Absinthe.Object.Schema

  alias SocialNetworkWeb.GraphQL

  # Import Absinthe built-in types (for :naive_datetime, etc.)
  import_types Absinthe.Type.Custom

  # Import all type modules
  import_types GraphQL.Interfaces.Node
  import_types GraphQL.Enums.FriendshipStatus
  import_types GraphQL.Enums.PostVisibility
  import_types GraphQL.Types.User
  import_types GraphQL.Types.Friendship
  import_types GraphQL.Types.Post
  import_types GraphQL.Types.Comment
  import_types GraphQL.Types.Like

  query do
    field :node, :node do
      arg :id, non_null(:id)

      resolve fn %{id: id}, _ ->
        # Parse global ID and fetch node
        {:ok, nil}
      end
    end

    field :viewer, :user do
      resolve fn _, %{context: context} ->
        {:ok, context[:current_user]}
      end
    end

    field :user, :user do
      arg :id, non_null(:id)

      resolve fn %{id: id}, _ ->
        {:ok, SocialNetwork.Repo.get(SocialNetwork.Accounts.User, id)}
      end
    end

    field :users, list_of(:user) do
      resolve fn _, _ ->
        {:ok, SocialNetwork.Repo.all(SocialNetwork.Accounts.User)}
      end
    end

    field :post, :post do
      arg :id, non_null(:id)

      resolve fn %{id: id}, _ ->
        {:ok, SocialNetwork.Repo.get(SocialNetwork.Content.Post, id)}
      end
    end

    field :posts, list_of(:post) do
      arg :visibility, :post_visibility

      resolve fn args, _ ->
        import Ecto.Query
        query = SocialNetwork.Content.Post

        query =
          if args[:visibility] do
            from p in query, where: p.visibility == ^args[:visibility]
          else
            query
          end

        {:ok, SocialNetwork.Repo.all(query)}
      end
    end
  end

  mutation do
    field :create_user, :user do
      arg :email, non_null(:string)
      arg :username, non_null(:string)
      arg :display_name, :string

      resolve fn args, _ ->
        %SocialNetwork.Accounts.User{}
        |> SocialNetwork.Accounts.User.changeset(args)
        |> SocialNetwork.Repo.insert()
      end
    end

    field :create_post, :post do
      arg :body, non_null(:string)
      arg :media_url, :string
      arg :visibility, :post_visibility

      resolve fn args, %{context: context} ->
        case context[:current_user] do
          nil ->
            {:error, "Not authenticated"}

          user ->
            %SocialNetwork.Content.Post{}
            |> SocialNetwork.Content.Post.changeset(Map.put(args, :author_id, user.id))
            |> SocialNetwork.Repo.insert()
        end
      end
    end

    field :create_comment, :comment do
      arg :post_id, non_null(:id)
      arg :body, non_null(:string)
      arg :parent_id, :id

      resolve fn args, %{context: context} ->
        case context[:current_user] do
          nil ->
            {:error, "Not authenticated"}

          user ->
            %SocialNetwork.Content.Comment{}
            |> SocialNetwork.Content.Comment.changeset(Map.put(args, :author_id, user.id))
            |> SocialNetwork.Repo.insert()
        end
      end
    end

    field :like_post, :like do
      arg :post_id, non_null(:id)

      resolve fn %{post_id: post_id}, %{context: context} ->
        case context[:current_user] do
          nil ->
            {:error, "Not authenticated"}

          user ->
            %SocialNetwork.Content.Like{}
            |> SocialNetwork.Content.Like.changeset(%{user_id: user.id, post_id: post_id})
            |> SocialNetwork.Repo.insert()
        end
      end
    end

    field :send_friend_request, :friendship do
      arg :friend_id, non_null(:id)

      resolve fn %{friend_id: friend_id}, %{context: context} ->
        case context[:current_user] do
          nil ->
            {:error, "Not authenticated"}

          user ->
            %SocialNetwork.Accounts.Friendship{}
            |> SocialNetwork.Accounts.Friendship.changeset(%{
              user_id: user.id,
              friend_id: friend_id,
              status: :pending
            })
            |> SocialNetwork.Repo.insert()
        end
      end
    end

    field :accept_friend_request, :friendship do
      arg :friendship_id, non_null(:id)

      resolve fn %{friendship_id: friendship_id}, %{context: context} ->
        case context[:current_user] do
          nil ->
            {:error, "Not authenticated"}

          _user ->
            case SocialNetwork.Repo.get(SocialNetwork.Accounts.Friendship, friendship_id) do
              nil ->
                {:error, "Friendship not found"}

              friendship ->
                friendship
                |> SocialNetwork.Accounts.Friendship.changeset(%{status: :accepted})
                |> SocialNetwork.Repo.update()
            end
        end
      end
    end
  end

  def context(ctx) do
    loader = SocialNetworkWeb.GraphQL.DataLoader.new()
    Map.put(ctx, :loader, loader)
  end

  def plugins do
    [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
  end
end
