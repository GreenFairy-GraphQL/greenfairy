# Associations and Custom Loaders

## Table of Contents

1. [Simple Associations](#simple-associations) - Use `assoc` macro
2. [Custom Loaders](#custom-loaders) - Use inline `loader` syntax
3. [Cross-Adapter Loading](#cross-adapter-loading) - Manual loaders for different data sources
4. [Pagination](#pagination) - Configuring limits and validation

---

## Simple Associations

For standard Ecto associations, use the `assoc` macro which automatically:
- Infers association type (belongs_to, has_one, has_many, many_to_many)
- Sets up DataLoader for efficient batching
- Adds pagination (limit/offset) for has_many associations
- Validates pagination arguments

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  type "User", struct: MyApp.Accounts.User do
    field :id, non_null(:id)
    field :email, non_null(:string)
    field :username, non_null(:string)

    # Single associations - automatic DataLoader
    assoc :organization  # belongs_to → Organization

    # List associations - automatic DataLoader + pagination
    assoc :posts         # has_many → [Post] with limit/offset args
    assoc :comments      # has_many → [Comment] with limit/offset args
    assoc :likes         # has_many → [Like] with limit/offset args
  end
end
```

### Generated GraphQL Schema

```graphql
type User {
  id: ID!
  email: String!
  username: String!

  # Single association - no pagination
  organization: Organization

  # List associations - with pagination
  posts(limit: Int = 20, offset: Int = 0): [Post!]
  comments(limit: Int = 20, offset: Int = 0): [Comment!]
  likes(limit: Int = 20, offset: Int = 0): [Like!]
}
```

---

## Custom Loaders

For complex associations or custom logic, use the inline `loader` syntax:

### Has-Through Associations

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  type "User", struct: MyApp.Accounts.User do
    field :id, non_null(:id)

    # has_through association requires custom loader
    field :friends, list_of(:user) do
      loader users, _args, _context do
        import Ecto.Query

        user_ids = Enum.map(users, & &1.id)

        # Query all friendships for these users
        friendships =
          MyApp.Accounts.Friendship
          |> where([f], f.user_id in ^user_ids or f.friend_id in ^user_ids)
          |> where([f], f.status == :accepted)
          |> MyApp.Repo.all()
          |> MyApp.Repo.preload([:user, :friend])

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
  end
end
```

### Computed Aggregations

```elixir
field :total_posts_count, :integer do
  loader users, _args, _context do
    import Ecto.Query

    user_ids = Enum.map(users, & &1.id)

    counts =
      MyApp.Content.Post
      |> where([p], p.author_id in ^user_ids)
      |> group_by([p], p.author_id)
      |> select([p], {p.author_id, count(p.id)})
      |> MyApp.Repo.all()
      |> Map.new()

    # Return map of user => count
    Map.new(users, fn user ->
      {user, Map.get(counts, user.id, 0)}
    end)
  end
end
```

### Filtered Relationships

```elixir
field :recent_posts, list_of(:post) do
  arg :days, :integer, default_value: 7

  loader users, args, _context do
    import Ecto.Query

    user_ids = Enum.map(users, & &1.id)
    cutoff_date = DateTime.utc_now() |> DateTime.add(-args.days, :day)

    posts =
      MyApp.Content.Post
      |> where([p], p.author_id in ^user_ids)
      |> where([p], p.inserted_at >= ^cutoff_date)
      |> order_by([p], desc: p.inserted_at)
      |> MyApp.Repo.all()

    # Group posts by author
    posts
    |> Enum.group_by(& &1.author_id)
    |> then(fn grouped ->
      Map.new(users, fn user ->
        {user, Map.get(grouped, user.id, [])}
      end)
    end)
  end
end
```

---

## Cross-Adapter Loading

Use inline loaders for loading data from non-Ecto sources:

### Elasticsearch Integration

```elixir
defmodule MyApp.GraphQL.Types.Product do
  use GreenFairy.Type

  type "Product", struct: MyApp.Catalog.Product do
    field :id, non_null(:id)
    field :name, non_null(:string)

    # Load related products from Elasticsearch
    field :similar_products, list_of(:product) do
      arg :limit, :integer, default_value: 10

      loader products, args, _context do
        product_ids = Enum.map(products, & &1.id)

        # Batch query to Elasticsearch
        search_results =
          MyApp.Search.batch_more_like_this(
            product_ids,
            size: args.limit
          )

        # Return map of product => similar products
        Map.new(products, fn product ->
          similar_ids = Map.get(search_results, product.id, [])

          similar_products =
            MyApp.Catalog.Product
            |> where([p], p.id in ^similar_ids)
            |> MyApp.Repo.all()

          {product, similar_products}
        end)
      end
    end
  end
end
```

### External API Integration

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  type "User", struct: MyApp.Accounts.User do
    field :id, non_null(:id)

    # Load payment methods from Stripe
    field :payment_methods, list_of(:payment_method) do
      loader users, _args, _context do
        # Batch load from Stripe API
        stripe_customer_ids = Enum.map(users, & &1.stripe_customer_id)

        payment_methods =
          stripe_customer_ids
          |> Enum.chunk_every(10)  # Stripe API limits
          |> Task.async_stream(fn batch ->
            Enum.flat_map(batch, fn customer_id ->
              {:ok, methods} = Stripe.PaymentMethod.list(%{customer: customer_id})
              Enum.map(methods.data, &{customer_id, &1})
            end)
          end)
          |> Enum.flat_map(fn {:ok, results} -> results end)
          |> Enum.group_by(fn {customer_id, _method} -> customer_id end, fn {_id, method} -> method end)

        # Map back to users
        Map.new(users, fn user ->
          {user, Map.get(payment_methods, user.stripe_customer_id, [])}
        end)
      end
    end
  end
end
```

### Redis Cache Integration

```elixir
field :view_count, :integer do
  loader posts, _args, _context do
    post_ids = Enum.map(posts, & &1.id)

    # Batch fetch from Redis using pipeline
    counts =
      Redix.pipeline!(MyApp.Redis, [
        Enum.map(post_ids, &["GET", "post:#{&1}:views"])
      ])
      |> List.flatten()
      |> Enum.zip(post_ids)
      |> Map.new(fn {count_str, post_id} ->
        {post_id, String.to_integer(count_str || "0")}
      end)

    # Return map of post => count
    Map.new(posts, fn post ->
      {post, Map.get(counts, post.id, 0)}
    end)
  end
end
```

---

## Pagination

### Configuration

Set global defaults and limits in your config:

```elixir
# config/config.exs
config :green_fairy, :pagination,
  default_limit: 20,      # Default items per request
  max_limit: 100,         # Maximum allowed limit
  max_offset: 10_000      # Maximum allowed offset
```

### Per-Field Override

```elixir
# Override defaults for specific fields
assoc :posts, default_limit: 50, max_limit: 200
```

### Validation

The pagination middleware automatically validates:
- `limit > 0`
- `limit <= max_limit`
- `offset >= 0`
- `offset <= max_offset`

Errors are returned to the client:

```graphql
query {
  user(id: "1") {
    posts(limit: 1000) {  # Exceeds max_limit
      id
    }
  }
}

# Response:
{
  "errors": [
    {
      "message": "limit cannot exceed 100",
      "path": ["user", "posts"]
    }
  ]
}
```

---

## Return Value Formats

Loaders can return results in two formats:

### 1. Map Format (Recommended)

Return a map of `parent => result`:

```elixir
loader users, args, _context do
  Map.new(users, fn user ->
    {user, load_data_for(user)}
  end)
end
```

### 2. List Format

Return a list in the same order as parents:

```elixir
loader users, args, _context do
  Enum.map(users, fn user ->
    load_data_for(user)
  end)
end
```

---

## Best Practices

### 1. Use `assoc` for Simple Cases

```elixir
# ✅ Good - simple and automatic
assoc :posts

# ❌ Avoid - unnecessary complexity
field :posts, list_of(:post) do
  loader users, _args, _context do
    # Manual DataLoader implementation...
  end
end
```

### 2. Use Inline Loaders for Complex Logic

```elixir
# ✅ Good - clear and inline
field :friends, list_of(:user) do
  loader users, args, context do
    # Complex has_through logic
  end
end

# ❌ Avoid - harder to read
field :friends, list_of(:user) do
  loader fn users, args, context ->
    # Same logic but less clear
  end
end
```

### 3. Batch External API Calls

```elixir
# ✅ Good - batches API calls
loader items, _args, _context do
  item_ids = Enum.map(items, & &1.id)
  results = MyExternalAPI.batch_fetch(item_ids)  # Single API call
  # Map results back to items
end

# ❌ Avoid - N+1 API calls
resolve fn item, _args, _context ->
  {:ok, MyExternalAPI.fetch(item.id)}  # Called once per item!
end
```

### 4. Handle Missing Data Gracefully

```elixir
loader users, _args, _context do
  Map.new(users, fn user ->
    # Always provide a default value
    {user, Map.get(cached_data, user.id, default_value())}
  end)
end
```

---

## Summary

| Use Case | Pattern | Example |
|----------|---------|---------|
| Simple Ecto associations | `assoc :field_name` | `assoc :posts` |
| Has-through associations | Inline `loader` | See [Has-Through](#has-through-associations) |
| Elasticsearch queries | Inline `loader` | See [Elasticsearch](#elasticsearch-integration) |
| External APIs | Inline `loader` | See [External API](#external-api-integration) |
| Redis cache | Inline `loader` | See [Redis](#redis-cache-integration) |
| Computed aggregations | Inline `loader` | See [Aggregations](#computed-aggregations) |
