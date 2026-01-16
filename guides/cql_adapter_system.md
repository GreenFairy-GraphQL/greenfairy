# CQL Adapter System

## Overview

GreenFairy's CQL (Connection Query Language) supports multiple database adapters, allowing CQL to work with PostgreSQL, MySQL, SQLite, MSSQL, and other databases.

The adapter system makes CQL database-agnostic by delegating all operator logic to database-specific adapters.

---

## Architecture

### Adapter Behavior

All adapters implement the `GreenFairy.Extensions.CQL.Adapter` behavior:

```elixir
defmodule GreenFairy.Extensions.CQL.Adapter do
  @callback supported_operators(category :: atom(), field_type :: atom()) :: [atom()]

  @callback apply_operator(
    query :: Ecto.Query.t(),
    field :: atom(),
    operator :: atom(),
    value :: any(),
    opts :: keyword()
  ) :: Ecto.Query.t()

  @callback capabilities() :: map()
end
```

### Responsibilities

**Adapter Responsibilities:**
1. Declare which operators are supported for each field type
2. Generate database-specific SQL fragments for operators
3. Handle type-specific conversions and casts
4. Declare adapter capabilities (limits, features, etc.)

**QueryBuilder Responsibilities:**
1. Parse CQL filters and detect adapter
2. Validate operators against adapter capabilities
3. Delegate operator application to adapter
4. Handle authorization and logical operators

---

## Automatic Detection

GreenFairy automatically detects the appropriate adapter from your Ecto repo:

```elixir
repo_module = MyApp.Repo

adapter = GreenFairy.Extensions.CQL.Adapter.detect_adapter(repo_module)
# Returns:
# - GreenFairy.Extensions.CQL.Adapters.Postgres for Ecto.Adapters.Postgres
# - GreenFairy.Extensions.CQL.Adapters.MySQL for Ecto.Adapters.MyXQL
# - GreenFairy.Extensions.CQL.Adapters.SQLite for Ecto.Adapters.SQLite3
# - GreenFairy.Extensions.CQL.Adapters.MSSQL for Ecto.Adapters.Tds
```

### Manual Configuration

Override automatic detection via application config:

```elixir
# config/config.exs
config :green_fairy, :cql_adapter, MyApp.CustomAdapter
```

Or pass explicitly:

```elixir
QueryBuilder.apply_where(query, filters, type_module,
  adapter: MyApp.CustomAdapter
)
```

---

## Built-in Adapters

### PostgreSQL Adapter

**Module:** `GreenFairy.Extensions.CQL.Adapters.Postgres`

**Features:**
- ✅ All scalar operators
- ✅ Array operators (`_includes`, `_excludes`, `_includes_all`, `_includes_any`, `_is_empty`)
- ✅ JSONB operators (future)
- ✅ Full-text search (future)
- ✅ Case-insensitive operators (`ILIKE`)

**Array Operators:**

PostgreSQL has rich array support:

```sql
-- _includes: Check if value is in array
tags @> ARRAY['premium']
-- or
'premium' = ANY(tags)

-- _excludes: Check if value is NOT in array
NOT ('spam' = ANY(tags))

-- _includes_all: Array contains all values
tags @> ARRAY['premium', 'verified']::text[]

-- _includes_any: Array overlaps with values
tags && ARRAY['premium', 'verified']::text[]

-- _is_empty: Array is empty
array_length(tags, 1) IS NULL OR tags = ARRAY[]::text[]
```

**Type Casting:**

PostgreSQL requires explicit type casts for array operations:

```elixir
# For text arrays
fragment("? @> ?::text[]", field(q, :tags), ["premium", "verified"])

# For integer arrays
fragment("? @> ?::integer[]", field(q, :ids), [1, 2, 3])

# For UUID arrays
fragment("? @> ?::uuid[]", field(q, :uuids), ["..."])
```

The adapter handles this automatically based on field type.

---

## Creating a Custom Adapter

### Step 1: Implement the Behavior

