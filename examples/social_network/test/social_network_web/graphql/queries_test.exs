defmodule SocialNetworkWeb.GraphQL.QueriesTest do
  use SocialNetwork.GraphQLCase

  describe "users query" do
    test "returns empty list when no users exist" do
      query = """
      query {
        users {
          id
          email
          username
        }
      }
      """

      result = run_query(query)
      assert get_data(result) == %{"users" => []}
    end

    test "returns all users" do
      user1 = create_user(%{email: "alice@example.com", username: "alice"})
      user2 = create_user(%{email: "bob@example.com", username: "bob"})

      query = """
      query {
        users {
          id
          email
          username
        }
      }
      """

      result = run_query(query)
      data = get_data(result)

      assert length(data["users"]) == 2

      emails = Enum.map(data["users"], & &1["email"])
      assert "alice@example.com" in emails
      assert "bob@example.com" in emails
    end
  end

  describe "user query" do
    test "returns user by id" do
      user = create_user(%{email: "alice@example.com", username: "alice", display_name: "Alice"})

      query = """
      query GetUser($id: ID!) {
        user(id: $id) {
          id
          email
          username
          displayName
        }
      }
      """

      result = run_query(query, %{"id" => to_string(user.id)})
      data = get_data(result)

      assert data["user"]["email"] == "alice@example.com"
      assert data["user"]["username"] == "alice"
      assert data["user"]["displayName"] == "Alice"
    end

    test "returns nil for non-existent user" do
      query = """
      query GetUser($id: ID!) {
        user(id: $id) {
          id
          email
        }
      }
      """

      result = run_query(query, %{"id" => "99999"})
      data = get_data(result)

      assert data["user"] == nil
    end
  end

  describe "viewer query" do
    test "returns nil when not authenticated" do
      query = """
      query {
        viewer {
          id
          email
        }
      }
      """

      result = run_query(query)
      data = get_data(result)

      assert data["viewer"] == nil
    end

    test "returns current user when authenticated" do
      user = create_user(%{email: "me@example.com", username: "me"})

      query = """
      query {
        viewer {
          id
          email
          username
        }
      }
      """

      result = run_query_as(query, user)
      data = get_data(result)

      assert data["viewer"]["email"] == "me@example.com"
      assert data["viewer"]["username"] == "me"
    end
  end

  describe "posts query" do
    test "returns empty list when no posts exist" do
      query = """
      query {
        posts {
          id
          body
        }
      }
      """

      result = run_query(query)
      assert get_data(result) == %{"posts" => []}
    end

    test "returns all posts" do
      user = create_user()
      post1 = create_post(user, %{body: "First post"})
      post2 = create_post(user, %{body: "Second post"})

      query = """
      query {
        posts {
          id
          body
        }
      }
      """

      result = run_query(query)
      data = get_data(result)

      assert length(data["posts"]) == 2
      bodies = Enum.map(data["posts"], & &1["body"])
      assert "First post" in bodies
      assert "Second post" in bodies
    end

    test "filters posts by visibility" do
      user = create_user()
      _public_post = create_post(user, %{body: "Public post", visibility: :public})
      _private_post = create_post(user, %{body: "Private post", visibility: :private})

      query = """
      query GetPosts($visibility: PostVisibility) {
        posts(visibility: $visibility) {
          id
          body
          visibility
        }
      }
      """

      result = run_query(query, %{"visibility" => "PUBLIC"})
      data = get_data(result)

      assert length(data["posts"]) == 1
      assert hd(data["posts"])["body"] == "Public post"
    end
  end

  describe "post query" do
    test "returns post by id" do
      user = create_user(%{username: "author"})
      post = create_post(user, %{body: "My awesome post"})

      query = """
      query GetPost($id: ID!) {
        post(id: $id) {
          id
          body
          visibility
        }
      }
      """

      result = run_query(query, %{"id" => to_string(post.id)})
      data = get_data(result)

      assert data["post"]["body"] == "My awesome post"
      assert data["post"]["id"] == to_string(post.id)
    end
  end
end
