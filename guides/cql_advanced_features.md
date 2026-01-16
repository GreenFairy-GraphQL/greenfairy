# CQL Advanced Features

This guide covers database-specific advanced operators, capability detection, and PostgreSQL setup.

## Overview

Beyond standard CQL operators, GreenFairy exposes database-specific advanced features:

- **PostgreSQL**: Full-text search, trigram similarity, PostGIS, JSONB path queries
- **Elasticsearch**: Fuzzy matching, relevance boosting, decay functions, geo queries

These operators are automatically available based on your configured adapter and database capabilities.

---

## PostgreSQL Advanced Operators

### Full-Text Search (Built-in)

PostgreSQL has full-text search built-in since version 8.3. **No extension needed!**

**Operators:**
- `_fulltext` - Full-text search with boolean operators
- `_fulltext_phrase` - Phrase search

**Example:**

```graphql
query {
  articles(filter: {
    # Boolean operators: & (AND), | (OR), ! (NOT)
    content: { _fulltext: "graphql & (elixir | phoenix) & !ruby" }
  }) {
    id
    title
  }
}
```

**Setup:**

```sql
-- Add tsvector column
ALTER TABLE articles
  ADD COLUMN content_tsvector tsvector;

-- Create trigger to auto-update
CREATE TRIGGER articles_content_tsvector_update
  BEFORE INSERT OR UPDATE ON articles
  FOR EACH ROW EXECUTE FUNCTION
  tsvector_update_trigger(content_tsvector, 'pg_catalog.english', content);

-- Create GIN index (fast!)
CREATE INDEX articles_content_tsvector_idx
  ON articles USING GIN (content_tsvector);
```

**Without tsvector column:**

```sql
-- Create functional index
CREATE INDEX articles_content_fts_idx
  ON articles USING GIN (to_tsvector('english', content));
```

---

### Trigram Similarity (Requires pg_trgm)

Fuzzy string matching for typo-tolerant search.

**Install Extension:**

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
```

**Operators:**
- `_similar` - Similarity search with threshold
- `_similarity_distance` - Get similarity score

**Example:**

```graphql
query {
  users(filter: {
    name: { _similar: {
      value: "Johnathan Doe"
      threshold: 0.3  # 0.0 (no match) to 1.0 (exact match)
    }}
  }) {
    id
    name
  }
}
```

Finds: "Jonathan Doe", "John Doe", "Johnathon Do"

**Setup:**

```sql
-- Create GIN index for fast trigram search
CREATE INDEX users_name_trgm_idx
  ON users USING GIN (name gin_trgm_ops);
```

**Test Extension:**

```sql
-- Check similarity scores
SELECT
  similarity('Jonathan', 'Johnathan') as score1,
  similarity('Jon', 'John') as score2,
  similarity('Smith', 'Smyth') as score3;

-- score1: 0.88
-- score2: 0.66
-- score3: 0.5
```

---

### Regular Expressions (Built-in)

POSIX regular expressions are always available.

**Operators:**
- `_regex` - Case-sensitive regex match
- `_iregex` - Case-insensitive regex match
- `_not_regex` - Negated regex match
- `_not_iregex` - Negated case-insensitive regex

**Example:**

```graphql
query {
  users(filter: {
    # Match emails from specific domains
    email: { _regex: "^[a-z]+@(example|test)\\.com$" }
  }) {
    id
    email
  }
}
```

---

### JSONB Path Queries (PostgreSQL 12+)

Query nested JSON structures with JSON path.

**Operators:**
- `_jsonb_path` - JSON path query
- `_jsonb_contains_path` - Check if path exists
- `_jsonb_has_keys_all` - Has all keys
- `_jsonb_has_keys_any` - Has any key

**Example:**

```graphql
query {
  products(filter: {
    metadata: { _jsonb_path: {
      path: "$.tags[*]"
      value: "featured"
    }}
  }) {
    id
    name
  }
}
```

**Setup:**

```sql
-- Create GIN index on JSONB column
CREATE INDEX products_metadata_jsonb_idx
  ON products USING GIN (metadata);
