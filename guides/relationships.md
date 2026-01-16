# Relationships and DataLoader

This guide covers how to define relationships between types and use DataLoader for efficient batching.

## Unified Field API

GreenFairy uses a single `field` macro for all fields, including associations. Resolution is determined by:

- **`resolve`** - Single-item resolver (receives one parent)
- **`loader`** - Batch loader (receives list of parents)
- **Default** - Adapter provides default resolution (Map.get for scalars, DataLoader for associations)

A field cannot have both `resolve` and `loader` - they are mutually exclusive.

## Association Fields

For associations, simply define fields with the appropriate type:

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  type "User", struct: MyApp.User do
    field :id, non_null(:id)
    field :name, :string

    # One-to-many: user has many posts
    field :posts, list_of(:post)

    # One-to-one: user has one profile
    field :profile, :profile

    # Many-to-one: user belongs to organization
    field :organization, :organization
  end
end
```

The adapter automatically determines how to load these fields based on the backing struct's associations.

## Explicit Loaders

When you need custom batch loading logic, use the `loader` macro:

```elixir
type "User", struct: MyApp.User do
  field :id, non_null(:id)

  # Loader receives list of parent objects and returns results
  field :recent_activity, list_of(:activity) do
    loader fn users, _args, ctx ->
      user_ids = Enum.map(users, & &1.id)
      activities = MyApp.Activity.recent_for_users(user_ids)

      # Return a map of parent -> result
      Enum.group_by(activities, & &1.user_id)
      |> Map.new(fn {user_id, acts} ->
        user = Enum.find(users, & &1.id == user_id)
        {user, acts}
      end)
    end
  end
end
```

## Resolvers vs Loaders

Use `resolve` when you need per-item resolution:

```elixir
field :display_name, :string do
  resolve fn user, _, _ ->
    {:ok, user.name || user.email}
  end
end
```

Use `loader` when you can batch load multiple items efficiently:

```elixir
field :friends_count, :integer do
  loader fn users, _args, _ctx ->
    user_ids = Enum.map(users, & &1.id)
    counts = MyApp.Friendship.count_by_user_ids(user_ids)

    Map.new(users, fn user ->
      {user, Map.get(counts, user.id, 0)}
    end)
  end
end
```

## DataLoader Setup

To enable automatic association loading, configure DataLoader in your schema:

### 1. Create a DataLoader Source

```elixir
defmodule MyApp.DataLoader do
  def data do
    Dataloader.Ecto.new(MyApp.Repo, query: &query/2)
  end

  def query(queryable, _params) do
    queryable
  end
end
```

### 2. Configure Your Schema

```elixir
defmodule MyApp.GraphQL.Schema do
  use Absinthe.Schema

  # ... import_types ...

  def context(ctx) do
    loader =
      Dataloader.new()
      |> Dataloader.add_source(:repo, MyApp.DataLoader.data())

    Map.put(ctx, :loader, loader)
  end

  def plugins do
    [Absinthe.Middleware.Dataloader | Absinthe.Plugin.defaults()]
  end
end
```

## Loader with Arguments

Loaders can access arguments for filtering:

```elixir
field :posts, list_of(:post) do
  arg :status, :post_status

  loader fn users, args, ctx ->
    user_ids = Enum.map(users, & &1.id)
    status = args[:status]

    posts = MyApp.Posts.list_for_users(user_ids, status: status)

    Enum.group_by(posts, & &1.author_id)
    |> Map.new(fn {user_id, user_posts} ->
      user = Enum.find(users, & &1.id == user_id)
      {user, user_posts}
    end)
  end
end
```

## N+1 Query Prevention

DataLoader and custom loaders automatically batch queries. For example, if you query:

```graphql
{
  users {
    id
    posts {
      title
    }
  }
}
```

DataLoader will:
1. Load all users in one query
2. Batch all post queries into a single query using `WHERE user_id IN (...)`

This prevents the N+1 query problem common in GraphQL APIs.

## Selection-Aware Loading

The Ecto adapter can be configured to select only the fields being queried:

```elixir
# Only loads the fields actually requested in the GraphQL query
field :organization, :organization
```

When a query only requests `{ organization { name } }`, the loader will only SELECT the `name` column (plus required columns like `id`).

## Next Steps

- [Connections](connections.html) - Relay-style pagination
- [CQL](cql.html) - Add filtering to association queries
- [Authorization](authorization.html) - Control access to related data
