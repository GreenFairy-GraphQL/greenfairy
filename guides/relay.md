# Relay Support

Absinthe.Object provides built-in support for the [Relay GraphQL specification](https://relay.dev/docs/guides/graphql-server-specification/), eliminating the need for the separate `absinthe_relay` dependency.

## Overview

The Relay specification defines three key patterns:

1. **Global Object Identification** - Globally unique IDs and the `node` query
2. **Cursor Connections** - Standardized pagination with edges and cursors
3. **Mutations** - Input/payload pattern with `clientMutationId`

Absinthe.Object supports all three patterns natively.

## Quick Start

### Enable Relay in Your Schema

```elixir
defmodule MyApp.GraphQL.Schema do
  use Absinthe.Object.Schema, discover: [MyApp.GraphQL]
  use Absinthe.Object.Relay, repo: MyApp.Repo
end
```

This adds:
- `node(id: ID!)` query field
- `nodes(ids: [ID!]!)` query field for batch fetching

### Define Node-Implementing Types

```elixir
defmodule MyApp.GraphQL.Types.User do
  use Absinthe.Object.Type
  import Absinthe.Object.Relay.Field

  type "User", struct: MyApp.User do
    implements Absinthe.Object.BuiltIns.Node

    # Generates globally unique ID
    global_id :id

    field :email, :string
    field :name, :string
  end
end
```

## Global Object Identification

### Global IDs

The `global_id` macro generates a field that returns a Base64-encoded ID containing both the type name and local ID:

```elixir
global_id :id                    # Uses struct's :id field
global_id :id, source: :uuid     # Uses a different source field
global_id :id, type_name: "User" # Override the type name
```

### Encoding and Decoding

Use `Absinthe.Object.Relay.GlobalId` to work with global IDs:

```elixir
alias Absinthe.Object.Relay.GlobalId

# Encoding
GlobalId.encode("User", 123)
#=> "VXNlcjoxMjM="

GlobalId.encode(:user_profile, "abc")
#=> "VXNlclByb2ZpbGU6YWJj"

# Decoding
GlobalId.decode("VXNlcjoxMjM=")
#=> {:ok, {"User", "123"}}

GlobalId.decode!("VXNlcjoxMjM=")
#=> {"User", "123"}

# Parse integer IDs when possible
GlobalId.decode_id("VXNlcjoxMjM=")
#=> {:ok, {"User", 123}}
```

### Node Query

The `node` query fetches any object by its global ID:

```graphql
query {
  node(id: "VXNlcjoxMjM=") {
    id
    ... on User {
      email
      name
    }
  }
}
```

For batch fetching:

```graphql
query {
  nodes(ids: ["VXNlcjoxMjM=", "UG9zdDo0NTY="]) {
    id
    ... on User {
      email
    }
    ... on Post {
      title
    }
  }
}
```

### Custom Node Resolution

By default, nodes are resolved using your Ecto repo. You can customize resolution per-type:

```elixir
type "User", struct: MyApp.User do
  implements Absinthe.Object.BuiltIns.Node

  node_resolver fn id, ctx ->
    MyApp.Accounts.get_user_with_permissions(id, ctx[:current_user])
  end

  global_id :id
  field :email, :string
end
```

## Cursor Connections

### Basic Connection

Use the `connection` macro for Relay-compliant pagination:

```elixir
type "User", struct: MyApp.User do
  field :id, non_null(:id)
  field :name, :string

  connection :posts, MyApp.GraphQL.Types.Post
end
```

This generates:
- `PostsConnection` type with `edges` and `pageInfo`
- `PostsEdge` type with `node` and `cursor`
- Standard pagination arguments (`first`, `after`, `last`, `before`)

### Custom Edge Fields

Add fields to edges:

```elixir
connection :friends, MyApp.GraphQL.Types.User do
  edge do
    field :friendship_date, :datetime
    field :mutual_friends_count, :integer
  end
end
```

### Custom Connection Fields

Add fields to the connection itself:

```elixir
connection :posts, MyApp.GraphQL.Types.Post do
  field :total_count, :integer
  field :average_likes, :float
end
```

### Resolving Connections

Use the connection helpers:

```elixir
alias Absinthe.Object.Field.Connection

# From a list
def resolve_posts(user, args, _resolution) do
  posts = MyApp.Content.list_posts(user_id: user.id)
  Connection.from_list(posts, args)
end

# From an Ecto query
def resolve_posts(user, args, _resolution) do
  query = from p in Post, where: p.user_id == ^user.id
  Connection.from_query(query, MyApp.Repo, args)
end
```

## Mutations

### Relay Mutations

Use `relay_mutation` for Relay-compliant mutations with automatic `clientMutationId` handling:

```elixir
defmodule MyApp.GraphQL.Mutations.UserMutations do
  use Absinthe.Object.Mutation
  import Absinthe.Object.Relay.Mutation

  mutations do
    relay_mutation :create_user do
      @desc "Creates a new user account"

      input do
        field :email, non_null(:string)
        field :name, :string
        field :password, non_null(:string)
      end

      output do
        field :user, :user
        field :errors, list_of(:string)
      end

      resolve fn input, _ctx ->
        case MyApp.Accounts.create_user(input) do
          {:ok, user} ->
            {:ok, %{user: user}}
          {:error, changeset} ->
            {:ok, %{errors: format_errors(changeset)}}
        end
      end
    end
  end
end
```

This generates:
- `CreateUserInput` input type with `clientMutationId` field
- `CreateUserPayload` output type with `clientMutationId` field
- Automatic passthrough of `clientMutationId` from input to output

### Mutation Query Example

```graphql
mutation CreateUser($input: CreateUserInput!) {
  createUser(input: $input) {
    clientMutationId
    user {
      id
      email
    }
    errors
  }
}
```

With variables:
```json
{
  "input": {
    "clientMutationId": "create-user-1",
    "email": "user@example.com",
    "name": "Jane Doe",
    "password": "secret123"
  }
}
```

### Manual clientMutationId Handling

For custom mutations that don't use `relay_mutation`, use the middleware:

```elixir
field :custom_operation, :custom_payload do
  arg :input, non_null(:custom_input)
  middleware Absinthe.Object.Relay.Mutation.ClientMutationId
  resolve &MyResolver.custom/3
end
```

Then in your resolver:

```elixir
alias Absinthe.Object.Relay.Mutation.ClientMutationId

def custom(_, %{input: input}, resolution) do
  result = do_custom_operation(input)

  {:ok, ClientMutationId.add_to_result(result, resolution)}
end
```

## API Reference

### Modules

- `Absinthe.Object.Relay` - Main Relay integration module
- `Absinthe.Object.Relay.GlobalId` - Global ID encoding/decoding
- `Absinthe.Object.Relay.Node` - Node query field
- `Absinthe.Object.Relay.Field` - Field helpers (`global_id`, `node_resolver`)
- `Absinthe.Object.Relay.Mutation` - Mutation helpers (`relay_mutation`)
- `Absinthe.Object.Field.Connection` - Connection pagination
- `Absinthe.Object.BuiltIns.Node` - Node interface
- `Absinthe.Object.BuiltIns.PageInfo` - PageInfo type

### GlobalId Functions

| Function | Description |
|----------|-------------|
| `encode(type, id)` | Encodes a type name and local ID to a global ID |
| `decode(global_id)` | Decodes a global ID, returns `{:ok, {type, id}}` |
| `decode!(global_id)` | Decodes a global ID, raises on error |
| `decode_id(global_id)` | Decodes and parses integer IDs |
| `type(global_id)` | Extracts just the type name |
| `local_id(global_id)` | Extracts just the local ID |

### Connection Functions

| Function | Description |
|----------|-------------|
| `from_list(items, args, opts)` | Creates a connection from a list |
| `from_query(query, repo, args, opts)` | Creates a connection from an Ecto query |

## See Also

- [Relay Specification](https://relay.dev/docs/guides/graphql-server-specification/)
- [Global Object Identification](https://relay.dev/graphql/objectidentification.htm)
- [Cursor Connections](https://relay.dev/graphql/connections.htm)
- [Mutations](https://relay.dev/graphql/mutations.htm)
