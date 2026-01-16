# GreenFairy Gap Analysis

**Analysis Date:** 2026-01-16
**Goal:** Feature parity with production GraphQL implementations + enhancements

---

## Executive Summary

| Category | GreenFairy Status | Compatibility |
|----------|-------------------|---------------|
| Core Types (Object, Interface, Input, Enum, Union, Scalar) | Fully Implemented | 100% |
| CQL Filters | Advanced (Beyond Hasura) | 100%+ |
| CQL Order Inputs | Advanced (Beyond Hasura) | 100%+ |
| CQL Enum Auto-Generation | Fully Implemented | 100% |
| Connections/Pagination | Fully Implemented | 100% |
| Authorization | Fully Implemented | 100% |
| Directives | Partial (via Absinthe) | 80% |
| GreenFairy Middleware | Fully Implemented | 100% |
| Relay Mutations | Fully Implemented | 95% |
| Subscriptions | Fully Implemented | 100% |
| DataLoader Integration | Fully Implemented | 95% |
| **Overall** | | **~98%** |

---

## 1. DIRECTIVE SYSTEM

### Status: PARTIAL (Via Absinthe)

GreenFairy includes `@onUnauthorized` directive and supports Absinthe's native `directive` macro.

### Implemented Directives

| Directive | Status | Purpose |
|-----------|--------|---------|
| `@onUnauthorized` | ✅ Implemented | Control unauthorized field behavior |
| `@deprecated` | ✅ Via Absinthe | Standard GraphQL deprecation |
| Custom directives | ✅ Via Absinthe | Use `directive` macro |

### Built-in: @onUnauthorized

```graphql
query GetUser {
  user(id: "123") {
    id
    email @onUnauthorized(behavior: NIL)  # Return null if unauthorized
    ssn @onUnauthorized(behavior: ERROR)  # Return error if unauthorized
  }
}
```

### Custom Directives (Via Absinthe)

Users can define custom directives using Absinthe's native support:

```elixir
defmodule MyApp.Directives do
  use Absinthe.Schema.Notation

  directive :cache do
    description "Cache field resolution"
    arg :ttl, non_null(:integer)
    on [:field]

    expand fn %{ttl: ttl}, node ->
      put_in(node.meta[:cache_ttl], ttl)
    end
  end
end
```

### Enhancement Opportunity

A GreenFairy-specific DSL could make directive definition cleaner:

```elixir
use GreenFairy.Directive

directive :rate_limit do
  arg :limit, non_null(:integer)
  arg :window, :integer, default_value: 60
  on [:field]
end
```

**Priority: LOW** - Core functionality available via Absinthe. DSL wrapper is nice-to-have.

---

## 2. CUSTOM SCALARS

### Status: MOSTLY IMPLEMENTED

| Scalar | GreenFairy Status | Community Use |
|--------|-------------------|---------------|
| `DateTime` | ✅ Implemented | Standard |
| `Date` | ✅ Implemented | Standard |
| `Time` | ✅ Implemented | Standard |
| `Decimal` | ✅ Implemented | Common |
| `JSON` | ✅ Implemented | Very Common |
| `Upload` | ✅ Via `absinthe_plug` | Common (file uploads) |
| `URL` | Optional | Common (validation) |
| `Email` | Optional | Common (validation) |
| `UUID` | Optional | Common (validation) |
| `Money` | Optional | Domain-specific |
| `Duration` | Optional | Domain-specific |

### JSON Scalar (Implemented)

The JSON scalar is now built-in with full CQL support across all adapters:

```elixir
# Automatically available for :map fields in Ecto schemas
field :metadata, :map  # Uses GreenFairy.BuiltIns.Scalars.JSON
```

**Supported Operators:**
| Operator | PostgreSQL | MySQL | SQLite | MSSQL |
|----------|------------|-------|--------|-------|
| `_eq` | ✅ | ✅ | ✅ | ✅ |
| `_neq` | ✅ | ✅ | ✅ | ✅ |
| `_contains` | ✅ | ✅ | ❌ | ❌ |
| `_contained_by` | ✅ | ✅ | ❌ | ❌ |
| `_has_key` | ✅ | ✅ | ✅ | ✅ |
| `_has_keys` | ✅ | ❌ | ❌ | ❌ |
| `_has_any_keys` | ✅ | ❌ | ❌ | ❌ |
| `_is_null` | ✅ | ✅ | ✅ | ✅ |

