defmodule SocialNetworkWeb.GraphQL.SchemaTest do
  use SocialNetwork.GraphQLCase

  describe "schema introspection" do
    test "has User type" do
      query = """
      query {
        __type(name: "User") {
          name
          kind
          fields {
            name
            type {
              name
              kind
            }
          }
        }
      }
      """

      result = run_query(query)
      data = get_data(result)

      assert data["__type"]["name"] == "User"
      assert data["__type"]["kind"] == "OBJECT"

      field_names = Enum.map(data["__type"]["fields"], & &1["name"])
      assert "id" in field_names
      assert "email" in field_names
      assert "username" in field_names
      assert "posts" in field_names
    end

    test "has Post type" do
      query = """
      query {
        __type(name: "Post") {
          name
          fields {
            name
          }
        }
      }
      """

      result = run_query(query)
      data = get_data(result)

      assert data["__type"]["name"] == "Post"

      field_names = Enum.map(data["__type"]["fields"], & &1["name"])
      assert "id" in field_names
      assert "body" in field_names
      assert "author" in field_names
      assert "comments" in field_names
      assert "visibility" in field_names
    end

    test "has PostVisibility enum" do
      query = """
      query {
        __type(name: "PostVisibility") {
          name
          kind
          enumValues {
            name
          }
        }
      }
      """

      result = run_query(query)
      data = get_data(result)

      assert data["__type"]["name"] == "PostVisibility"
      assert data["__type"]["kind"] == "ENUM"

      values = Enum.map(data["__type"]["enumValues"], & &1["name"])
      assert "PUBLIC" in values
      assert "FRIENDS" in values
      assert "PRIVATE" in values
    end

    test "has FriendshipStatus enum" do
      query = """
      query {
        __type(name: "FriendshipStatus") {
          name
          kind
          enumValues {
            name
          }
        }
      }
      """

      result = run_query(query)
      data = get_data(result)

      assert data["__type"]["name"] == "FriendshipStatus"
      assert data["__type"]["kind"] == "ENUM"

      values = Enum.map(data["__type"]["enumValues"], & &1["name"])
      assert "PENDING" in values
      assert "ACCEPTED" in values
      assert "BLOCKED" in values
    end

    test "has Node interface" do
      query = """
      query {
        __type(name: "Node") {
          name
          kind
          possibleTypes {
            name
          }
        }
      }
      """

      result = run_query(query)
      data = get_data(result)

      assert data["__type"]["name"] == "Node"
      assert data["__type"]["kind"] == "INTERFACE"
    end

    test "has required queries" do
      query = """
      query {
        __schema {
          queryType {
            fields {
              name
            }
          }
        }
      }
      """

      result = run_query(query)
      data = get_data(result)

      query_fields = Enum.map(data["__schema"]["queryType"]["fields"], & &1["name"])
      assert "user" in query_fields
      assert "users" in query_fields
      assert "post" in query_fields
      assert "posts" in query_fields
      assert "viewer" in query_fields
      assert "node" in query_fields
    end

    test "has required mutations" do
      query = """
      query {
        __schema {
          mutationType {
            fields {
              name
            }
          }
        }
      }
      """

      result = run_query(query)
      data = get_data(result)

      mutation_fields = Enum.map(data["__schema"]["mutationType"]["fields"], & &1["name"])
      assert "createUser" in mutation_fields
      assert "createPost" in mutation_fields
      assert "createComment" in mutation_fields
      assert "likePost" in mutation_fields
      assert "sendFriendRequest" in mutation_fields
      assert "acceptFriendRequest" in mutation_fields
    end
  end

  describe "relationship queries" do
    test "can query user's basic info" do
      user = create_user(%{username: "author", display_name: "Author"})

      query = """
      query GetUser($id: ID!) {
        user(id: $id) {
          username
          displayName
        }
      }
      """

      result = run_query(query, %{"id" => to_string(user.id)})
      data = get_data(result)

      assert data["user"]["username"] == "author"
      assert data["user"]["displayName"] == "Author"
    end

    test "can query post's basic info" do
      user = create_user()
      post = create_post(user, %{body: "Original post", visibility: :public})

      query = """
      query GetPost($id: ID!) {
        post(id: $id) {
          body
          visibility
        }
      }
      """

      result = run_query(query, %{"id" => to_string(post.id)})
      data = get_data(result)

      assert data["post"]["body"] == "Original post"
      assert data["post"]["visibility"] == "PUBLIC"
    end
  end
end