```

---

### PostGIS Spatial Queries (Requires PostGIS)

Advanced geo-spatial queries.

**Install Extension:**

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

**Operators:**
- `_st_dwithin` - Within distance of point
- `_st_within` - Contained within geometry
- `_st_contains` - Contains geometry
- `_st_intersects` - Intersects geometry

**Example:**

```graphql
query {
  locations(filter: {
    coordinates: { _st_dwithin: {
      point: { lat: 37.7749, lon: -122.4194 }
      distance: 10000  # meters
    }}
  }) {
    id
    name
    distance
  }
}
```

**Setup:**

```sql
-- Add geometry column
ALTER TABLE locations
  ADD COLUMN coordinates geography(POINT, 4326);

-- Create spatial index
CREATE INDEX locations_coordinates_gist_idx
  ON locations USING GIST (coordinates);
```

---

### Array Operations (Built-in)

PostgreSQL has powerful native array support.

**Operators:**
- `_array_length` - Array length check
- `_array_contains_subarray` - Contains subarray
- `_array_overlap` - Arrays overlap

**Example:**

```graphql
query {
  posts(filter: {
    tags: { _array_length: { _gte: 3 } }
  }) {
    id
    tags
  }
}
```

**Setup:**

```sql
-- Create GIN index on array column
CREATE INDEX posts_tags_gin_idx
  ON posts USING GIN (tags);
```

---

## Elasticsearch Advanced Operators

### Fuzzy Matching

**Operators:**
- `_fuzzy` - Simple fuzzy match
- `_fuzzy_advanced` - Configurable fuzzy match

**Example:**

```graphql
query {
  products(filter: {
    brand: { _fuzzy_advanced: {
      value: "appel"
      fuzziness: 2  # Edit distance
      prefix_length: 0
      max_expansions: 50
    }}
  }) {
    id
    brand  # Finds "apple"
  }
}
```

---

### Relevance Boosting

**Operators:**
- `_match_boosted` - Boost relevance score
- `_multi_match` - Multi-field match with boosts

**Example:**

```graphql
query {
  products(filter: {
    description: { _match_boosted: {
      value: "gaming laptop"
      boost: 2.0  # 2x relevance
    }}
  }) {
    id
    description
    _score  # Relevance score
  }
}
```

---

### Decay Functions

**Operators:**
- `_gauss_decay` - Gaussian decay function
- `_time_decay` - Time-based decay
- `_geo_decay` - Distance-based decay

**Example:**

```graphql
query {
  listings(filter: {
    created_at: { _time_decay: {
      origin: "2024-01-01"
      scale: "7d"
      decay: 0.5
    }}
  }) {
    id
    created_at
    _score
  }
}
```

---

### More Like This

Find similar documents.

**Operators:**
- `_more_like_this` - Find similar documents

**Example:**

```graphql
query {
  articles(filter: {
    content: { _more_like_this: {
      like: "GraphQL is a query language for APIs..."
      min_term_freq: 2
      max_query_terms: 12
    }}
  }) {
    id
    title
    _score
  }
}
```

---

## Capability Detection

GreenFairy automatically detects database version and installed extensions at runtime.

### PostgreSQL Detection

```elixir
# At application startup
defmodule MyApp.Application do
  def start(_type, _args) do
    children = [MyApp.Repo, ...]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    result = Supervisor.start_link(children, opts)

    # Detect and log capabilities
    capabilities = GreenFairy.Extensions.CQL.AdapterCapabilities.detect(MyApp.Repo)
    GreenFairy.Extensions.CQL.AdapterCapabilities.log_report(capabilities)

    result
  end
end
```

**Console Output:**

```
[info] GreenFairy CQL Capabilities:
Database: PostgreSQL 15.3
Extensions: pg_trgm, postgis
Features:
  ✓ Full-text search (built-in)
  ✓ Similarity search (pg_trgm)
  ✓ Geo queries (PostGIS)
  ✓ JSONB support
  ✓ JSONB path queries
```

### Checking Capabilities

```elixir
capabilities = GreenFairy.Extensions.CQL.AdapterCapabilities.detect(MyApp.Repo)

# Check version
capabilities.version           # => {15, 3}
capabilities.version_string    # => "15.3"

# Check features
capabilities.full_text_search  # => true (built-in)
capabilities.pg_trgm          # => true (extension installed)
capabilities.postgis          # => false (not installed)

# Check extensions list
capabilities.extensions        # => [:pg_trgm, :plpgsql]
```

### Installing Extensions

```sql
-- Check available extensions
SELECT * FROM pg_available_extensions
WHERE name IN ('pg_trgm', 'postgis');

