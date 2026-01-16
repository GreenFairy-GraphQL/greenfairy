<p align="center">
  <img src="assets/logo.svg" alt="GreenFairy Logo" width="200">
</p>

<h1 align="center">GreenFairy</h1>

<p align="center">
  <a href="https://hex.pm/packages/green_fairy"><img src="https://img.shields.io/hexpm/v/green_fairy.svg" alt="Hex.pm"></a>
  <a href="https://hexdocs.pm/green_fairy"><img src="https://img.shields.io/badge/docs-hexdocs-blue.svg" alt="Documentation"></a>
  <a href="https://github.com/GreenFairy-GraphQL/greenfairy/actions"><img src="https://github.com/GreenFairy-GraphQL/greenfairy/workflows/CI/badge.svg" alt="CI"></a>
</p>

<p align="center">
  A cleaner DSL for GraphQL schema definitions built on <a href="https://github.com/absinthe-graphql/absinthe">Absinthe</a>.
</p>

---

> **Note:** GreenFairy is in early development and should be considered experimental.
> The API may change significantly between versions. Use in production at your own risk.

---

## Why GreenFairy?

- **One module = one type** — Each GraphQL type lives in its own file (SOLID principles)
- **Convention over configuration** — Smart defaults reduce boilerplate
- **Auto-discovery** — Types are automatically discovered from your schema graph
- **CQL (Connection Query Language)** — Automatic Hasura-style filtering and sorting
- **Multi-database** — PostgreSQL, MySQL, SQLite, MSSQL, Elasticsearch adapters
- **DataLoader integration** — Efficient batched queries out of the box
- **Relay connections** — Built-in cursor-based pagination
- **Authorization** — Simple, type-owned field visibility control

## Installation

```elixir
def deps do
  [
    {:green_fairy, "~> 0.1.0"}
  ]
end
```

## Quick Start

### Define a Type

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  type "User", struct: MyApp.User do
    implements MyApp.GraphQL.Interfaces.Node

    field :id, non_null(:id)
    field :email, non_null(:string)
    field :name, :string

    field :display_name, :string do
      resolve fn user, _, _ ->
        {:ok, user.name || user.email}
      end
    end

    # Associations resolved via DataLoader
    field :posts, list_of(:post)

    # Relay-style pagination with automatic filtering
    connection :friends, MyApp.GraphQL.Types.User
  end
end
```

### Define an Interface

```elixir
defmodule MyApp.GraphQL.Interfaces.Node do
  use GreenFairy.Interface

  interface "Node" do
    field :id, non_null(:id)
    # resolve_type auto-generated from implementing types!
  end
end
```

### Define Operations

```elixir
defmodule MyApp.GraphQL.Queries.UserQueries do
  use GreenFairy.Query

  queries do
    field :user, :user do
      arg :id, non_null(:id)
      resolve &MyApp.Resolvers.User.get/3
    end
  end
end
```

### Assemble the Schema

```elixir
defmodule MyApp.GraphQL.Schema do
  use GreenFairy.Schema,
    query: MyApp.GraphQL.Queries,
    mutation: MyApp.GraphQL.Mutations
end
```

That's it! Types are auto-discovered by walking the graph from your operations.

## CQL — Automatic Filtering & Sorting

Every type with a backing struct automatically gets Hasura-style filtering:

```graphql
query {
  users(
    where: {
      age: { _gte: 18 }
      email: { _ilike: "%@example.com" }
      _or: [
        { role: { _eq: ADMIN } }
        { verified: { _eq: true } }
      ]
    }
    orderBy: [{ createdAt: { direction: DESC } }]
    first: 10
  ) {
    nodes { id name email }
    totalCount
    pageInfo { hasNextPage endCursor }
  }
}
```

Supported operators include `_eq`, `_neq`, `_gt`, `_gte`, `_lt`, `_lte`, `_in`, `_nin`, `_like`, `_ilike`, `_is_null`, and logical operators `_and`, `_or`, `_not`.

See the [CQL Guide](https://hexdocs.pm/green_fairy/cql.html) for complete documentation.

## Authorization

Types control their own field visibility:

```elixir
type "User", struct: MyApp.User do
  authorize fn user, ctx ->
    cond do
      ctx[:current_user]?.admin -> :all
      ctx[:current_user]?.id == user.id -> [:id, :name, :email]
      true -> [:id, :name]  # Public only
    end
  end

  field :id, non_null(:id)
  field :name, :string
  field :email, :string      # Self or admin only
  field :ssn, :string        # Admin only