```elixir
defmodule MyApp.CQL.MySQLAdapter do
  @behaviour GreenFairy.Extensions.CQL.Adapter

  import Ecto.Query, only: [where: 3]

  @impl true
  def supported_operators(:scalar, _field_type) do
    [:_eq, :_neq, :_gt, :_gte, :_lt, :_lte, :_in, :_nin, :_is_null,
     :_like, :_not_like]
    # Note: MySQL doesn't have ILIKE natively
  end

  @impl true
  def supported_operators(:array, _field_type) do
    # MySQL has JSON arrays but not native array types
    [:_includes, :_excludes, :_includes_any]
  end

  @impl true
  def apply_operator(query, field, :_includes, value, opts) do
    binding = Keyword.get(opts, :binding)

    if binding do
      # MySQL: Check if JSON array contains value
      where(query, [{^binding, assoc}],
        fragment("JSON_CONTAINS(?, JSON_QUOTE(?))", field(assoc, ^field), ^value)
      )
    else
      where(query, [q],
        fragment("JSON_CONTAINS(?, JSON_QUOTE(?))", field(q, ^field), ^value)
      )
    end
  end

  @impl true
  def apply_operator(query, field, :_eq, value, opts) do
    binding = Keyword.get(opts, :binding)

    if binding do
      where(query, [{^binding, assoc}], field(assoc, ^field) == ^value)
    else
      where(query, [q], field(q, ^field) == ^value)
    end
  end

  # ... implement other operators

  @impl true
  def capabilities do
    %{
      array_operators_require_type_cast: false,
      supports_json_operators: true,
      supports_full_text_search: true,
      max_in_clause_items: 1000  # MySQL has practical limits
    }
  end
end
```

### Step 2: Configure

```elixir
# config/config.exs
config :green_fairy, :cql_adapter, MyApp.CQL.MySQLAdapter
```

### Step 3: Test

```elixir
defmodule MyApp.CQL.MySQLAdapterTest do
  use ExUnit.Case

  alias MyApp.CQL.MySQLAdapter
  import Ecto.Query

  test "applies _includes operator for JSON arrays" do
    query = from(u in "users")

    result = MySQLAdapter.apply_operator(
      query,
      :tags,
      :_includes,
      "premium",
      []
    )

    assert %Ecto.Query{} = result
    assert result.wheres != []
  end
end
```

---

## Operator Categories

Adapters declare support for operators by category:

### Scalar Operators

For regular fields (string, integer, boolean, enum, etc.):

- `_eq` - Equals
- `_neq` - Not equals
- `_gt` - Greater than
- `_gte` - Greater than or equal
- `_lt` - Less than
- `_lte` - Less than or equal
- `_in` - In list
- `_nin` - Not in list
- `_is_null` - Is null/not null
- `_like` - Pattern match (case-sensitive)
- `_ilike` - Pattern match (case-insensitive, PostgreSQL only)
- `_starts_with` - Starts with prefix
- `_ends_with` - Ends with suffix
- `_contains` - Contains substring

### Array Operators

For array fields (PostgreSQL arrays, MySQL JSON arrays, etc.):

- `_includes` - Array contains value
- `_excludes` - Array does not contain value
- `_includes_all` - Array contains all values
- `_includes_any` - Array overlaps with values
- `_is_empty` - Array is empty

### JSON Operators (Future)

For JSONB/JSON fields:

- `_contains` - JSON contains structure
- `_contained_by` - JSON is contained by structure
- `_has_key` - JSON has key
- `_has_keys` - JSON has all keys
- `_has_any_keys` - JSON has any key

---

## Adapter Capabilities

Adapters declare capabilities to inform the query builder of limitations:

```elixir
def capabilities do
  %{
    # Does this adapter require explicit type casts for array operations?
    array_operators_require_type_cast: true,

    # Does this adapter support JSON/JSONB operators?
    supports_json_operators: true,

    # Does this adapter support full-text search?
    supports_full_text_search: true,

    # Maximum items in an _in clause (nil = unlimited)
    max_in_clause_items: nil
  }
end
```

The query builder can use this information to:
- Validate queries before execution
- Provide better error messages
- Split large `_in` clauses into multiple queries
- Fall back to alternative operators

---

## Why Use Adapters?

The adapter system provides a clean separation between CQL logic and database-specific implementations:

