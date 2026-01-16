# Social Network Example

A comprehensive example demonstrating GreenFairy's GraphQL DSL with a social networking domain.

## Features

- **Users** with profiles, friendships, posts, comments, and likes
- **Posts** with visibility controls (public, friends, private)
- **Comments** with nested replies
- **Likes** on posts and comments
- **Friendships** with status (pending, accepted, blocked)

## GraphQL Types

This example demonstrates:

- **Types**: User, Post, Comment, Like, Friendship
- **Enums**: FriendshipStatus, PostVisibility
- **Interfaces**: Node (for Relay global IDs)
- **DataLoader**: Batch loading for associations

## Setup

### Backend

```bash
# Install dependencies
mix deps.get

# Create and migrate database
mix ecto.create
mix ecto.migrate

# Start the server
mix run --no-halt

# The GraphQL endpoint will be available at http://localhost:4000/api/graphql
# GraphiQL playground at http://localhost:4000/graphiql
```

### Frontend (React + Relay)

```bash
cd frontend

# Install dependencies
npm install

# Generate Relay artifacts
npm run relay

# Start development server
npm run dev

# The frontend will be available at http://localhost:3000
```

### Running Tests

```bash
# Run backend tests
mix test

# Tests cover:
# - GraphQL queries (users, posts, viewer)
# - GraphQL mutations (createUser, createPost, etc.)
# - Schema introspection
# - Relationship queries
```

## Project Structure

```
lib/
  social_network/
    accounts/
      user.ex           # User Ecto schema
      friendship.ex     # Friendship Ecto schema
    content/
      post.ex           # Post Ecto schema
      comment.ex        # Comment Ecto schema
      like.ex           # Like Ecto schema
    repo.ex             # Ecto repo
    router.ex           # Plug router with GraphQL endpoints
    application.ex      # OTP application
  social_network_web/
    graphql/
      schema.ex         # GraphQL schema
      data_loader.ex    # DataLoader configuration
      interfaces/
        node.ex         # Node interface
      enums/
        friendship_status.ex
        post_visibility.ex
      types/
        user.ex
        post.ex
        comment.ex
        like.ex
        friendship.ex
test/
  support/
    data_case.ex        # Database test helpers
    graphql_case.ex     # GraphQL test helpers
  social_network_web/
    graphql/
      queries_test.exs  # Query tests
      mutations_test.exs # Mutation tests
      schema_test.exs   # Schema introspection tests
frontend/
  src/
    components/         # React components
    relay/              # Relay environment
    __generated__/      # Relay compiler output
  schema.graphql        # GraphQL schema for Relay
```

## GraphQL API

### Queries

```graphql
query {
  # Get current user
  viewer {
    id
    username
    posts {
      body
      comments {
        body
        author { username }
      }
    }
  }

  # Get user by ID
  user(id: "1") {
    username
    displayName
    friends { username }
  }

  # Get all public posts
  posts(visibility: PUBLIC) {
    body
    author { username }
    likes { user { username } }
  }
}
```

### Mutations

```graphql
mutation {
  # Create a new user
  createUser(email: "alice@example.com", username: "alice") {
    id
    username
  }

  # Create a post
  createPost(body: "Hello, world!", visibility: PUBLIC) {
    id
    body
  }

  # Comment on a post
  createComment(postId: "1", body: "Great post!") {
    id
    body
    author { username }
  }

  # Like a post
  likePost(postId: "1") {
    id
  }

  # Send friend request
  sendFriendRequest(friendId: "2") {
    id
    status
  }
}
```

## Type Definitions

Each GraphQL type is defined in its own module using the clean DSL:

```elixir
defmodule SocialNetworkWeb.GraphQL.Types.User do
  use GreenFairy.Type

  alias SocialNetworkWeb.GraphQL.Interfaces

  type "User", struct: SocialNetwork.Accounts.User do
    implements Interfaces.Node

    field :id, non_null(:id)
    field :email, non_null(:string)
    field :username, non_null(:string)
    field :display_name, :string
    field :bio, :string

    field :posts, list_of(:post)
    field :friends, list_of(:user)
  end
end
```

## License

MIT
