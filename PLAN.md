# Absinthe Object Library - Implementation Plan

## Overview

A new Elixir library (`green_fairy`) providing a cleaner DSL for GraphQL schema definitions, built on top of Absinthe. One module = one type, following SOLID principles.

## Library Name

**`green_fairy`** (package: `github.com/GreenFairy-GraphQL/greenfairy`)

**Architecture Decision: Separate Library**

The library extends Absinthe without requiring core changes:
- Generates Absinthe Blueprint AST from clean DSL
- Uses `import_types` mechanism for schema assembly
- Leverages Absinthe's runtime, phases, and execution unchanged

```
┌─────────────────────┐
│  green_fairy    │  ← Clean DSL layer
├─────────────────────┤
│  Generates Absinthe │
│  Blueprint structs  │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  absinthe           │  ← Unchanged core
└─────────────────────┘
```

---

## Module Structure

```
lib/
  absinthe/
    object.ex                     # Main entry, configuration
    object/
      # Core DSL
      type.ex                     # use GreenFairy.Type
      interface.ex                # use GreenFairy.Interface
      input.ex                    # use GreenFairy.Input
      enum.ex                     # use GreenFairy.Enum
      union.ex                    # use GreenFairy.Union
      scalar.ex                   # use GreenFairy.Scalar

      # Operations
      query.ex                    # use GreenFairy.Query
      mutation.ex                 # use GreenFairy.Mutation
      subscription.ex             # use GreenFairy.Subscription

      # Schema assembly
      schema.ex                   # use GreenFairy.Schema
      discovery.ex                # Auto-discovery of type modules
      registry.ex                 # Runtime type registry

      # Field helpers
      field/
        resolver.ex               # Smart resolver generation
        dataloader.ex             # DataLoader integration
        connection.ex             # Connection/pagination
        middleware.ex             # Middleware helpers

      # Built-ins
      built_ins/
        node.ex                   # Relay Node interface
        page_info.ex              # PageInfo type
        connection.ex             # Generic connection types

      # Code generation
      generator.ex                # Generates Absinthe Blueprint
      compiler.ex                 # Compile-time processing

      # Mix tasks
      mix/
        tasks/
          absinthe/
            object/
              gen/
                type.ex           # mix absinthe.object.gen.type
                interface.ex      # mix absinthe.object.gen.interface
                input.ex          # mix absinthe.object.gen.input
                enum.ex           # mix absinthe.object.gen.enum
                queries.ex        # mix absinthe.object.gen.queries
                mutations.ex      # mix absinthe.object.gen.mutations
                subscriptions.ex  # mix absinthe.object.gen.subscriptions
                domain.ex         # mix absinthe.object.gen.domain
                schema.ex         # mix absinthe.object.gen.schema
                scalar.ex         # mix absinthe.object.gen.scalar
```

---

## Convention Over Configuration

### Directory Structure (Recommended)

```
lib/my_app/graphql/
├── schema.ex                    # Main schema module
├── types/                       # Object types (one file per type)
│   ├── user.ex                  # type "User"
│   ├── post.ex                  # type "Post"
│   └── comment.ex               # type "Comment"
├── interfaces/                  # Interface definitions
│   ├── node.ex                  # interface "Node"
│   └── timestampable.ex         # interface "Timestampable"
├── inputs/                      # Input types for mutations
│   ├── create_user_input.ex
│   └── update_user_input.ex
├── enums/                       # Enum definitions
│   ├── user_status.ex
│   └── post_visibility.ex
├── unions/                      # Union types
│   └── search_result.ex
├── scalars/                     # Custom scalar types
│   ├── datetime.ex
│   └── money.ex
├── queries/                     # Query field modules
│   ├── user_queries.ex          # queries for User domain
│   └── post_queries.ex
├── mutations/                   # Mutation field modules
│   ├── user_mutations.ex
│   └── post_mutations.ex
├── subscriptions/               # Subscription field modules
│   ├── user_subscriptions.ex
│   └── post_subscriptions.ex
├── middleware/                  # Custom middleware
│   ├── authenticate.ex
│   └── authorize.ex
├── loaders/                     # DataLoader sources
│   ├── repo.ex
│   └── external_api.ex
└── resolvers/                   # Complex resolver logic (optional)
    ├── user_resolver.ex
    └── post_resolver.ex
```