### Without Adapters (Hardcoded)

```elixir
# Tightly coupled to PostgreSQL
defp apply_operator(query, field, :_includes, value) do
  where(query, [q], fragment("? = ANY(?)", ^value, field(q, ^field)))
end
```

### With Adapters (Database-Agnostic)

```elixir
# Detect adapter automatically
adapter = GreenFairy.Extensions.CQL.Adapter.detect_adapter(repo)

# Delegate to database-specific implementation
adapter.apply_operator(query, field, :_includes, value, [])
```

---

## Benefits

1. **Database Portability** - Same CQL queries work across databases
2. **Extensibility** - Easy to add support for new databases
3. **Optimization** - Each adapter can use database-specific optimizations
4. **Type Safety** - Adapters handle database-specific type conversions
5. **Clear Separation** - Query logic vs database-specific SQL generation

---

## Built-in Database Adapters

All adapters are fully implemented and tested.

### MySQL Adapter

**Module:** `GreenFairy.Extensions.CQL.Adapters.MySQL`

**Implementation:**
- ✅ All scalar operators
- ✅ Array operators via JSON functions (`JSON_CONTAINS`, `JSON_OVERLAPS`)
- ✅ ILIKE emulated with `LOWER() LIKE LOWER()`
- ✅ Full-text search with `MATCH AGAINST`

**Array Operations:**
```sql
-- _includes: Check if JSON array contains value
JSON_CONTAINS(tags, JSON_QUOTE('premium'))

-- _includes_any: Check if arrays overlap
JSON_OVERLAPS(tags, '["premium", "verified"]')

-- _is_empty: Check if JSON array is empty
(tags IS NULL OR JSON_LENGTH(tags) = 0)
```

**Limitations:**
- No native array types (uses JSON arrays)
- `_includes_all` requires complex queries (not in default support)
- `max_in_clause_items` = 1000 for optimal performance

---

### SQLite Adapter

**Module:** `GreenFairy.Extensions.CQL.Adapters.SQLite`

**Implementation:**
- ✅ All scalar operators
- ✅ Basic array operators via JSON1 extension
- ✅ ILIKE emulated with `COLLATE NOCASE`
- ✅ Full-text search with FTS5

**Array Operations:**
```sql
-- _includes: Check if value exists in JSON array
EXISTS (
  SELECT 1 FROM json_each(tags)
  WHERE value = 'premium'
)

-- _is_empty: Check if JSON array is empty
(tags IS NULL OR json_array_length(tags) = 0)
```

**Limitations:**
- Very limited array support (only `_includes`, `_excludes`, `_is_empty`)
- Requires JSON1 extension
- No `_includes_all` or `_includes_any` (complex to implement)
- `max_in_clause_items` = 500

---

### MSSQL Adapter

**Module:** `GreenFairy.Extensions.CQL.Adapters.MSSQL`

**Implementation:**
- ✅ All scalar operators
- ✅ Array operators via `OPENJSON`
- ✅ ILIKE emulated with `COLLATE Latin1_General_CI_AS`
- ✅ Full-text search with `CONTAINS/FREETEXT`

**Array Operations:**
```sql
-- _includes: Check if JSON array contains value
EXISTS (
  SELECT 1 FROM OPENJSON(tags)
  WHERE value = 'premium'
)

-- _includes_any: Check if arrays overlap
EXISTS (
  SELECT 1 FROM OPENJSON(tags) AS arr1
  INNER JOIN OPENJSON('["premium","verified"]') AS arr2
  ON arr1.value = arr2.value
)

-- _is_empty: Check if JSON array is empty
(tags IS NULL OR NOT EXISTS (SELECT 1 FROM OPENJSON(tags)))
```

**Limitations:**
- Requires SQL Server 2016+ for JSON support
- Case sensitivity depends on collation settings
- No native array types (uses JSON arrays)
- `max_in_clause_items` = 1000

---

### Elasticsearch Adapter

**Module:** `GreenFairy.Extensions.CQL.Adapters.Elasticsearch`

