# Unions

Unions allow a field to return one of several distinct types. Unlike interfaces,
union member types don't need to share any common fields.

## Basic Usage

```elixir
defmodule MyApp.GraphQL.Unions.SearchResult do
  use GreenFairy.Union

  union "SearchResult" do
    types [:user, :post, :comment, :organization]

    resolve_type fn
      %MyApp.User{}, _ -> :user
      %MyApp.Post{}, _ -> :post
      %MyApp.Comment{}, _ -> :comment
      %MyApp.Organization{}, _ -> :organization
      _, _ -> nil
    end
  end
end
```

This generates:

```graphql
union SearchResult = User | Post | Comment | Organization
```

## Type Resolution

The `resolve_type` callback determines which concrete type is being returned:

```elixir
union "SearchResult" do
  types [:user, :post, :comment]

  resolve_type fn value, _resolution ->
    case value do
      %MyApp.User{} -> :user
      %MyApp.Post{} -> :post
      %MyApp.Comment{} -> :comment
      _ -> nil
    end
  end
end
```

The function receives:
1. The resolved value
2. The Absinthe resolution info

### Using Struct Module

A cleaner pattern using the struct's module:

```elixir
union "SearchResult" do
  types [:user, :post, :comment]

  resolve_type fn
    %{__struct__: MyApp.User}, _ -> :user
    %{__struct__: MyApp.Post}, _ -> :post
    %{__struct__: MyApp.Comment}, _ -> :comment
    _, _ -> nil
  end
end
```

### Dynamic Resolution

For extensible systems:

```elixir
union "SearchResult" do
  types [:user, :post, :comment, :page, :file]

  resolve_type fn value, _ ->
    type_map = %{
      MyApp.User => :user,
      MyApp.Post => :post,
      MyApp.Comment => :comment,
      MyApp.Page => :page,
      MyApp.File => :file
    }

    Map.get(type_map, value.__struct__)
  end
end
```

## Querying Unions

Use inline fragments to access type-specific fields:

```graphql
query {
  search(query: "elixir") {
    ... on User {
      id
      name
      email
    }
    ... on Post {
      id
      title
      body
    }
    ... on Comment {
      id
      body
      author {
        name
      }
    }
  }
}
```

Or use named fragments:

```graphql
query {
  search(query: "elixir") {
    ...UserFields
    ...PostFields
    ...CommentFields
  }
}

fragment UserFields on User {
  id
  name
  email
}

fragment PostFields on Post {
  id
  title
  body
}

fragment CommentFields on Comment {
  id
  body
}
```

## Using `__typename`

Request the concrete type name:

```graphql
query {
  search(query: "elixir") {
    __typename
    ... on User {
      name
    }
    ... on Post {
      title
    }
  }
}
```

Response:

```json
{
  "data": {
    "search": [
      { "__typename": "User", "name": "John" },
      { "__typename": "Post", "title": "Learning Elixir" }
    ]
  }
}
```

## Common Patterns

### Activity Feed

```elixir
defmodule MyApp.GraphQL.Unions.FeedItem do
  use GreenFairy.Union

  union "FeedItem" do
    @desc "An item in the activity feed"

    types [:post, :comment, :like, :follow, :share]

    resolve_type fn
      %MyApp.Post{}, _ -> :post
      %MyApp.Comment{}, _ -> :comment
      %MyApp.Like{}, _ -> :like
      %MyApp.Follow{}, _ -> :follow
      %MyApp.Share{}, _ -> :share
      _, _ -> nil
    end
  end
end
```

Query:

```elixir
field :feed, list_of(:feed_item) do
  arg :limit, :integer, default_value: 20

  resolve fn _, args, ctx ->
    {:ok, MyApp.Feed.get_items(ctx[:current_user], args)}
  end
end
```

### Mutation Results

For mutations that can return different result types:

```elixir
defmodule MyApp.GraphQL.Unions.AuthResult do
  use GreenFairy.Union

  union "AuthResult" do
    types [:auth_success, :auth_error, :mfa_required]

    resolve_type fn
      %{token: _}, _ -> :auth_success
      %{error: _}, _ -> :auth_error
      %{mfa_token: _}, _ -> :mfa_required
      _, _ -> nil
    end
  end
end
```

Usage:

```elixir
field :login, :auth_result do
  arg :email, non_null(:string)
  arg :password, non_null(:string)

  resolve fn _, args, _ ->
    case MyApp.Auth.login(args) do
      {:ok, session} -> {:ok, %{token: session.token, user: session.user}}
      {:mfa_required, token} -> {:ok, %{mfa_token: token}}
      {:error, reason} -> {:ok, %{error: reason}}
    end
  end
end
```

Query:

```graphql
mutation {
  login(email: "user@example.com", password: "secret") {
    ... on AuthSuccess {
      token
      user {
        id
        name
      }
    }
    ... on AuthError {
      error
    }
    ... on MfaRequired {
      mfaToken
    }
  }
}
```

### Media Types

```elixir
defmodule MyApp.GraphQL.Unions.Media do
  use GreenFairy.Union

  union "Media" do
    types [:image, :video, :audio, :document]

    resolve_type fn
      %{mime_type: "image/" <> _}, _ -> :image
      %{mime_type: "video/" <> _}, _ -> :video
      %{mime_type: "audio/" <> _}, _ -> :audio
      _, _ -> :document
    end
  end
end
```

### Notification Payload

```elixir
defmodule MyApp.GraphQL.Unions.NotificationPayload do
  use GreenFairy.Union

  union "NotificationPayload" do
    types [:user, :post, :comment, :order, :message]

    resolve_type fn value, _ ->
      # Pattern match on struct module
      case value.__struct__ do
        MyApp.User -> :user
        MyApp.Post -> :post
        MyApp.Comment -> :comment
        MyApp.Order -> :order
        MyApp.Message -> :message
        _ -> nil
      end
    end
  end
end
```

## Unions vs Interfaces

| Feature | Unions | Interfaces |
|---------|--------|------------|
| Shared fields | No | Yes (required) |
| Type resolution | Required | Required |
| Member types | Explicit list | Types opt-in via `implements` |
| Best for | Unrelated types | Related types with common fields |

### When to Use Unions

- Search results returning different entity types
- Activity feeds with varied item types
- Mutation results with different outcomes
- Media attachments of different kinds

### When to Use Interfaces

- Entities sharing common fields (id, timestamps)
- Node interface for Relay
- Polymorphic relationships where common fields are queried

## Module Functions

Every union module exports:

| Function | Description |
|----------|-------------|
| `__green_fairy_kind__/0` | Returns `:union` |
| `__green_fairy_identifier__/0` | Returns the type identifier |
| `__green_fairy_definition__/0` | Returns the full definition map |

## Naming Conventions

| GraphQL Name | Elixir Identifier | Module Suggestion |
|--------------|-------------------|-------------------|
| `SearchResult` | `:search_result` | `MyApp.GraphQL.Unions.SearchResult` |
| `FeedItem` | `:feed_item` | `MyApp.GraphQL.Unions.FeedItem` |
| `MediaType` | `:media_type` | `MyApp.GraphQL.Unions.MediaType` |

## Next Steps

- [Interfaces](interfaces.html) - Alternative for types with shared fields
- [Object Types](object-types.html) - Defining union member types
- [Operations](operations.html) - Using unions in queries and mutations