-- Install trigram extension
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Install PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Verify installation
SELECT * FROM pg_extension;
```

**Ubuntu/Debian:**

```bash
sudo apt-get install postgresql-contrib
sudo apt-get install postgis
```

**macOS (Homebrew):**

```bash
brew install postgresql  # contrib included
brew install postgis
```

---

## Conditional Operator Exposure

Operators are automatically filtered based on detected capabilities.

**Example Type Definition:**

```elixir
defmodule MyApp.GraphQL.Types.Article do
  use GreenFairy.Type

  type "Article", struct: MyApp.Article do
    field :title, :string
    field :content, :string
    field :location, :geo_point

    # Detect capabilities
    capabilities = GreenFairy.Extensions.CQL.AdapterCapabilities.detect(MyApp.Repo)

    # Full-text search (always available PG 8.3+)
    if capabilities.full_text_search do
      custom_filter :content, [:_fulltext, :_fulltext_phrase]
    end

    # Trigram similarity (only if pg_trgm installed)
    if capabilities.pg_trgm do
      custom_filter :title, [:_similar, :_similarity_distance]
    end

    # PostGIS (only if postgis installed)
    if capabilities.postgis do
      custom_filter :location, [:_st_dwithin, :_st_within]
    end
  end
end
```

**Generated GraphQL Schema:**

With pg_trgm installed:

```graphql
input CqlOpStringInput {
  _eq: String
  _contains: String
  _fulltext: String
  _similar: CqlSimilarityInput  # ✅ Available
}
```

Without pg_trgm:

```graphql
input CqlOpStringInput {
  _eq: String
  _contains: String
  _fulltext: String
  # _similar not included
}
```

---

## Feature Matrix

### PostgreSQL Features

| Feature | Version | Extension | Operator |
|---------|---------|-----------|----------|
| Full-text search | 8.3+ | ❌ None | `_fulltext` |
| JSONB | 9.4+ | ❌ None | `_jsonb_contains` |
| JSONB path | 12+ | ❌ None | `_jsonb_path` |
| Arrays | All | ❌ None | `_includes_all` |
| Regex | All | ❌ None | `_regex` |
| Trigram similarity | All | ✅ pg_trgm | `_similar` |
| Geo queries | All | ✅ PostGIS | `_st_dwithin` |

### Elasticsearch Features

| Feature | Operator | Configuration |
|---------|----------|---------------|
| Fuzzy matching | `_fuzzy` | Always available |
| Relevance boosting | `_match_boosted` | Always available |
| Decay functions | `_time_decay` | Always available |
| Geo queries | `_geo_decay` | Requires geo mapping |
| More like this | `_more_like_this` | Always available |

---

## Performance Considerations

### PostgreSQL Indexes

**GIN Indexes (Generalized Inverted Index):**

Best for:
- Full-text search
- JSONB queries
- Array operations
- Trigram similarity

```sql
-- Full-text search
CREATE INDEX articles_content_gin_idx
  ON articles USING GIN (to_tsvector('english', content));

-- JSONB
CREATE INDEX products_metadata_gin_idx
  ON products USING GIN (metadata);

-- Arrays
CREATE INDEX posts_tags_gin_idx
  ON posts USING GIN (tags);

-- Trigram
CREATE INDEX users_name_trgm_idx
  ON users USING GIN (name gin_trgm_ops);
```

**GIST Indexes (Generalized Search Tree):**

Best for:
- Geometric data (PostGIS)
- Range types
- Exclusion constraints

```sql
-- PostGIS spatial queries
CREATE INDEX locations_coordinates_gist_idx
  ON locations USING GIST (coordinates);
```

**B-tree Indexes (Regular):**

Best for:
- Equality and range queries
- Sorting
- LIKE queries with prefix

```sql
-- Email domain lookups
CREATE INDEX users_email_idx
  ON users (email);

-- Date range queries
CREATE INDEX posts_created_at_idx
  ON posts (created_at DESC);