### Naming Conventions

| Kind | Module Name | File Path | GraphQL Name |
|------|-------------|-----------|--------------|
| Type | `MyApp.GraphQL.Types.User` | `types/user.ex` | `User` |
| Interface | `MyApp.GraphQL.Interfaces.Node` | `interfaces/node.ex` | `Node` |
| Input | `MyApp.GraphQL.Inputs.CreateUserInput` | `inputs/create_user_input.ex` | `CreateUserInput` |
| Enum | `MyApp.GraphQL.Enums.UserStatus` | `enums/user_status.ex` | `UserStatus` |
| Queries | `MyApp.GraphQL.Queries.UserQueries` | `queries/user_queries.ex` | N/A (fields) |
| Mutations | `MyApp.GraphQL.Mutations.UserMutations` | `mutations/user_mutations.ex` | N/A (fields) |

### Auto-Discovery Rules

1. **Namespace scanning**: Schema discovers types under configured namespaces
2. **File = Type**: One type definition per file (enforced at compile time)
3. **Struct inference**: `type "User", struct: MyApp.User` or inferred from `MyApp.GraphQL.Types.User` → `MyApp.User`

---

## Mix Task Generators

### Available Generators

```bash
# Generate a new type
mix absinthe.object.gen.type User email:string:required name:string posts:has_many:Post

# Generate an interface
mix absinthe.object.gen.interface Node id:id:required

# Generate an input type
mix absinthe.object.gen.input CreateUserInput email:string:required name:string

# Generate an enum
mix absinthe.object.gen.enum UserStatus active inactive pending suspended

# Generate queries module
mix absinthe.object.gen.queries User

# Generate mutations module
mix absinthe.object.gen.mutations User

# Generate subscriptions module
mix absinthe.object.gen.subscriptions User

# Generate a complete domain (type + queries + mutations + subscriptions)
mix absinthe.object.gen.domain User email:string:required name:string

# Generate the main schema
mix absinthe.object.gen.schema MyApp.GraphQL

# Generate a scalar
mix absinthe.object.gen.scalar Money
```

### Generator Field Syntax

```
field_name:type[:modifier][:related_type]

# Examples:
email:string:required          # field :email, :string, null: false
name:string                    # field :name, :string
posts:has_many:Post            # has_many :posts, MyApp.GraphQL.Types.Post
organization:belongs_to:Org    # belongs_to :organization, MyApp.GraphQL.Types.Organization
friends:connection:User        # connection :friends, MyApp.GraphQL.Types.User
status:enum:UserStatus         # field :status, MyApp.GraphQL.Enums.UserStatus
```

### Example Generator Output

```bash
$ mix absinthe.object.gen.type User email:string:required name:string organization:belongs_to:Organization posts:has_many:Post
```

Generates `lib/my_app/graphql/types/user.ex`:

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  type "User", struct: MyApp.User do
    implements MyApp.GraphQL.Interfaces.Node

    field :email, :string, null: false
    field :name, :string

    belongs_to :organization, MyApp.GraphQL.Types.Organization
    has_many :posts, MyApp.GraphQL.Types.Post
  end
end
```

### Generator Configuration

In `config/config.exs`:

```elixir
config :green_fairy, :generators,
  graphql_namespace: MyApp.GraphQL,
  domain_namespace: MyApp,
  default_implements: [MyApp.GraphQL.Interfaces.Node],
  timestamps: true  # Auto-add inserted_at/updated_at fields