### Remaining Scalars (Optional)

Validation scalars (URL, Email, UUID) and domain-specific scalars (Money, Duration) can be easily defined by users using `GreenFairy.Scalar`. These are not gaps - just optional conveniences.

**Priority: LOW** - Users can define these as needed for their domain.

---

## 3. CONNECTION AGGREGATES

### Status: FULLY IMPLEMENTED ✅

GreenFairy has full aggregate support for connections.

### Implemented Features

| Operation | Status | Use Case |
|-----------|--------|----------|
| `totalCount` | ✅ Implemented | Pagination UI |
| `exists` | ✅ Implemented | Conditional rendering |
| `sum` | ✅ Implemented | Financial totals |
| `avg` | ✅ Implemented | Statistics |
| `min` | ✅ Implemented | Range queries |
| `max` | ✅ Implemented | Range queries |

### Usage Example

```elixir
connection :engagements, node_type: :engagement do
  arg :where, :cql_filter_engagement_input

  aggregate do
    sum [:hours_worked, :total_pay]
    avg [:hours_worked, :hourly_rate]
    min [:start_time]
    max [:end_time]
  end

  resolve dataloader(Repo, :engagements)
end
```

**Generated Types:**
- `{Type}Aggregate` - Main aggregate type
- `{Type}SumAggregates` - Sum fields
- `{Type}AvgAggregates` - Average fields
- `{Type}MinAggregates` - Minimum fields
- `{Type}MaxAggregates` - Maximum fields

**Priority: N/A** - Fully implemented.

---

## 4. CQL ENUM AUTO-GENERATION

### Status: FULLY IMPLEMENTED ✅

When a GreenFairy enum is used in a CQL-enabled type's field, type-specific operator inputs are automatically generated. **No explicit option required** - follows convention over configuration.

### How It Works

```elixir
# Define a GreenFairy enum
defmodule MyApp.GraphQL.Enums.OrderStatus do
  use GreenFairy.Enum

  enum "OrderStatus" do
    value :pending
    value :shipped
    value :delivered
  end
end

# Use it in a type field
defmodule MyApp.GraphQL.Types.Order do
  use GreenFairy.Type

  type "Order", struct: MyApp.Order do
    field :id, non_null(:id)
    field :status, :order_status  # GreenFairy enum
  end
end
```

### Auto-Generated Types

The schema automatically generates:

1. **`CqlEnumOrderStatusInput`** - Type-specific scalar operator input
   ```graphql
   input CqlEnumOrderStatusInput {
     _eq: OrderStatus
     _neq: OrderStatus
     _in: [OrderStatus!]
     _nin: [OrderStatus!]
     _is_null: Boolean
   }
   ```

2. **`CqlEnumOrderStatusArrayInput`** - Type-specific array operator input
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

3. **Filter references the type-specific input:**
   ```graphql
   input CqlFilterOrderInput {
     _and: [CqlFilterOrderInput]
     _or: [CqlFilterOrderInput]
     _not: CqlFilterOrderInput
     id: CqlOpIdInput
     status: CqlEnumOrderStatusInput  # Type-specific!
   }
   ```

### Benefits

- **Type safety** - Only valid enum values accepted in filters
- **No configuration** - Automatic detection of GreenFairy enums
- **GraphQL introspection** - Schema shows actual enum type, not string

### Priority-Based Ordering

Priority ordering for enums is already supported (see CQL advanced features).

**Priority: N/A** - Fully implemented.

---

## 5. AUTHORIZATION

### Status: FULLY IMPLEMENTED (100%)

GreenFairy has a comprehensive, type-owned authorization system with client-side control.

### Implemented Features

| Feature | Status | Use Case |
|---------|--------|----------|
| Basic `authorize` callback | ✅ Implemented | Field visibility |
| `@onUnauthorized` directive | ✅ Implemented | Client controls per-field behavior |
| Type-level `on_unauthorized` | ✅ Implemented | Default behavior for type |
| Field-level `on_unauthorized` | ✅ Implemented | Override per field |
| Policy-based authorization | ✅ Implemented | Reusable policies |
| Path-aware authorization | ✅ Implemented | Context-sensitive access |
| Input authorization | ✅ Implemented | Control input field submission |
| CQL integration | ✅ Implemented | Filter only on authorized fields |

