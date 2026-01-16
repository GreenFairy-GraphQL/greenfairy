# CQL (Connection Query Language) - Getting Started

CQL is GreenFairy's powerful filtering and ordering system for GraphQL queries, inspired by Hasura's query language.

## What is CQL?

CQL automatically generates GraphQL filter and order inputs for your Ecto schemas, enabling rich querying without writing custom resolvers:

```graphql
query {
  users(
    filter: {
      age: { _gte: 18 }
      name: { _ilike: "%john%" }
      _or: [
        { email: { _contains: "@gmail.com" } }
        { email: { _contains: "@example.com" } }
      ]
    }
    order: { created_at: DESC }
    limit: 50
    offset: 10
  ) {
    id
    name
    email
  }
}
```

## Basic Usage

### 1. Enable CQL in Your Schema

```elixir
defmodule MyApp.GraphQL.Schema do
  use Absinthe.Schema
  use GreenFairy.Schema,
    repo: MyApp.Repo  # ← CQL automatically enabled
end
```

### 2. Define a Type with CQL

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  type "User", struct: MyApp.Accounts.User do
    field :id, non_null(:id)
    field :email, non_null(:string)
    field :name, :string
    field :age, :integer
    field :active, :boolean
    field :inserted_at, :datetime
  end
end
```

That's it! CQL filter and order inputs are automatically generated.

### 3. Add Query Field

```elixir
defmodule MyApp.GraphQL.Queries do
  use GreenFairy.Query

  query do
    field :users, list_of(:user) do
      # These are automatically added:
      # arg :filter, :cql_filter_user_input
      # arg :order, :cql_order_user_input
      # arg :limit, :integer
      # arg :offset, :integer

      resolve fn args, _info ->
        # CQL automatically applied
        {:ok, MyApp.Accounts.list_users(args)}
      end
    end
  end
end
```

## Common Operators

### Comparison Operators

```graphql
# Equality
filter: { name: { _eq: "John" } }

# Not equal
filter: { name: { _neq: "Admin" } }

# Greater than / Less than
filter: { age: { _gte: 18, _lt: 65 } }

# In list
filter: { status: { _in: ["active", "pending"] } }

# Not in list
filter: { status: { _nin: ["deleted", "banned"] } }
```

### String Operators

```graphql
# Contains (case-sensitive)
filter: { bio: { _contains: "GraphQL" } }

# Case-insensitive like
filter: { email: { _ilike: "%@example.com" } }

# Starts with
filter: { name: { _starts_with: "J" } }

# Ends with
filter: { email: { _ends_with: "@gmail.com" } }
```

### Boolean Operators

```graphql
# AND (implicit)
filter: {
  active: { _eq: true }
  age: { _gte: 18 }
}

# OR
filter: {
  _or: [
    { status: { _eq: "premium" } }
    { trial_active: { _eq: true } }
  ]
}

# NOT
filter: {
  _not: {
    status: { _eq: "banned" }
  }
}
```

### Null Checks

```graphql
# Is null
filter: { deleted_at: { _is_null: true } }

# Is not null
filter: { confirmed_at: { _is_null: false } }
```

### Array Operators

For array/list fields:

```graphql
# Array contains all
filter: { tags: { _includes_all: ["premium", "verified"] } }

# Array contains any
filter: { tags: { _includes_any: ["admin", "moderator"] } }

# Array is empty
filter: { tags: { _is_empty: true } }

# Array length
filter: { tags: { _array_length: { _gte: 3 } } }
```

## Ordering

```graphql
# Single field ascending
order: { name: ASC }

# Single field descending
order: { created_at: DESC }

# Multiple fields (order matters!)
order: [
  { status: ASC }
  { created_at: DESC }
]
```

## Pagination

```graphql
# Limit results
query {
  users(limit: 50) {
    id
    name
  }
}

# Offset pagination
query {
  users(limit: 50, offset: 100) {
    id
    name
  }
}
```

## Complex Queries

### Combining Multiple Conditions

```graphql
query {
  users(
    filter: {
      # Must be active
      active: { _eq: true }

      # Age between 18 and 65
      age: { _gte: 18, _lte: 65 }

      # Email from specific domains
      _or: [
        { email: { _ends_with: "@company.com" } }
        { email: { _ends_with: "@partner.com" } }
      ]

      # Not deleted
      _not: {
        status: { _eq: "deleted" }
      }
    }
    order: [
      { premium: DESC }
      { created_at: DESC }
    ]
    limit: 100
  ) {
    id
    name
    email
    status
  }
}
```

### Nested Boolean Logic

```graphql
query {
  posts(
    filter: {
      _or: [
        # Published posts
        {
          published: { _eq: true }
          published_at: { _lte: "2024-01-01" }
        }
        # Draft posts by current user
        {
          status: { _eq: "draft" }
          author_id: { _eq: 123 }
        }
      ]
    }
  ) {
    id
    title
  }
}
```

## Database Compatibility

CQL works across multiple databases with automatic operator filtering:

| Database      | Full Support | Array Ops | Advanced Ops |
|---------------|--------------|-----------|--------------|
| PostgreSQL    | ✅           | ✅        | ✅           |
| MySQL         | ✅           | ⚠️        | ⚠️           |
| SQLite        | ✅           | ⚠️        | ❌           |
| MSSQL         | ✅           | ⚠️        | ❌           |
| Elasticsearch | ✅           | ✅        | ✅           |

✅ Native support | ⚠️ Emulated (slower) | ❌ Not available

The GraphQL schema automatically exposes only operators supported by your database.

## Best Practices

### 1. Always Use LIMIT

```graphql
# Bad - could return millions of rows
query {
  users {
    id
  }
}

# Good - bounded result set
query {
  users(limit: 100) {
    id
  }
}
```

### 2. Index Filtered Fields

```sql
-- Add indexes for commonly filtered fields
CREATE INDEX users_active_idx ON users(active);
CREATE INDEX users_email_idx ON users(email);
CREATE INDEX users_created_at_idx ON users(created_at DESC);
```

### 3. Use Specific Operators

```graphql
# Bad - _ilike is slower (full table scan)
filter: { email: { _ilike: "%@%" } }

# Good - _ends_with can use index
filter: { email: { _ends_with: "@example.com" } }
```

### 4. Combine Filters Efficiently

```graphql
# Bad - OR with many conditions
filter: {
  _or: [
    { status: { _eq: "pending" } }
    { status: { _eq: "active" } }
    { status: { _eq: "trial" } }
  ]
}

# Good - Use _in
filter: {
  status: { _in: ["pending", "active", "trial"] }
}
```

## Next Steps

- **[CQL Adapter System](cql_adapter_system.md)** - Multi-database support details
- **[CQL Advanced Features](cql_advanced_features.md)** - Database-specific operators
- **[CQL Query Complexity](cql_query_complexity.md)** - Automatic query protection

## Example Application

Check out `examples/social_network` for a complete application using CQL with:
- User filtering and search
- Post queries with author filtering
- Comment threading
- Pagination
- Real-time subscriptions