```

---

## DSL Examples

### Object Type

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  # Specify the backing struct for auto-resolve_type generation
  type "User", struct: MyApp.User do
    @desc "A user in the system"

    implements MyApp.GraphQL.Interfaces.Node  # Auto-registers for resolve_type

    # Basic fields - Map.get resolver by default
    field :id, :id, null: false
    field :email, :string, null: false
    field :first_name, :string

    # Computed field
    field :full_name, :string do
      resolve fn user, _, _ ->
        {:ok, "#{user.first_name} #{user.last_name}"}
      end
    end

    # Relationships - DataLoader by default
    belongs_to :organization, MyApp.GraphQL.Types.Organization
    has_many :posts, MyApp.GraphQL.Types.Post

    # Connection (paginated)
    connection :friends, MyApp.GraphQL.Types.User do
      edge do
        field :friendship_date, :datetime
      end
      field :total_count, :integer
    end
  end
end
```

### Interface

```elixir
defmodule MyApp.GraphQL.Interfaces.Node do
  use GreenFairy.Interface

  interface "Node" do
    field :id, :id, null: false
    # resolve_type is AUTO-GENERATED based on types that call `implements`!
    # No manual pattern matching needed.
  end
end

# Interfaces can implement other interfaces (GraphQL spec June 2018)
defmodule MyApp.GraphQL.Interfaces.Resource do
  use GreenFairy.Interface

  interface "Resource" do
    implements MyApp.GraphQL.Interfaces.Node  # Interface implements interface!

    field :id, :id, null: false  # Inherited from Node, must be redeclared
    field :url, :string, null: false
  end
end
```

### Input

```elixir
defmodule MyApp.GraphQL.Inputs.CreateUserInput do
  use GreenFairy.Input

  input "CreateUserInput" do
    field :email, :string, null: false
    field :first_name, :string, null: false
    field :organization_id, :id
  end
end
```

### Enum

```elixir
defmodule MyApp.GraphQL.Enums.UserStatus do
  use GreenFairy.Enum

  enum "UserStatus" do
    value :active
    value :inactive
    value :pending, as: "PENDING_APPROVAL"
  end
end
```

### Query

```elixir
defmodule MyApp.GraphQL.Queries.UserQueries do
  use GreenFairy.Query

  queries do
    field :user, MyApp.GraphQL.Types.User do
      arg :id, :id, null: false
      resolve &MyApp.Resolvers.User.get/3
    end

    connection :users, MyApp.GraphQL.Types.User do
      arg :filter, MyApp.GraphQL.Inputs.UserFilterInput
      resolve &MyApp.Resolvers.User.paginate/3
    end
  end
end
```

### Mutation

```elixir
defmodule MyApp.GraphQL.Mutations.UserMutations do
  use GreenFairy.Mutation

  mutations do
    field :create_user, MyApp.GraphQL.Types.User do
      arg :input, MyApp.GraphQL.Inputs.CreateUserInput, null: false

      middleware MyApp.Middleware.Authenticate
      resolve &MyApp.Resolvers.User.create/3
    end
  end
end
```

### Subscription

```elixir
defmodule MyApp.GraphQL.Subscriptions.UserSubscriptions do
  use GreenFairy.Subscription

  subscriptions do
    field :user_updated, MyApp.GraphQL.Types.User do
      arg :user_id, :id

      config fn args, _info ->
        {:ok, topic: args[:user_id] || "*"}
      end

      # Publish to multiple topics (specific + wildcard)
      trigger :update_user, topic: fn user ->
        ["user_updated:#{user.id}", "user_updated:*"]
      end
    end
  end
end
```

### Schema

```elixir
defmodule MyApp.GraphQL.Schema do
  use GreenFairy.Schema,
    discover: [MyApp.GraphQL],
    dataloader: [
      sources: [
        {MyApp.Accounts, MyApp.Accounts.data()},
        {MyApp.Blog, MyApp.Blog.data()}
      ]
    ]
end
```

---

## Implementation Steps

### Phase 1: Core Foundation

1. **Create mix project** with basic structure
2. **Implement `GreenFairy.Type`**
   - `type/2` macro with block support
   - `field/2-3` macro with type inference
   - `implements/1` macro for interfaces
   - Compile-time validation (one type per file)
   - Generate `__green_fairy_definition__/0` callback

3. **Implement `GreenFairy.Interface`**
   - `interface/2` macro
   - `resolve_type/1` macro
   - Field definitions same as Type