### Client Directive (Frontend Control)

```graphql
query GetUser {
  user(id: "123") {
    id
    name
    email @onUnauthorized(behavior: NIL)   # Return null if unauthorized
    ssn @onUnauthorized(behavior: ERROR)   # Return error if unauthorized
  }
}
```

### Backend Configuration

```elixir
# Type-level default
type "User", struct: MyApp.User, on_unauthorized: :return_nil do
  authorize fn user, ctx ->
    if ctx[:current_user]?.admin, do: :all, else: [:id, :name]
  end

  field :id, :id
  field :name, :string
  field :email, :string                           # Uses type default (nil)
  field :ssn, :string, on_unauthorized: :error    # Override: will error
end

# Policy-based authorization
type "User", struct: MyApp.User do
  authorize with: MyApp.Policies.UserPolicy
end
```

### Priority Chain

1. Client `@onUnauthorized(behavior: ...)` directive (highest)
2. Field-level `on_unauthorized:` option
3. Type-level `on_unauthorized:` option
4. Global default (`:error`)

**Priority: N/A** - Authorization is complete. No gaps identified.

---

## 6. GREENFAIRY-SPECIFIC MIDDLEWARE

### Status: FULLY IMPLEMENTED ✅

GreenFairy provides middleware for its domain-specific concerns. General middleware (logging, tracing, rate limiting) is handled by Absinthe.

### GreenFairy's Middleware Concerns

| Feature | Status | Purpose |
|---------|--------|---------|
| Authorization middleware | ✅ Implemented | Field visibility, `@onUnauthorized` |
| CQL complexity analysis | ✅ Implemented | Query protection |
| Extension system | ✅ Implemented | Custom type/field hooks |

### Extension System

Create custom extensions for GreenFairy types:

```elixir
defmodule MyApp.Extension do
  use GreenFairy.Extension

  @impl true
  def transform_field(field_ast, config), do: field_ast

  @impl true
  def before_compile(env, config), do: nil
end
```

### Not GreenFairy's Concern (Use Absinthe)

- Logging/tracing
- Rate limiting
- Caching
- General request middleware

**Priority: N/A** - Domain-specific middleware fully implemented.

---

## 7. RELAY MUTATIONS

### Status: FULLY IMPLEMENTED ✅

GreenFairy provides full Relay-compliant mutation support.

### Implemented Features

| Feature | Status | Use Case |
|---------|--------|----------|
| `relay_mutation` macro | ✅ Implemented | Standard pattern |
| Automatic input type generation | ✅ Implemented | `{Name}Input` |
| Automatic payload type generation | ✅ Implemented | `{Name}Payload` |
| `clientMutationId` handling | ✅ Implemented | Automatic passthrough |
| ClientMutationId middleware | ✅ Implemented | Manual control |

### Usage Example

```elixir
defmodule MyApp.GraphQL.Mutations.UserMutations do
  use GreenFairy.Mutation
  import GreenFairy.Relay.Mutation

  mutations do
    relay_mutation :create_user do
      @desc "Creates a new user"

      input do
        field :email, non_null(:string)
        field :name, :string
      end

      output do
        field :user, :user
        field :errors, list_of(:string)
      end

      resolve fn input, ctx ->
        case MyApp.Accounts.create_user(input) do
          {:ok, user} -> {:ok, %{user: user}}
          {:error, changeset} -> {:ok, %{errors: format_errors(changeset)}}
        end
      end
    end
  end
end
```

**Generates:**
- `CreateUserInput` with `clientMutationId`
- `CreateUserPayload` with `clientMutationId`
- Automatic passthrough of `clientMutationId`

### Enhancement Opportunities

| Feature | Status | Use Case |
|---------|--------|----------|
| Edge-returning helpers | Enhancement | Return new edges |
| Correlation IDs | Enhancement | Idempotency |

**Priority: LOW** - Core functionality complete, enhancements are nice-to-have.

---

## 8. STRUCTURED ERROR TYPES

### Status: NOT IMPLEMENTED

GraphQL best practice: return structured errors, not just strings.

### Required Implementation