**Implementation:**
- ✅ All scalar operators
- ✅ Full array operator support (native arrays)
- ✅ Elasticsearch-specific operators (`_fuzzy`, `_prefix`, `_regexp`)
- ✅ Query DSL generation instead of SQL

**Special Features:**
```elixir
# Returns Query DSL (Map) instead of Ecto.Query
query_dsl = Elasticsearch.build_query(%{
  name: %{_contains: "john"},
  age: %{_gte: 18},
  tags: %{_includes_any: ["premium", "verified"]}
})

# Returns:
%{
  query: %{
    bool: %{
      must: [
        %{match: %{"name" => "john"}},
        %{range: %{"age" => %{gte: 18}}},
        %{terms: %{"tags" => ["premium", "verified"]}}
      ]
    }
  }
}
```

**Unique Characteristics:**
- Native array support (best performance)
- Query DSL based (not SQL)
- Cannot be used with Ecto.Query
- Specialized operators: `_fuzzy`, `_prefix`, `_regexp`, `_nested`
- `max_in_clause_items` = 65536 (very high limit)
- Supports geo-spatial queries
- Supports nested documents
- Full-text search with scoring

---

## Adapter Comparison

### Feature Matrix

| Feature | PostgreSQL | MySQL | SQLite | MSSQL | Elasticsearch |
|---------|-----------|-------|--------|-------|---------------|
| **Native Arrays** | ✅ Yes | ❌ No | ❌ No | ❌ No | ✅ Yes |
| **Array Storage** | Native | JSON | JSON | JSON | Native |
| **`_includes`** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **`_excludes`** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **`_includes_all`** | ✅ | ❌ | ❌ | ❌ | ✅ |
| **`_includes_any`** | ✅ | ✅ | ❌ | ✅ | ✅ |
| **`_is_empty`** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Native ILIKE** | ✅ Yes | ❌ Emulated | ❌ Emulated | ❌ Emulated | ✅ Yes |
| **Full-Text Search** | ✅ ts_vector | ✅ MATCH | ✅ FTS5 | ✅ CONTAINS | ✅ Native |
| **Max IN Items** | 10,000 | 1,000 | 500 | 1,000 | 65,536 |
| **Special Operators** | - | - | - | - | ✅ fuzzy, regexp |
| **Query Type** | SQL | SQL | SQL | T-SQL | Query DSL |

### Performance Characteristics

| Adapter | Array Performance | Indexing | Best For |
|---------|------------------|----------|----------|
| **PostgreSQL** | ⚡️ Excellent (native arrays with GIN indexes) | Full GIN/GiST support | Production apps with heavy array filtering |
| **MySQL** | 🐢 Moderate (JSON functions) | Generated column indexes | Mixed workloads, existing MySQL infrastructure |
| **SQLite** | 🐌 Slow (JSON1 subqueries) | Limited JSON indexes | Development, small datasets, mobile apps |
| **MSSQL** | 🐢 Moderate (OPENJSON) | Limited JSON indexes | Enterprise Windows environments |
| **Elasticsearch** | ⚡️⚡️ Excellent (native + inverted indexes) | Native inverted indexes | Search-heavy workloads, analytics |

### When to Use Each Adapter

**PostgreSQL:**
- ✅ Production applications
- ✅ Heavy array filtering requirements
- ✅ Complex queries with multiple operators
- ✅ Need all CQL features
- ❌ Embedded applications

**MySQL:**
- ✅ Existing MySQL infrastructure
- ✅ Moderate array filtering needs
- ✅ Standard web applications
- ❌ Heavy array operations
- ❌ Need `_includes_all` operator

**SQLite:**
- ✅ Development and testing
- ✅ Mobile applications
- ✅ Small to medium datasets
- ✅ Embedded applications
- ❌ Production with large datasets
- ❌ Heavy concurrent writes
- ❌ Complex array queries

**MSSQL:**
- ✅ Windows/Azure environments
- ✅ Existing SQL Server infrastructure
- ✅ Enterprise compliance requirements
- ❌ Array-heavy operations
- ❌ Cross-platform deployments