4. **Implement field inheritance**
   - When type implements interface, inherit fields
   - Allow override of inherited fields

5. **Implement auto-resolve_type**
   - Track `implements` calls at compile-time in registry
   - Auto-generate `resolve_type` function based on struct patterns
   - Types specify backing struct via `type "Name", struct: Module`
   - Allow manual override when custom logic needed

### Phase 2: Additional Types

6. **Implement `GreenFairy.Input`**
   - `input/2` macro
   - Field definitions (no resolvers)

7. **Implement `GreenFairy.Enum`**
   - `enum/2` macro
   - `value/1-2` macro with custom GraphQL names

8. **Implement `GreenFairy.Union`**
   - `union/2` macro
   - `types/1` macro
   - `resolve_type/1` macro (can also be auto-generated)

9. **Implement `GreenFairy.Scalar`**
   - `scalar/2` macro
   - `parse/1` and `serialize/1` macros

### Phase 3: Relationships & DataLoader

10. **Implement relationship macros**
    - `has_many/2-3` - generates DataLoader resolver
    - `has_one/2-3` - generates DataLoader resolver
    - `belongs_to/2-3` - generates DataLoader resolver

11. **Implement smart resolver generation**
    - Default: `Map.get` for basic fields
    - Relationships: DataLoader
    - Allow override with inline or module reference

12. **DataLoader integration**
    - Auto-configure context with loader
    - Source determination (explicit or convention)

### Phase 4: Connections

13. **Implement `connection/2-3` macro**
    - Auto-generate `*Connection` and `*Edge` types
    - Support custom edge fields via `edge do` block
    - Support custom connection fields

14. **Implement connection resolver**
    - Relay-style pagination (first/last/before/after)
    - `from_list/3` and `from_query/4` helpers

15. **Built-in PageInfo type**

### Phase 5: Operations

16. **Implement `GreenFairy.Query`**
    - `queries do` block
    - Field definitions with args
    - Connection support

17. **Implement `GreenFairy.Mutation`**
    - `mutations do` block
    - Middleware support

18. **Implement `GreenFairy.Subscription`**
    - `subscriptions do` block
    - `config/1` macro
    - `trigger/2` macro with multi-topic support

### Phase 6: Schema Assembly

19. **Implement `GreenFairy.Discovery`**
    - Scan modules for `__green_fairy_definition__/0`
    - Filter by namespace
    - Compile-time discovery

20. **Implement `GreenFairy.Schema`**
    - `use` macro with options
    - Assemble discovered types
    - Generate root query/mutation/subscription types
    - Auto-generate `resolve_type` for interfaces based on implementors
    - Configure DataLoader in context

21. **Implement `GreenFairy.Generator`**
    - Convert definitions to Absinthe Blueprint AST
    - Handle interface field inheritance
    - Wire up resolvers and middleware

### Phase 7: Middleware & Polish

22. **Middleware support**
    - Field-level: `middleware Module, opts`
    - Type-level middleware
    - Schema-level defaults

23. **Built-in interfaces**
    - `GreenFairy.BuiltIns.Node`
    - `GreenFairy.BuiltIns.Timestampable`

24. **Validation & errors**
    - One definition per file enforcement
    - Duplicate type name detection
    - Helpful compile-time error messages

### Phase 8: Mix Generators

25. **Implement `mix absinthe.object.gen.type`**
    - Parse field syntax (name:type:modifier)
    - Generate type module with fields, relationships
    - Support `--implements` flag

26. **Implement remaining generators**
    - `gen.interface`, `gen.input`, `gen.enum`
    - `gen.queries`, `gen.mutations`, `gen.subscriptions`
    - `gen.domain` (full domain scaffold)
    - `gen.schema` (main schema module)

27. **Generator configuration**
    - Read from `config :green_fairy, :generators`
    - Support custom templates

### Phase 9: Authorization & Extensibility

28. **Native field authorization**
    - `authorize: :policy_name` on individual fields
    - `authorize with: PolicyModule` at type level
    - `default_on_unauthorized: value` option
    - Policy behaviour: `can?(user, action, resource) :: boolean`