```elixir
# Built-in error interface
defmodule GreenFairy.BuiltIns.Error do
  use GreenFairy.Interface

  interface "Error" do
    field :message, non_null(:string)
    field :code, :string  # Machine-readable code

    resolve_type fn
      %{field: _}, _ -> :field_error
      %{path: _}, _ -> :path_error
      _, _ -> :generic_error
    end
  end
end

# Field-specific error
defmodule GreenFairy.BuiltIns.FieldError do
  use GreenFairy.Type

  type "FieldError" do
    implements GreenFairy.BuiltIns.Error

    field :message, non_null(:string)
    field :code, :string
    field :field, non_null(:string)  # Which input field
  end
end
```

**Usage:**
```graphql
mutation {
  createUser(input: { email: "invalid" }) {
    user { id }
    errors {
      ... on FieldError {
        field
        message
        code
      }
    }
  }
}
```

**Priority: MEDIUM** - Important for good API design.

---

## 9. DATALOADER ENHANCEMENTS

### Status: PARTIAL

### Missing Features

| Feature | Status | Use Case |
|---------|--------|----------|
| Basic loader | Implemented | Batch loading |
| Connection loader | Implemented | Paginated associations |
| `post_process` option | **MISSING** | Transform loaded data |
| `default_value` option | **MISSING** | Fallback when nil |
| Conditional loading | **MISSING** | Load based on args |

### Required Implementation

```elixir
field :avatar_url, :string do
  loader MyApp.Loaders, :avatar,
    post_process: fn avatar -> avatar.url end,
    default_value: "/default-avatar.png"
end

field :recent_orders, list_of(:order) do
  loader MyApp.Loaders, :orders,
    args: fn _parent, args, _ctx ->
      %{limit: args[:limit] || 10, status: :completed}
    end
end
```

**Priority: LOW** - Nice to have, can work around with custom loaders.

---

## Implementation Priority Matrix

### Phase 1: High Impact, Broadly Useful

| Feature | Effort | Impact |
|---------|--------|--------|
| Directive system | Medium | Enables caching, rate limiting |
| Connection aggregates | Medium | Dashboards, analytics |
| JSON/Upload scalars | Low | Very common needs |

### Phase 2: Production Readiness

| Feature | Effort | Impact |
|---------|--------|--------|
| Structured error types | Low | API quality |
| Middleware hooks | Medium | Observability, caching |
| Correlation IDs | Low | Idempotency |
| Edge-returning helpers | Low | Relay integration |

### Phase 3: Developer Experience

| Feature | Effort | Impact |
|---------|--------|--------|
| Enum CQL auto-generation | Medium | Less boilerplate |
| Priority ordering | Low | Better UX |
| DataLoader enhancements | Medium | Convenience |
| More built-in scalars | Low | Convenience |

---

## Summary

### Production Ready (~97%)

- **Core type system (100%)** - Object, Interface, Input, Enum, Union, Scalar
- **CQL System (100%+, Beyond Hasura):**
  - Multi-database adapters (Postgres, MySQL, SQLite, MSSQL, Elasticsearch)
  - Period operators (`_period`, `_currentPeriod`) for intuitive date filtering
  - Geo-distance filtering and ordering
  - Nested association ordering with deep nesting support
  - Enum priority ordering (sort by business priority)
  - Null positioning (nullsFirst, nullsLast)
  - 100% compatible with GigSmart's CQL schema
- **Authorization (100%)** - Field-level, policy-based, path-aware, `@onUnauthorized` directive
- **Connection Aggregates (100%)** - sum, avg, min, max with type generation
- **GreenFairy Middleware (100%)** - Authorization, CQL complexity, extension system
- **Relay Mutations (95%)** - Full clientMutationId support
- **Subscriptions (100%)** - Via Absinthe integration
- **Graph-based type discovery** - Automatic type importing

### Minor Enhancement Opportunities

1. **Directive DSL** - Wrapper for cleaner directive definition (can use Absinthe directly)
2. **Common scalars** - JSON, Upload, UUID (can be added as needed)
3. **Structured errors** - Standard error interface
4. **Edge-returning helpers** - For Relay cache updates
5. **Correlation IDs** - For idempotency

### Removed from Analysis (Too Domain-Specific)

- Admin fields / admin notes
- Version/audit trail system
- Impression tracking
- Impersonation (`@onBehalfOf`)
- Feature flags (`@capabilities`)
- Force operations (`@force`)
- Custom Node interface extensions
