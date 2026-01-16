# Interfaces

Interfaces define a set of fields that multiple types can implement. They enable
polymorphic queries where a field can return different types that share common fields.

## Basic Usage

```elixir
defmodule MyApp.GraphQL.Interfaces.Node do
  use GreenFairy.Interface

  interface "Node" do
    @desc "A globally unique identifier"
    field :id, non_null(:id)

    resolve_type fn
      %MyApp.User{}, _ -> :user
      %MyApp.Post{}, _ -> :post
      %MyApp.Comment{}, _ -> :comment
      _, _ -> nil
    end
  end
end
```

This generates:

```graphql
interface Node {
  id: ID!
}
```

## Implementing Interfaces

Types implement interfaces using the `implements` macro:

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  type "User", struct: MyApp.User do
    implements MyApp.GraphQL.Interfaces.Node

    field :id, non_null(:id)
    field :email, non_null(:string)
    field :name, :string
  end
end

defmodule MyApp.GraphQL.Types.Post do
  use GreenFairy.Type

  type "Post", struct: MyApp.Post do
    implements MyApp.GraphQL.Interfaces.Node

    field :id, non_null(:id)
    field :title, non_null(:string)
    field :body, :string
  end
end
```

Implementing types must include all fields defined by the interface.

## Type Resolution

The `resolve_type` callback determines which concrete type to use when the interface
is returned from a query:

```elixir
interface "Node" do
  field :id, non_null(:id)

  resolve_type fn
    %MyApp.User{}, _ -> :user
    %MyApp.Post{}, _ -> :post
    %MyApp.Comment{}, _ -> :comment
    _, _ -> nil
  end
end
```

The function receives:
1. The resolved value (the struct/map being returned)
2. The Absinthe resolution info

### Automatic Type Resolution

When types register their struct with `implements`, GreenFairy can automatically
resolve types via the `GreenFairy.Registry`:

```elixir
interface "Node" do
  field :id, non_null(:id)

  # Auto-resolve based on struct -> type mappings
  resolve_type fn value, _ ->
    GreenFairy.Registry.resolve_type(value, MyApp.GraphQL.Interfaces.Node)
  end
end
```

This works because each type with a `:struct` option registers itself:

```elixir
# This automatically registers MyApp.User -> :user for Node interface
type "User", struct: MyApp.User do
  implements MyApp.GraphQL.Interfaces.Node
  # ...
end
```

## Multiple Interfaces

Types can implement multiple interfaces:

```elixir
defmodule MyApp.GraphQL.Interfaces.Timestamped do
  use GreenFairy.Interface

  interface "Timestamped" do
    field :inserted_at, non_null(:datetime)
    field :updated_at, non_null(:datetime)

    resolve_type fn
      %MyApp.User{}, _ -> :user
      %MyApp.Post{}, _ -> :post
      _, _ -> nil
    end
  end
end

defmodule MyApp.GraphQL.Types.Post do
  use GreenFairy.Type

  type "Post", struct: MyApp.Post do
    implements MyApp.GraphQL.Interfaces.Node
    implements MyApp.GraphQL.Interfaces.Timestamped

    field :id, non_null(:id)
    field :title, non_null(:string)
    field :inserted_at, non_null(:datetime)
    field :updated_at, non_null(:datetime)
  end
end
```

## Interface Fields

Interfaces can have complex fields with arguments:

```elixir
defmodule MyApp.GraphQL.Interfaces.Searchable do
  use GreenFairy.Interface

  interface "Searchable" do
    @desc "Search relevance score"
    field :relevance_score, :float

    @desc "Highlighted search matches"
    field :highlights, list_of(:string) do
      arg :max_length, :integer, default_value: 100
    end

    resolve_type fn
      %{__struct__: module}, _ ->
        case module do
          MyApp.User -> :user
          MyApp.Post -> :post
          MyApp.Comment -> :comment
          _ -> nil
        end
      _, _ -> nil
    end
  end
end
```

## Querying Interfaces

Use inline fragments to access type-specific fields:

```graphql
query {
  node(id: "123") {
    id
    ... on User {
      email
      name
    }
    ... on Post {
      title
      body
    }
  }
}

# Or with fragment spreads
query {
  search(query: "elixir") {
    relevanceScore
    ... on User {
      email
    }
    ... on Post {
      title
    }
  }
}
```

## Common Patterns

### Node Interface (Relay)

The Node interface is fundamental to Relay-compatible schemas:

```elixir
defmodule MyApp.GraphQL.Interfaces.Node do
  use GreenFairy.Interface

  interface "Node" do
    @desc "Globally unique identifier"
    field :id, non_null(:id)

    resolve_type fn value, _ ->
      GreenFairy.Registry.resolve_type(value, __MODULE__)
    end
  end
end
```

With a root query field:

```elixir
queries do
  field :node, :node do
    arg :id, non_null(:id)

    resolve fn _, %{id: global_id}, _ ->
      case MyApp.GlobalId.decode(global_id) do
        {:ok, type, local_id} -> fetch_by_type(type, local_id)
        :error -> {:error, "Invalid ID"}
      end
    end
  end
end
```

### Actor Interface

For systems with multiple actor types:

```elixir
defmodule MyApp.GraphQL.Interfaces.Actor do
  use GreenFairy.Interface

  interface "Actor" do
    field :id, non_null(:id)
    field :display_name, non_null(:string)
    field :avatar_url, :string

    resolve_type fn
      %MyApp.User{}, _ -> :user
      %MyApp.Organization{}, _ -> :organization
      %MyApp.Bot{}, _ -> :bot
      _, _ -> nil
    end
  end
end
```

### Auditable Interface

For tracking changes:

```elixir
defmodule MyApp.GraphQL.Interfaces.Auditable do
  use GreenFairy.Interface

  interface "Auditable" do
    field :created_by, :user
    field :updated_by, :user
    field :created_at, non_null(:datetime)
    field :updated_at, non_null(:datetime)

    resolve_type fn value, _ ->
      GreenFairy.Registry.resolve_type(value, __MODULE__)
    end
  end
end
```

## Module Functions

Every interface module exports:

| Function | Description |
|----------|-------------|
| `__green_fairy_kind__/0` | Returns `:interface` |
| `__green_fairy_identifier__/0` | Returns the type identifier (e.g., `:node`) |
| `__green_fairy_definition__/0` | Returns the full definition map |

## Naming Conventions

| GraphQL Name | Elixir Identifier | Module Suggestion |
|--------------|-------------------|-------------------|
| `Node` | `:node` | `MyApp.GraphQL.Interfaces.Node` |
| `Timestamped` | `:timestamped` | `MyApp.GraphQL.Interfaces.Timestamped` |
| `Searchable` | `:searchable` | `MyApp.GraphQL.Interfaces.Searchable` |

## Next Steps

- [Object Types](object-types.html) - Types that implement interfaces
- [Unions](unions.html) - Alternative to interfaces for polymorphism
- [Relay](relay.html) - Relay-compliant Node interface