```

### Elasticsearch Mappings

```json
{
  "mappings": {
    "properties": {
      "title": {
        "type": "text",
        "analyzer": "standard"
      },
      "tags": {
        "type": "keyword"  // For exact array matches
      },
      "location": {
        "type": "geo_point"  // For geo queries
      },
      "created_at": {
        "type": "date"  // For time decay
      }
    }
  }
}
```

---

## Testing Capabilities

Create a mix task to test database capabilities:

```elixir
defmodule Mix.Tasks.Db.Capabilities do
  use Mix.Task

  @shortdoc "Show database capabilities"

  def run(_) do
    Mix.Task.run("app.start")

    capabilities = GreenFairy.Extensions.CQL.AdapterCapabilities.detect(MyApp.Repo)
    report = GreenFairy.Extensions.CQL.AdapterCapabilities.report(capabilities)

    IO.puts(report)

    # Test features
    IO.puts("\nTesting features:\n")

    if capabilities.pg_trgm do
      IO.puts("✓ Trigram similarity: OK")
      test_trigram()
    else
      IO.puts("✗ Trigram similarity: Extension not installed")
      IO.puts("  Run: CREATE EXTENSION pg_trgm;")
    end

    if capabilities.postgis do
      IO.puts("✓ PostGIS: OK")
      test_postgis()
    else
      IO.puts("✗ PostGIS: Extension not installed")
      IO.puts("  Run: CREATE EXTENSION postgis;")
    end
  end

  defp test_trigram do
    result = MyApp.Repo.query!(
      "SELECT similarity('test', 'text') as sim"
    )
    sim = result.rows |> List.first() |> List.first()
    IO.puts("  Similarity('test', 'text') = #{sim}")
  end

  defp test_postgis do
    result = MyApp.Repo.query!(
      "SELECT PostGIS_Version() as version"
    )
    version = result.rows |> List.first() |> List.first()
    IO.puts("  PostGIS version: #{version}")
  end
end
```

**Run:**

```bash
mix db.capabilities
```

---

## Troubleshooting

### Extension Not Available

**Error:**
```
** (Postgrex.Error) ERROR 42704 (undefined_object) extension "pg_trgm" is not available
```

**Solution:**

```bash
# Ubuntu/Debian
sudo apt-get install postgresql-contrib

# macOS
brew install postgresql  # contrib included

# Then restart PostgreSQL and install extension
sudo service postgresql restart
psql -d mydb -c "CREATE EXTENSION pg_trgm;"
```

### Permission Denied

**Error:**
```
ERROR: permission denied to create extension "pg_trgm"
```

**Solution:**

```sql
-- Connect as superuser
sudo -u postgres psql mydb

-- Grant privilege
GRANT CREATE ON DATABASE mydb TO myuser;

-- Or create extension as superuser
CREATE EXTENSION IF NOT EXISTS pg_trgm;
```

### Index Not Being Used

**Check query plan:**

```sql
EXPLAIN ANALYZE
SELECT * FROM users WHERE name ILIKE '%john%';
```

**If you see "Seq Scan" instead of "Index Scan":**

1. Verify index exists
2. Run `ANALYZE users;` to update statistics
3. Check if condition matches index type (e.g., trigram index for `ILIKE`)

---

## Best Practices

### 1. Always Check Capabilities

```elixir
capabilities = AdapterCapabilities.detect(repo)

if capabilities.pg_trgm do
  # Use trigram operators
else
  # Fall back to ILIKE or contains
end
```

### 2. Create Appropriate Indexes

```sql
-- For full-text search
CREATE INDEX USING GIN (to_tsvector('english', content));

-- For array operations
CREATE INDEX USING GIN (tags);

-- For trigram similarity
CREATE INDEX USING GIN (name gin_trgm_ops);

-- For geo queries
CREATE INDEX USING GIST (coordinates);
```

### 3. Test Performance

```sql
-- Check query plan
EXPLAIN ANALYZE SELECT ...;

-- Look for:
-- ✓ Index Scan (good)
-- ✗ Seq Scan (bad - add index)
```

### 4. Monitor Query Costs

Use query complexity analysis (see [CQL Query Complexity](cql_query_complexity.md)) to automatically detect and reject expensive queries.

---

## Summary

GreenFairy CQL advanced features provide:

- ✅ **PostgreSQL full-text search** - Built-in, no extension needed
- ✅ **Trigram similarity** - Fuzzy matching with pg_trgm
- ✅ **PostGIS spatial queries** - Geo-spatial operations
- ✅ **JSONB path queries** - Deep JSON querying
- ✅ **Elasticsearch advanced search** - Fuzzy, boosting, decay
- ✅ **Automatic capability detection** - Runtime feature detection
- ✅ **Conditional operator exposure** - Only available operators in schema
- ✅ **Comprehensive indexing** - GIN, GIST, B-tree support

All features are automatically detected and exposed based on your database configuration!