29. **Clean directive/middleware syntax**
    - `cache ttl: 300` inside field blocks
    - `require_capability :admin`
    - Middleware as declarative DSL, not function calls

30. **Macro extensibility hooks**
    - Allow `use CustomMacroModule` inside type blocks
    - Provide extension points for custom field types
    - Document how to build CQL-like systems

31. **Subscription enhancements**
    - `topics fn -> [id, "*"] end` for multiple topics
    - `trigger [:event_a, :event_b]` for multiple triggers
    - Simplified config with smart defaults

---

## Critical Files to Reference

| Absinthe File | Purpose |
|---------------|---------|
| `lib/absinthe/schema/notation.ex` | How macros build Blueprint via module attributes |
| `lib/absinthe/blueprint/schema.ex` | Blueprint assembly from attributes |
| `lib/absinthe/phase/schema/type_imports.ex` | Type discovery patterns |
| `lib/absinthe/resolution/helpers.ex` | DataLoader integration |
| `lib/absinthe/middleware.ex` | Middleware system |

---

## Verification Plan

1. **Unit tests** for each DSL macro
2. **Integration test** - complete schema with all type kinds
3. **DataLoader test** - verify batching works correctly
4. **Connection test** - verify pagination
5. **Subscription test** - verify multi-topic publishing
6. **Compile error tests** - verify helpful error messages
7. **Example app** - real-world usage demonstration

---

## Design Principles (from GigSmart Review)

### Core Philosophy: Extensibility Over Features

Rather than building specific features like CQL into the core, the library should make it **easy to build custom systems on top of the DSL**.

### Single Module = Complete Domain

A single GraphQL type module should be able to handle **all** its concerns:
- Type definition
- Field authorization
- Query filtering (CQL-like systems)
- Custom resolvers
- Middleware

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  type "User", struct: MyApp.User do
    # Built-in field authorization
    authorize with: MyApp.Policies.User

    # Custom macro extensions (like CQL) can be added
    use MyApp.GraphQL.CQL  # Brings in query_field, filter_input macros

    field :email, :string, null: false, authorize: :owner_only
    field :name, :string

    has_many :posts, MyApp.GraphQL.Types.Post
  end
end
```

### Key Features to Support

**1. Native Field Authorization**
- `authorize: :policy_name` on fields
- `authorize with: Module` at type level
- `default_on_unauthorized: value` option
- Clean integration without wrapper structs if possible

**2. Macro Extensibility**
Allow users to define custom macros that integrate cleanly:
```elixir
# User can create their own CQL-like system
defmodule MyApp.GraphQL.CQL do
  defmacro __using__(_opts) do
    quote do
      import MyApp.GraphQL.CQL.Macros
    end
  end
end
```

**3. Clean Directive Syntax**
Better than Absinthe's current approach:
```elixir
field :data, :string do
  cache ttl: 300
  require_capability :admin
  track_impressions action: :view
end
```

**4. Subscription Simplification**
Make multi-topic and wildcards first-class:
```elixir
subscription :user_updated do
  topics fn user -> [user.id, "*"] end  # Multiple topics
  trigger [:update_user, :create_user]  # Multiple triggers
end
```

### Not Needed (Handled by Core Design)

- ~~Import fields~~ → Auto-registration handles this
- ~~Node enhancers~~ → Extend interfaces instead
- ~~Connection aggregations~~ → Custom resolver macros
- ~~Command/event pattern~~ → Custom resolver macros

---

## Open Questions (Resolved)

- [x] Library name: `green_fairy`
- [x] Schema discovery: Auto-discover under configured namespaces
- [x] Resolver defaults: Map.get for basic, DataLoader for relationships
- [x] Connections: Relay-style with configurability
- [x] Subscriptions: Support multi-topic with wildcards
- [x] Type coverage: Full (type, interface, input, enum, union, scalar)
- [x] Auto-resolve_type: Yes, generated from `implements` + struct mapping
- [x] Interfaces implementing interfaces: Yes, supported per GraphQL spec