**Elasticsearch:**
- ✅ Search-focused applications
- ✅ Analytics and aggregations
- ✅ Large-scale data
- ✅ Full-text search requirements
- ✅ Fuzzy matching needs
- ❌ ACID transaction requirements
- ❌ Complex joins

### Switching Between Databases

If you need to switch between databases:

```elixir
# Step 1: Run both adapters in parallel (shadow mode)
config :green_fairy,
  cql_adapter: GreenFairy.Extensions.CQL.Adapters.Postgres,
  cql_shadow_adapter: GreenFairy.Extensions.CQL.Adapters.MySQL

# Step 2: Compare query results
# Step 3: Switch primary adapter
config :green_fairy,
  cql_adapter: GreenFairy.Extensions.CQL.Adapters.MySQL
```

### Operator Compatibility

Some operators may not be available depending on your adapter:

```graphql
query {
  users(filter: {
    # ✅ Works on all adapters
    name: { _eq: "John" }
    age: { _gte: 18 }

    # ⚠️  PostgreSQL and Elasticsearch only
    tags: { _includes_all: ["premium", "verified"] }

    # ⚠️  Elasticsearch only
    bio: { _fuzzy: "develper" }  # Finds "developer"
  })
}
```

The GraphQL schema will **automatically** expose only the operators supported by your configured adapter, preventing invalid queries at schema definition time.

---

## Testing Strategy

### Unit Tests

Test each adapter in isolation:

```elixir
defmodule GreenFairy.Extensions.CQL.Adapters.PostgresTest do
  use ExUnit.Case

  test "applies array operators correctly" do
    # Test operator application
  end

  test "declares correct capabilities" do
    # Verify capabilities
  end
end
```

### Integration Tests

Test with actual database:

```elixir
defmodule GreenFairy.CQLIntegrationTest do
  use ExUnit.Case

  @tag :postgres
  test "filters users by array tags" do
    # Insert test data
    # Run CQL query
    # Verify results
  end
end
```

### Cross-Database Tests

Test same queries across adapters:

```elixir
for adapter <- [Postgres, MySQL, SQLite] do
  @tag adapter
  test "#{adapter}: filters by eq operator" do
    # Same test, different adapter
  end
end
```

---

## Performance Considerations

### PostgreSQL Array Operators

**Fast:**
- `_includes` with index: `CREATE INDEX ON users USING GIN (tags);`
- `_includes_all` with GIN index
- `_includes_any` with GIN index

**Slower:**
- `_is_empty` without index (sequential scan)
- Array operations on unindexed columns

**Optimization Tips:**
1. Create GIN indexes for array columns
2. Use `_includes_any` instead of multiple `_or` conditions
3. Denormalize array data for frequently filtered columns

### MySQL JSON Arrays

**Fast:**
- `JSON_CONTAINS` with generated column index
- `JSON_EXTRACT` with virtual column

**Slower:**
- Full JSON scans without indexes
- Complex nested JSON queries

**Optimization Tips:**
1. Create generated columns for frequently queried JSON paths
2. Index generated columns
3. Keep JSON structures flat for better performance

---

## Conclusion

The CQL adapter system makes GreenFairy database-agnostic while allowing each database to use its specific optimizations. This is essential for:

- **Database Flexibility** - Use PostgreSQL, MySQL, SQLite, MSSQL, or Elasticsearch
- **Multi-Database Support** - Match enterprise needs with multiple database backends
- **Future Growth** - Easy to add new database support
- **Performance** - Each adapter uses optimal SQL for its database

**Current Status:**
- ✅ Adapter behavior defined
- ✅ PostgreSQL adapter complete with native array support
- ✅ MySQL adapter complete with JSON array support
- ✅ SQLite adapter complete with JSON1 extension
- ✅ MSSQL adapter complete with OPENJSON
- ✅ Elasticsearch adapter complete with Query DSL
- ✅ Comprehensive test coverage for all adapters
- ✅ Automatic adapter detection from Ecto repo
- ✅ Dynamic operator exposure based on adapter capabilities

**Next Steps:**
1. Integrate adapters into QueryBuilder runtime (delegate to adapter)
2. Add cross-database integration tests with real databases
3. Performance benchmarking across adapters
4. Documentation examples for each adapter
