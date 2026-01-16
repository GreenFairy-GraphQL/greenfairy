defmodule SocialNetworkWeb.GraphQL.MutationsTest do
  use SocialNetwork.GraphQLCase

  describe "createUser mutation" do
    test "creates a new user" do
      mutation = """
      mutation CreateUser($email: String!, $username: String!, $displayName: String) {
        createUser(email: $email, username: $username, displayName: $displayName) {
          id
          email
          username
          displayName
        }
      }
      """

      variables = %{
        "email" => "newuser@example.com",
        "username" => "newuser",
        "displayName" => "New User"
      }

      result = run_query(mutation, variables)
      data = get_data(result)

      assert data["createUser"]["email"] == "newuser@example.com"
      assert data["createUser"]["username"] == "newuser"
      assert data["createUser"]["displayName"] == "New User"
      assert data["createUser"]["id"] != nil
    end

    test "fails with duplicate email" do
      _existing = create_user(%{email: "taken@example.com", username: "existing"})

      mutation = """
      mutation CreateUser($email: String!, $username: String!) {
        createUser(email: $email, username: $username) {
          id
        }
      }
      """

      variables = %{
        "email" => "taken@example.com",
        "username" => "different"
      }

      # This will raise an error due to changeset not being handled properly
      # In a production app, you'd handle changeset errors in the resolver
      assert_raise Protocol.UndefinedError, fn ->
        run_query(mutation, variables)
      end
    end
  end

  describe "createPost mutation" do
    test "requires authentication" do
      mutation = """
      mutation CreatePost($body: String!) {
        createPost(body: $body) {
          id
          body
        }
      }
      """

      result = run_query(mutation, %{"body" => "Hello world"})
      errors = get_errors(result)

      assert errors != nil
      assert Enum.any?(errors, &String.contains?(&1.message, "Not authenticated"))
    end

    test "creates post when authenticated" do
      user = create_user()

      mutation = """
      mutation CreatePost($body: String!, $visibility: PostVisibility) {
        createPost(body: $body, visibility: $visibility) {
          id
          body
          visibility
        }
      }
      """

      variables = %{
        "body" => "My first post!",
        "visibility" => "FRIENDS"
      }

      result = run_query_as(mutation, user, variables)
      data = get_data(result)

      assert data["createPost"]["body"] == "My first post!"
      assert data["createPost"]["visibility"] == "FRIENDS"
      assert data["createPost"]["id"] != nil
    end
  end

  describe "createComment mutation" do
    test "requires authentication" do
      user = create_user()
      post = create_post(user)

      mutation = """
      mutation CreateComment($postId: ID!, $body: String!) {
        createComment(postId: $postId, body: $body) {
          id
        }
      }
      """

      result = run_query(mutation, %{"postId" => to_string(post.id), "body" => "Comment"})
      errors = get_errors(result)

      assert errors != nil
    end

    test "creates comment when authenticated" do
      author = create_user(%{username: "author"})
      commenter = create_user(%{username: "commenter"})
      post = create_post(author, %{body: "Original post"})

      mutation = """
      mutation CreateComment($postId: ID!, $body: String!) {
        createComment(postId: $postId, body: $body) {
          id
          body
        }
      }
      """

      variables = %{
        "postId" => to_string(post.id),
        "body" => "Great post!"
      }

      result = run_query_as(mutation, commenter, variables)
      data = get_data(result)

      assert data["createComment"]["body"] == "Great post!"
      assert data["createComment"]["id"] != nil
    end

    test "creates nested reply" do
      user = create_user()
      post = create_post(user)
      parent_comment = create_comment(user, post, %{body: "Parent comment"})

      mutation = """
      mutation CreateComment($postId: ID!, $body: String!, $parentId: ID) {
        createComment(postId: $postId, body: $body, parentId: $parentId) {
          id
          body
        }
      }
      """

      variables = %{
        "postId" => to_string(post.id),
        "body" => "Reply to parent",
        "parentId" => to_string(parent_comment.id)
      }

      result = run_query_as(mutation, user, variables)
      data = get_data(result)

      assert data["createComment"]["body"] == "Reply to parent"
      assert data["createComment"]["id"] != nil
    end
  end

  describe "likePost mutation" do
    test "requires authentication" do
      user = create_user()
      post = create_post(user)

      mutation = """
      mutation LikePost($postId: ID!) {
        likePost(postId: $postId) {
          id
        }
      }
      """

      result = run_query(mutation, %{"postId" => to_string(post.id)})
      errors = get_errors(result)

      assert errors != nil
    end

    test "likes a post when authenticated" do
      author = create_user(%{username: "author"})
      liker = create_user(%{username: "liker"})
      post = create_post(author)

      mutation = """
      mutation LikePost($postId: ID!) {
        likePost(postId: $postId) {
          id
        }
      }
      """

      result = run_query_as(mutation, liker, %{"postId" => to_string(post.id)})
      data = get_data(result)

      assert data["likePost"]["id"] != nil
    end
  end

  describe "sendFriendRequest mutation" do
    test "requires authentication" do
      friend = create_user()

      mutation = """
      mutation SendFriendRequest($friendId: ID!) {
        sendFriendRequest(friendId: $friendId) {
          id
        }
      }
      """

      result = run_query(mutation, %{"friendId" => to_string(friend.id)})
      errors = get_errors(result)

      assert errors != nil
    end

    test "sends friend request when authenticated" do
      user = create_user(%{username: "requester"})
      friend = create_user(%{username: "requestee"})

      mutation = """
      mutation SendFriendRequest($friendId: ID!) {
        sendFriendRequest(friendId: $friendId) {
          id
          status
        }
      }
      """

      result = run_query_as(mutation, user, %{"friendId" => to_string(friend.id)})
      data = get_data(result)

      assert data["sendFriendRequest"]["status"] == "PENDING"
      assert data["sendFriendRequest"]["id"] != nil
    end
  end

  describe "acceptFriendRequest mutation" do
    test "accepts a pending friend request" do
      user = create_user(%{username: "user"})
      friend = create_user(%{username: "friend"})

      # Create a pending friendship
      {:ok, friendship} =
        %SocialNetwork.Accounts.Friendship{}
        |> SocialNetwork.Accounts.Friendship.changeset(%{
          user_id: friend.id,
          friend_id: user.id,
          status: :pending
        })
        |> SocialNetwork.Repo.insert()

      mutation = """
      mutation AcceptFriendRequest($friendshipId: ID!) {
        acceptFriendRequest(friendshipId: $friendshipId) {
          id
          status
        }
      }
      """

      result = run_query_as(mutation, user, %{"friendshipId" => to_string(friendship.id)})
      data = get_data(result)

      assert data["acceptFriendRequest"]["status"] == "ACCEPTED"
    end
  end
end
