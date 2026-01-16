defmodule SocialNetwork.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use SocialNetwork.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias SocialNetwork.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import SocialNetwork.DataCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(SocialNetwork.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end

  @doc """
  A helper that creates a user with the given attributes.
  """
  def create_user(attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          email: "user#{System.unique_integer()}@example.com",
          username: "user#{System.unique_integer()}",
          display_name: "Test User"
        },
        attrs
      )

    %SocialNetwork.Accounts.User{}
    |> SocialNetwork.Accounts.User.changeset(attrs)
    |> SocialNetwork.Repo.insert!()
  end

  @doc """
  A helper that creates a post with the given attributes.
  """
  def create_post(user, attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          body: "Test post body",
          visibility: :public,
          author_id: user.id
        },
        attrs
      )

    %SocialNetwork.Content.Post{}
    |> SocialNetwork.Content.Post.changeset(attrs)
    |> SocialNetwork.Repo.insert!()
  end

  @doc """
  A helper that creates a comment with the given attributes.
  """
  def create_comment(user, post, attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          body: "Test comment body",
          author_id: user.id,
          post_id: post.id
        },
        attrs
      )

    %SocialNetwork.Content.Comment{}
    |> SocialNetwork.Content.Comment.changeset(attrs)
    |> SocialNetwork.Repo.insert!()
  end
end
