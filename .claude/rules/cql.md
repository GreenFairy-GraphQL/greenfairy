# CQL Rules - NEVER FORGET

## CQL is ALWAYS Enabled

**NEVER write `use GreenFairy.Extensions.CQL` - This is INVALID and INCORRECT!**

CQL (Connection Query Language) is automatically enabled on ALL types when you use `use GreenFairy.Type`. There is NO separate CQL extension to enable.

❌ **WRONG:**
```elixir
defmodule MyApp.Types.User do
  use GreenFairy.Type

  type "User", struct: User do
    use GreenFairy.Extensions.CQL  # ❌ INVALID - DO NOT DO THIS!
    field :id, non_null(:id)
  end
end
```

✅ **CORRECT:**
```elixir
defmodule MyApp.Types.User do
  use GreenFairy.Type

  type "User", struct: User do
    # CQL is already enabled automatically!
    field :id, non_null(:id)
    field :name, :string
  end
end
```

## Adapter Ownership

**ADAPTERS OWN ALL OPERATOR LOGIC** - both implementation AND schema generation.

Each adapter must implement `operator_inputs/0` to declare which GraphQL operator types it supports. This prevents operator overlap when using multiple databases (Postgres + ClickHouse + Elasticsearch) in the same schema.

### Operator Namespacing

Operator types are namespaced by repo/connection name:
- **Default repo:** `CqlOpStringInput` (no prefix)
- **Non-default repos:** `CqlOp{RepoName}StringInput` (e.g., `CqlOpAnalyticsStringInput`)

This hides database implementation details from the GraphQL schema and maintains compatibility with GigSmart's existing naming conventions.

### Multi-Database Support

GreenFairy supports multiple databases in the same GraphQL schema:
- Different types can use different repos (e.g., User uses Postgres, AnalyticsEvent uses ClickHouse, SearchDocument uses Elasticsearch)
- Each repo generates its own namespaced operator types
- The default repo (typically MyApp.Repo) has no namespace prefix

### Operator Generation Flow

1. Schema discovers all CQL-enabled types at compile time
2. Extracts unique repos used across all types
3. For each repo, detects the adapter (Postgres, MySQL, ClickHouse, Elasticsearch, etc.)
4. Generates operator input types by calling `adapter.operator_inputs()`
5. Each type's filter references operators from its specific repo

This ensures:
- PostgreSQL's `_ilike` doesn't conflict with MySQL's lack of `_ilike`
- Elasticsearch's `_match` operators don't conflict with SQL operators
- Each type uses only operators its database supports
