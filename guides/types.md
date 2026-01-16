# Types Overview

GreenFairy provides a clean DSL for defining all GraphQL type kinds. Each type kind
has its own module and follows the "one module = one type" principle.

## Type Kinds

| Kind | Module | Description | Guide |
|------|--------|-------------|-------|
| Object Types | `GreenFairy.Type` | Entities with fields | [Object Types](object-types.html) |
| Interfaces | `GreenFairy.Interface` | Shared field contracts | [Interfaces](interfaces.html) |
| Input Types | `GreenFairy.Input` | Complex mutation arguments | [Input Types](input-types.html) |
| Enums | `GreenFairy.Enum` | Fixed value sets | [Enums](enums.html) |
| Unions | `GreenFairy.Union` | Return one of several types | [Unions](unions.html) |
| Scalars | `GreenFairy.Scalar` | Custom leaf values | [Scalars](scalars.html) |

## Quick Examples

### Object Type

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  type "User", struct: MyApp.User do
    field :id, non_null(:id)
    field :email, non_null(:string)
    field :name, :string
  end
end
```

### Interface

```elixir
defmodule MyApp.GraphQL.Interfaces.Node do
  use GreenFairy.Interface

  interface "Node" do
    field :id, non_null(:id)

    resolve_type fn
      %MyApp.User{}, _ -> :user
      %MyApp.Post{}, _ -> :post
      _, _ -> nil
    end
  end
end
```

### Input Type

```elixir
defmodule MyApp.GraphQL.Inputs.CreateUserInput do
  use GreenFairy.Input

  input "CreateUserInput" do
    field :email, non_null(:string)
    field :name, :string
  end
end
```

### Enum

```elixir
defmodule MyApp.GraphQL.Enums.UserRole do
  use GreenFairy.Enum

  enum "UserRole" do
    value :admin
    value :member
    value :guest
  end
end
```

### Union

```elixir
defmodule MyApp.GraphQL.Unions.SearchResult do
  use GreenFairy.Union

  union "SearchResult" do
    types [:user, :post, :comment]

    resolve_type fn
      %MyApp.User{}, _ -> :user
      %MyApp.Post{}, _ -> :post
      %MyApp.Comment{}, _ -> :comment
      _, _ -> nil
    end
  end
end
```

### Scalar

```elixir
defmodule MyApp.GraphQL.Scalars.Email do
  use GreenFairy.Scalar

  scalar "Email" do
    parse fn
      %Absinthe.Blueprint.Input.String{value: value}, _ ->
        if valid_email?(value), do: {:ok, value}, else: :error
      _, _ -> :error
    end

    serialize fn email -> email end
  end
end
```

## Directory Structure

GreenFairy encourages organizing types by kind:

```
lib/my_app/graphql/
├── schema.ex           # Main schema
├── types/              # Object types
│   ├── user.ex
│   └── post.ex
├── interfaces/         # Interfaces
│   └── node.ex
├── inputs/             # Input types
│   ├── create_user_input.ex
│   └── update_user_input.ex
├── enums/              # Enums
│   ├── user_role.ex
│   └── post_status.ex
├── unions/             # Unions
│   └── search_result.ex
├── scalars/            # Custom scalars
│   ├── email.ex
│   └── url.ex
├── queries/            # Query operations
├── mutations/          # Mutation operations
└── resolvers/          # Resolver logic
```

## Common Module Functions

All GreenFairy type modules export standard functions:

| Function | Description |
|----------|-------------|
| `__green_fairy_kind__/0` | Returns the type kind (`:object`, `:interface`, etc.) |
| `__green_fairy_identifier__/0` | Returns the snake_case identifier |
| `__green_fairy_definition__/0` | Returns the full definition map |

## Naming Conventions

| GraphQL Name | Elixir Identifier |
|--------------|-------------------|
| `User` | `:user` |
| `CreateUserInput` | `:create_user_input` |
| `UserRole` | `:user_role` |
| `SearchResult` | `:search_result` |

The identifier is automatically derived from the GraphQL name using snake_case.

## Auto-Discovery

Types are automatically discovered when walking the schema graph from your
operations. You don't need to explicitly register types - just reference them
in your fields and GreenFairy finds them.

```elixir
# In your query module
field :user, :user do  # :user type auto-discovered
  arg :id, non_null(:id)
  resolve &MyApp.Resolvers.get_user/3
end
```

## Common Features

### Authorization

Object types and input types support authorization:

```elixir
type "User", struct: MyApp.User do
  authorize fn user, ctx ->
    if ctx[:current_user]?.admin, do: :all, else: [:id, :name]
  end

  field :id, non_null(:id)
  field :name, :string
  field :ssn, :string  # Hidden from non-admins
end
```

See the [Authorization Guide](authorization.html) for details.

### CQL Integration

Types with a backing struct automatically get CQL filtering:

```elixir
type "User", struct: MyApp.User do
  field :id, non_null(:id)
  field :status, :user_status  # Enum filtering auto-generated
  field :age, :integer         # Numeric operators auto-generated
end
```

See the [CQL Guide](cql.html) for details.

## Detailed Guides

- [Object Types](object-types.html) - Fields, resolvers, batch loading, associations
- [Interfaces](interfaces.html) - Shared fields, type resolution, common patterns
- [Input Types](input-types.html) - Mutation arguments, authorization, validation
- [Enums](enums.html) - Value definitions, mappings, CQL filter generation
- [Unions](unions.html) - Polymorphic returns, type resolution
- [Scalars](scalars.html) - Custom parsing/serialization, CQL operators

## Related Guides

- [Operations](operations.html) - Queries, mutations, subscriptions
- [Relationships](relationships.html) - Associations and DataLoader
- [Connections](connections.html) - Relay-style pagination
- [Authorization](authorization.html) - Field-level access control
- [CQL](cql.html) - Automatic filtering and sorting