end
```

See the [Authorization Guide](https://hexdocs.pm/green_fairy/authorization.html) for advanced patterns.

## Directory Structure

```
lib/my_app/graphql/
├── schema.ex           # Main schema
├── types/              # Object types
├── interfaces/         # Interfaces
├── inputs/             # Input types
├── enums/              # Enums
├── unions/             # Unions
├── scalars/            # Custom scalars
├── queries/            # Query operations
├── mutations/          # Mutation operations
└── resolvers/          # Resolver logic
```

## Documentation

Full documentation at [HexDocs](https://hexdocs.pm/green_fairy).

### Guides

| Guide | Description |
|-------|-------------|
| [Getting Started](https://hexdocs.pm/green_fairy/getting-started.html) | Installation and first schema |
| [Types](https://hexdocs.pm/green_fairy/types.html) | Objects, interfaces, inputs, enums, unions |
| [Custom Scalars](https://hexdocs.pm/green_fairy/custom-scalars.html) | Custom scalars with CQL adapter support |
| [Operations](https://hexdocs.pm/green_fairy/operations.html) | Queries, mutations, subscriptions |
| [Authorization](https://hexdocs.pm/green_fairy/authorization.html) | Field-level access control |
| [Relationships](https://hexdocs.pm/green_fairy/relationships.html) | Associations and DataLoader |
| [Connections](https://hexdocs.pm/green_fairy/connections.html) | Relay-style pagination |
| [CQL](https://hexdocs.pm/green_fairy/cql.html) | Filtering, sorting, and multi-database support |
| [Relay](https://hexdocs.pm/green_fairy/relay.html) | Global IDs, Node interface, mutations |
| [Configuration](https://hexdocs.pm/green_fairy/global-config.html) | Global settings and adapters |

### CQL Deep Dives

| Guide | Description |
|-------|-------------|
| [CQL Getting Started](https://hexdocs.pm/green_fairy/cql-getting-started.html) | Basic filtering and sorting |
| [CQL Adapters](https://hexdocs.pm/green_fairy/cql-adapters.html) | Multi-database configuration |
| [CQL Advanced](https://hexdocs.pm/green_fairy/cql-advanced.html) | Full-text search, geo queries |
| [Query Complexity](https://hexdocs.pm/green_fairy/query-complexity.html) | EXPLAIN-based analysis and limits |

## Available Modules

### Core DSL
`GreenFairy.Type` · `GreenFairy.Interface` · `GreenFairy.Input` · `GreenFairy.Enum` · `GreenFairy.Union` · `GreenFairy.Scalar`

### Operations
`GreenFairy.Query` · `GreenFairy.Mutation` · `GreenFairy.Subscription`

### Schema
`GreenFairy.Schema` · `GreenFairy.Discovery`

### Fields
`GreenFairy.Field.Connection` · `GreenFairy.Field.Loader`

### Relay
`GreenFairy.Relay` · `GreenFairy.Relay.GlobalId` · `GreenFairy.Relay.Node` · `GreenFairy.Relay.Field`

### Built-ins
`GreenFairy.BuiltIns.Node` · `GreenFairy.BuiltIns.PageInfo` · `GreenFairy.BuiltIns.Timestampable`

## License

MIT License — see [LICENSE](LICENSE) for details.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -am 'Add feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Create a Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.
