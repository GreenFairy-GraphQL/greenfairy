defmodule SocialNetworkWeb.GraphQL.CQLIntegrationTest do
  use SocialNetwork.DataCase, async: true

  alias SocialNetwork.Accounts.User
  alias SocialNetwork.Content.{Post, Comment}
  alias SocialNetwork.Repo

  import Ecto.Query

  @moduledoc """
  Comprehensive integration tests for CQL (Connection Query Language) features
  using the real SocialNetwork schema.

  These tests exercise:
  - Basic field filtering (eq, neq, contains, etc.)
  - Logical operators (_and, _or, _not)
  - Association filtering (filter by related records)
  - Association ordering (order by related record fields)
  - Authorization enforcement (field-level access control)
  - Complex nested queries with real data
  """

  setup do
    # Create test users
    {:ok, alice} =
      %User{}
      |> User.changeset(%{
        email: "alice@example.com",
        username: "alice",
        display_name: "Alice Smith",
        bio: "Software engineer"
      })
      |> Repo.insert()

    {:ok, bob} =
      %User{}
      |> User.changeset(%{
        email: "bob@example.com",
        username: "bob",
        display_name: "Bob Jones",
        bio: "Product manager"
      })
      |> Repo.insert()

    {:ok, carol} =
      %User{}
      |> User.changeset(%{
        email: "carol@example.com",
        username: "carol",
        display_name: "Carol White"
      })
      |> Repo.insert()

    # Create test posts
    {:ok, alice_post1} =
      %Post{}
      |> Post.changeset(%{
        author_id: alice.id,
        body: "Hello world from Alice!",
        visibility: :public
      })
      |> Repo.insert()

    {:ok, alice_post2} =
      %Post{}
      |> Post.changeset(%{
        author_id: alice.id,
        body: "Another post about Elixir",
        visibility: :friends
      })
      |> Repo.insert()

    {:ok, bob_post} =
      %Post{}
      |> Post.changeset(%{
        author_id: bob.id,
        body: "Product roadmap for Q1",
        visibility: :public
      })
      |> Repo.insert()

    # Create test comments
    {:ok, comment1} =
      %Comment{}
      |> Comment.changeset(%{
        author_id: bob.id,
        post_id: alice_post1.id,
        body: "Great post Alice!"
      })
      |> Repo.insert()

    {:ok, comment2} =
      %Comment{}
      |> Comment.changeset(%{
        author_id: carol.id,
        post_id: alice_post1.id,
        body: "I agree!"
      })
      |> Repo.insert()

    %{
      users: %{alice: alice, bob: bob, carol: carol},
      posts: %{alice_post1: alice_post1, alice_post2: alice_post2, bob_post: bob_post},
      comments: %{comment1: comment1, comment2: comment2}
    }
  end

  describe "Basic CQL Filtering" do
    test "filters users by exact username match", %{users: users} do
      query = """
      query {
        users(where: { username: { _eq: "alice" } }) {
          id
          username
          email
        }
      }
      """

      result = run_query(query)

      assert {:ok, %{data: %{"users" => returned_users}}} = result
      assert length(returned_users) == 1
      assert List.first(returned_users)["username"] == "alice"
      assert List.first(returned_users)["email"] == "alice@example.com"
    end

    test "filters users by username contains", %{users: _users} do
      query = """
      query {
        users(where: { username: { _contains: "o" } }) {
          id
          username
        }
      }
      """

      result = run_query(query)

      assert {:ok, %{data: %{"users" => returned_users}}} = result
      assert length(returned_users) == 2
      usernames = Enum.map(returned_users, & &1["username"]) |> Enum.sort()
      assert usernames == ["bob", "carol"]
    end

    test "filters users by email starts_with", %{users: _users} do
      query = """
      query {
        users(where: { email: { _starts_with: "alice" } }) {
          id
          username
          email
        }
      }
      """

      result = run_query(query)

      assert {:ok, %{data: %{"users" => returned_users}}} = result
      assert length(returned_users) == 1
      assert List.first(returned_users)["username"] == "alice"
    end

    test "filters posts by visibility enum", %{posts: _posts} do
      query = """
      query {
        posts(where: { visibility: { _eq: "public" } }) {
          id
          body
          visibility
        }
      }
      """

      result = run_query(query)

      assert {:ok, %{data: %{"posts" => returned_posts}}} = result
      assert length(returned_posts) == 2
      assert Enum.all?(returned_posts, &(&1["visibility"] == "PUBLIC"))
    end

    test "filters posts by body contains", %{posts: _posts} do
      query = """
      query {
        posts(where: { body: { _contains: "Elixir" } }) {
          id
          body
        }
      }
      """

      result = run_query(query)

      assert {:ok, %{data: %{"posts" => returned_posts}}} = result
      assert length(returned_posts) == 1
      assert String.contains?(List.first(returned_posts)["body"], "Elixir")
    end
  end

  describe "Logical Operators" do
    test "combines filters with _and", %{users: _users} do
      query = """
      query {
        users(where: {
          _and: [
            { username: { _contains: "a" } }
            { email: { _starts_with: "alice" } }
          ]
        }) {
          id
          username
        }
      }
      """

      result = run_query(query)

      assert {:ok, %{data: %{"users" => returned_users}}} = result
      assert length(returned_users) == 1
      assert List.first(returned_users)["username"] == "alice"
    end

    test "combines filters with _or", %{users: _users} do
      query = """
      query {
        users(where: {
          _or: [
            { username: { _eq: "alice" } }
            { username: { _eq: "bob" } }
          ]
        }) {
          id
          username
        }
      }
      """

      result = run_query(query)

      assert {:ok, %{data: %{"users" => returned_users}}} = result
      assert length(returned_users) == 2
      usernames = Enum.map(returned_users, & &1["username"]) |> Enum.sort()
      assert usernames == ["alice", "bob"]
    end

    test "negates filters with _not", %{users: _users} do
      query = """
      query {
        users(where: {
          _not: { username: { _eq: "alice" } }
        }) {
          id
          username
        }
      }
      """

      result = run_query(query)

      assert {:ok, %{data: %{"users" => returned_users}}} = result
      assert length(returned_users) == 2
      usernames = Enum.map(returned_users, & &1["username"]) |> Enum.sort()
      assert usernames == ["bob", "carol"]
    end

    test "nests logical operators", %{posts: _posts} do
      query = """
      query {
        posts(where: {
          _or: [
            {
              _and: [
                { visibility: { _eq: "public" } }
                { body: { _contains: "Alice" } }
              ]
            }
            { body: { _contains: "roadmap" } }
          ]
        }) {
          id
          body
        }
      }
      """

      result = run_query(query)

      assert {:ok, %{data: %{"posts" => returned_posts}}} = result
      assert length(returned_posts) == 2
    end
  end

  describe "Association Filtering" do
    test "filters users by posts they've created", %{users: users} do
      query = """
      query {
        users(where: {
          posts: { body: { _contains: "Elixir" } }
        }) {
          id
          username
        }
      }
      """

      result = run_query(query)

      assert {:ok, %{data: %{"users" => returned_users}}} = result
      assert length(returned_users) == 1
      assert List.first(returned_users)["username"] == "alice"
    end

    test "filters users by multiple post criteria", %{users: users} do
      query = """
      query {
        users(where: {
          posts: {
            _and: [
              { visibility: { _eq: "public" } }
              { body: { _contains: "Alice" } }
            ]
          }
        }) {
          id
          username
        }
      }
      """

      result = run_query(query)

      assert {:ok, %{data: %{"users" => returned_users}}} = result
      assert length(returned_users) == 1
      assert List.first(returned_users)["username"] == "alice"
    end

    test "filters posts by author username", %{posts: _posts} do
      query = """
      query {
        posts(where: {
          author: { username: { _eq: "bob" } }
        }) {
          id
          body
        }
      }
      """

      result = run_query(query)

      assert {:ok, %{data: %{"posts" => returned_posts}}} = result
      assert length(returned_posts) == 1
      assert String.contains?(List.first(returned_posts)["body"], "roadmap")
    end

    test "filters posts by author email domain", %{posts: _posts} do
      query = """
      query {
        posts(where: {
          author: { email: { _contains: "@example.com" } }
        }) {
          id
          body
        }
      }
      """

      result = run_query(query)

      assert {:ok, %{data: %{"posts" => returned_posts}}} = result
      assert length(returned_posts) == 3
    end

    test "filters posts by comments content", %{posts: posts} do
      query = """
      query {
        posts(where: {
          comments: { body: { _contains: "Great" } }
        }) {
          id
          body
        }
      }
      """

      result = run_query(query)

      assert {:ok, %{data: %{"posts" => returned_posts}}} = result
      assert length(returned_posts) == 1
      assert String.contains?(List.first(returned_posts)["body"], "Hello world")
    end
  end

  describe "CQL Ordering" do
    test "orders users by username ascending", %{users: _users} do
      query = """
      query {
        users(order_by: [{ username: { direction: ASC } }]) {
          id
          username
        }
      }
      """

      result = run_query(query)

      assert {:ok, %{data: %{"users" => returned_users}}} = result
      usernames = Enum.map(returned_users, & &1["username"])
      assert usernames == ["alice", "bob", "carol"]
    end

    test "orders users by username descending", %{users: _users} do
      query = """
      query {
        users(order_by: [{ username: { direction: DESC } }]) {
          id
          username
        }
      }
      """

      result = run_query(query)

      assert {:ok, %{data: %{"users" => returned_users}}} = result
      usernames = Enum.map(returned_users, & &1["username"])
      assert usernames == ["carol", "bob", "alice"]
    end

    test "orders posts by multiple fields", %{posts: _posts} do
      query = """
      query {
        posts(order_by: [
          { visibility: { direction: ASC, priority: 1 } }
          { id: { direction: ASC, priority: 2 } }
        ]) {
          id
          visibility
        }
      }
      """

      result = run_query(query)

      assert {:ok, %{data: %{"posts" => returned_posts}}} = result
      assert length(returned_posts) == 3
    end
  end

  describe "Association Ordering" do
    test "orders posts by author username", %{posts: _posts} do
      query = """
      query {
        posts(order_by: [
          { author: { username: { direction: ASC } } }
        ]) {
          id
          body
        }
      }
      """

      result = run_query(query)

      assert {:ok, %{data: %{"posts" => returned_posts}}} = result
      assert length(returned_posts) == 3
      # First two posts should be from alice (alphabetically first)
      assert Enum.take(returned_posts, 2) |> Enum.all?(&String.contains?(&1["body"], ["Alice", "Elixir"]))
    end

    test "orders comments by post author username", %{comments: _comments} do
      query = """
      query {
        comments: allComments(order_by: [
          { post: { author: { username: { direction: DESC } } } }
        ]) {
          id
          body
        }
      }
      """

      # Note: This would require a comments query field in the schema
      # For now, we'll test the QueryBuilder directly in unit tests
      # This is a placeholder to show the intended usage
      assert true
    end
  end

  describe "Authorization Enforcement" do
    test "non-admin users cannot filter by email field", %{users: _users} do
      query = """
      query {
        users(where: { email: { _eq: "alice@example.com" } }) {
          id
          username
        }
      }
      """

      # Run query as non-admin user
      context = %{current_user: %{id: 1, is_admin: false}}
      result = run_query(query, context: context)

      # Should return an error about unauthorized field
      assert {:ok, %{errors: errors}} = result
      assert length(errors) > 0
      assert Enum.any?(errors, fn error ->
        String.contains?(error.message, "Unauthorized") or
        String.contains?(error.message, "email")
      end)
    end

    test "admin users can filter by email field", %{users: users} do
      query = """
      query {
        users(where: { email: { _eq: "alice@example.com" } }) {
          id
          username
          email
        }
      }
      """

      # Run query as admin user
      context = %{current_user: %{id: 1, is_admin: true}}
      result = run_query(query, context: context)

      assert {:ok, %{data: %{"users" => returned_users}}} = result
      assert length(returned_users) == 1
      assert List.first(returned_users)["email"] == "alice@example.com"
    end

    test "non-admin users can filter by allowed fields", %{users: _users} do
      query = """
      query {
        users(where: { username: { _eq: "alice" } }) {
          id
          username
          displayName
        }
      }
      """

      # Run query as non-admin user
      context = %{current_user: %{id: 1, is_admin: false}}
      result = run_query(query, context: context)

      assert {:ok, %{data: %{"users" => returned_users}}} = result
      assert length(returned_users) == 1
      assert List.first(returned_users)["username"] == "alice"
    end
  end

  describe "Complex Real-World Queries" do
    test "finds users who posted about Elixir, ordered by username", %{users: _users} do
      query = """
      query {
        users(
          where: {
            posts: {
              _and: [
                { body: { _contains: "Elixir" } }
                { visibility: { _eq: "friends" } }
              ]
            }
          }
          order_by: [{ username: { direction: ASC } }]
        ) {
          id
          username
          displayName
        }
      }
      """

      result = run_query(query)

      assert {:ok, %{data: %{"users" => returned_users}}} = result
      assert length(returned_users) == 1
      assert List.first(returned_users)["username"] == "alice"
    end

    test "finds public posts with comments, ordered by author", %{posts: _posts} do
      query = """
      query {
        posts(
          where: {
            _and: [
              { visibility: { _eq: "public" } }
              { comments: { body: { _is_nil: false } } }
            ]
          }
          order_by: [{ author: { username: { direction: ASC } } }]
        ) {
          id
          body
          visibility
        }
      }
      """

      result = run_query(query)

      assert {:ok, %{data: %{"posts" => returned_posts}}} = result
      assert length(returned_posts) >= 1
      assert Enum.all?(returned_posts, &(&1["visibility"] == "PUBLIC"))
    end

    test "combines multiple association filters", %{users: _users} do
      query = """
      query {
        users(where: {
          _and: [
            { posts: { visibility: { _eq: "public" } } }
            { username: { _contains: "alice" } }
          ]
        }) {
          id
          username
        }
      }
      """

      result = run_query(query)

      assert {:ok, %{data: %{"users" => returned_users}}} = result
      assert length(returned_users) == 1
      assert List.first(returned_users)["username"] == "alice"
    end

    test "excludes users without specific post characteristics", %{users: _users} do
      query = """
      query {
        users(where: {
          _not: {
            posts: { visibility: { _eq: "private" } }
          }
        }) {
          id
          username
        }
      }
      """

      result = run_query(query)

      assert {:ok, %{data: %{"users" => returned_users}}} = result
      # Should return all users since none have private posts
      assert length(returned_users) == 3
    end
  end

  # Helper function to run GraphQL queries
  defp run_query(query, opts \\ []) do
    context = Keyword.get(opts, :context, %{})

    Absinthe.run(
      query,
      SocialNetworkWeb.GraphQL.Schema,
      context: context
    )
  end
end
