# Enums

Enums define a set of allowed values for a field. GreenFairy provides a clean DSL
for defining GraphQL enums with support for Ecto mapping and automatic CQL filter generation.

## Basic Usage

```elixir
defmodule MyApp.GraphQL.Enums.UserRole do
  use GreenFairy.Enum

  enum "UserRole" do
    value :admin
    value :moderator
    value :member
    value :guest
  end
end
```

This generates a GraphQL enum:

```graphql
enum UserRole {
  ADMIN
  MODERATOR
  MEMBER
  GUEST
}
```

## Custom GraphQL Names

Use the `:as` option to customize the GraphQL value name:

```elixir
enum "UserRole" do
  value :admin
  value :member
  value :guest, as: "GUEST_USER"  # GraphQL: GUEST_USER, Elixir: :guest
end
```

## Descriptions

Add descriptions to enums and their values for better documentation:

```elixir
defmodule MyApp.GraphQL.Enums.OrderStatus do
  use GreenFairy.Enum

  enum "OrderStatus", description: "Status of an order in the system" do
    value :pending, description: "Order placed but not yet processed"
    value :processing, description: "Order is being prepared"
    value :shipped, description: "Order has been shipped"
    value :delivered, description: "Order delivered to customer"
    value :cancelled, description: "Order was cancelled"
  end
end
```

## Ecto Enum Mapping

When your GraphQL enum values differ from your database/Ecto values, use `enum_mapping`:

```elixir
defmodule MyApp.GraphQL.Enums.PostVisibility do
  use GreenFairy.Enum

  enum "PostVisibility" do
    value :public
    value :friends_only
    value :private
  end

  # Map GraphQL values to Ecto/database values
  enum_mapping %{
    public: :public,
    friends_only: :friends,  # GraphQL: FRIENDS_ONLY, DB: :friends
    private: :private
  }
end
```

This automatically generates `serialize/1` and `parse/1` functions:

```elixir
# Generated functions
PostVisibility.serialize(:friends_only)  # => :friends
PostVisibility.parse(:friends)           # => :friends_only
```

## Custom Serialize/Parse

For complex transformations (e.g., storing enums as integers in the database):

```elixir
defmodule MyApp.GraphQL.Enums.Priority do
  use GreenFairy.Enum

  enum "Priority" do
    value :low
    value :medium
    value :high
    value :critical
  end

  # Override serialize/parse for custom storage format
  def serialize(:low), do: 1
  def serialize(:medium), do: 5
  def serialize(:high), do: 10
  def serialize(:critical), do: 100

  def parse(1), do: :low
  def parse(5), do: :medium
  def parse(10), do: :high
  def parse(100), do: :critical
  def parse(_), do: nil
end
```

## Automatic CQL Filter Generation

When you use a GreenFairy enum in a CQL-enabled type's field, type-specific filter
inputs are **automatically generated** - no configuration needed.

### Example

```elixir
# Define the enum
defmodule MyApp.GraphQL.Enums.OrderStatus do
  use GreenFairy.Enum

  enum "OrderStatus" do
    value :pending
    value :shipped
    value :delivered
  end
end

# Use it in a type
defmodule MyApp.GraphQL.Types.Order do
  use GreenFairy.Type

  type "Order", struct: MyApp.Order do
    field :id, non_null(:id)
    field :status, :order_status  # Uses the enum
    field :tags, list_of(:order_tag)  # Array of enums also supported
  end
end
```

### Generated Types

GreenFairy automatically generates:

**`CqlEnumOrderStatusInput`** - Scalar enum operators:
```graphql
input CqlEnumOrderStatusInput {
  _eq: OrderStatus
  _neq: OrderStatus
  _in: [OrderStatus!]
  _nin: [OrderStatus!]
  _is_null: Boolean
}
```

**`CqlEnumOrderStatusArrayInput`** - Array enum operators:
```graphql
input CqlEnumOrderStatusArrayInput {
  _includes: OrderStatus
  _excludes: OrderStatus
  _includes_all: [OrderStatus!]
  _excludes_all: [OrderStatus!]
  _includes_any: [OrderStatus!]
  _excludes_any: [OrderStatus!]
  _is_empty: Boolean
  _is_null: Boolean
}
```

### Type-Safe Filtering

The filter input references the type-specific enum input:

```graphql
input CqlFilterOrderInput {
  _and: [CqlFilterOrderInput]
  _or: [CqlFilterOrderInput]
  _not: CqlFilterOrderInput
  id: CqlOpIdInput
  status: CqlEnumOrderStatusInput  # Type-specific!
}
```

Query with type-safe enum filtering:

```graphql
query {
  orders(filter: {
    status: { _in: [PENDING, SHIPPED] }
  }) {
    id
    status
  }
}

# Multiple conditions
query {
  orders(filter: {
    _and: [
      { status: { _neq: CANCELLED } },
      { status: { _neq: DELIVERED } }
    ]
  }) {
    id
    status
  }
}
```

This provides full type safety - the GraphQL schema validates that only valid enum
values are used in filters, catching errors at query validation time rather than runtime.

## Using Enums in Fields

Reference enums by their identifier (snake_case version of the name):

```elixir
# In a type
type "User", struct: MyApp.User do
  field :role, :user_role
  field :status, non_null(:account_status)
  field :preferences, list_of(:notification_preference)
end

# In an input
input "CreateUserInput" do
  field :role, :user_role, default_value: :member
  field :notification_preferences, list_of(:notification_preference)
end

# In a mutation
mutations do
  field :update_role, :user do
    arg :user_id, non_null(:id)
    arg :role, non_null(:user_role)

    resolve &Resolvers.update_role/3
  end
end
```

## Module Functions

Every enum module exports these functions:

| Function | Description |
|----------|-------------|
| `__green_fairy_kind__/0` | Returns `:enum` |
| `__green_fairy_identifier__/0` | Returns the type identifier (e.g., `:user_role`) |
| `__green_fairy_definition__/0` | Returns the full definition map |
| `serialize/1` | Converts GraphQL value to database value |
| `parse/1` | Converts database value to GraphQL value |

## Naming Conventions

| GraphQL Name | Elixir Identifier | Module Suggestion |
|--------------|-------------------|-------------------|
| `UserRole` | `:user_role` | `MyApp.GraphQL.Enums.UserRole` |
| `OrderStatus` | `:order_status` | `MyApp.GraphQL.Enums.OrderStatus` |
| `NotificationType` | `:notification_type` | `MyApp.GraphQL.Enums.NotificationType` |

## Next Steps

- [Object Types](object-types.html) - Define GraphQL object types
- [Input Types](input-types.html) - Complex mutation arguments
- [CQL Filtering](cql.html) - Advanced filtering with CQL
