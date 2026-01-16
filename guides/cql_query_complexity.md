# CQL Query Complexity Analysis

## Overview

GreenFairy's CQL system includes automatic query complexity analysis that:

1. **Estimates query cost** using database EXPLAIN (PostgreSQL, MySQL) or heuristics (SQLite, MSSQL)
2. **Tracks database load** and adjusts limits dynamically
3. **Rejects expensive queries** during high load periods
4. **Provides optimization suggestions** for slow queries
5. **Caches analysis results** to minimize overhead
6. **Emits telemetry** for monitoring

This prevents denial-of-service via complex queries and protects your database under load.

---

## Quick Start

### 1. Add Middleware to Schema

```elixir
defmodule MyApp.GraphQL.Schema do
  use Absinthe.Schema
  use GreenFairy.Schema

  def middleware(middleware, field, %Absinthe.Type.Object{identifier: :query}) do
    # Add complexity checking to all query fields
    [GreenFairy.Middleware.QueryComplexity | middleware]
  end

  def middleware(middleware, _field, _object), do: middleware
end
```

### 2. Configure Limits

```elixir
# config/config.exs
config :green_fairy, :query_complexity,
  # Repo to use for analysis
  repo: MyApp.Repo,

  # Maximum complexity score (0-100)
  max_complexity: 10_000,

  # Adjust limits based on database load
  adaptive_limits: true,

  # Cache analysis results
  cache: true,

  # Cache TTL (5 minutes)
  cache_ttl: 300_000
```

### 3. That's It!

Queries are automatically analyzed and rejected if too complex.

---

## How It Works

### For PostgreSQL and MySQL

1. **Query is intercepted** by middleware before execution
2. **EXPLAIN query** is run to estimate cost
3. **Database load** is measured (connections, cache hit ratio)
4. **Adaptive limit** is calculated based on load
5. **Query is rejected** if complexity exceeds limit
6. **Suggestions** are provided for optimization

### For SQLite, MSSQL, and Other Databases

1. **Query structure** is analyzed heuristically
2. **Complexity score** is calculated from:
   - Number of WHERE conditions
   - Number of JOINs
   - ORDER BY without LIMIT
   - Large OFFSET values
   - Missing LIMIT clause
   - Subqueries and OR conditions
3. **Suggestions** are generated based on analysis
4. **Query is rejected** if score exceeds limit

---

## Adapter Support

| Database      | Analysis Method | Features                                      |
|---------------|-----------------|-----------------------------------------------|
| PostgreSQL    | EXPLAIN         | Cost, rows, sequential scans, index usage     |
| MySQL         | EXPLAIN         | Cost, rows, filesort, temporary tables        |
| SQLite        | Heuristic       | WHERE, JOINs, ORDER BY, LIMIT analysis        |
| MSSQL         | Heuristic       | WHERE, JOINs, ORDER BY, LIMIT analysis        |
| Elasticsearch | Heuristic       | Query structure analysis                      |

---

## Configuration

### Application-Level Config

```elixir
config :green_fairy, :query_complexity,
  # Required: Repo for database queries
  repo: MyApp.Repo,

  # Maximum complexity score (default: 10,000)
  max_complexity: 10_000,

  # Enable adaptive limits based on load (default: true)
  adaptive_limits: true,

  # Warning threshold as fraction of limit (default: 0.7)
  warn_threshold: 0.7,

  # Enable globally (default: true)
  enabled: true,

  # Enable caching (default: true)
  cache: true,

  # Cache TTL in milliseconds (default: 5 minutes)
  cache_ttl: 300_000
```

### Per-Field Config

```elixir
field :users, list_of(:user) do
  arg :filter, :cql_filter_user_input

  # Custom limit for this field
  middleware GreenFairy.Middleware.QueryComplexity,
    max_complexity: 5_000,
    adaptive_limits: false,
    error_message: "User query too complex"

  resolve &resolve_users/3
end
```

### Disable in Development

```elixir
# config/dev.exs
config :green_fairy, :query_complexity,
  enabled: false
```

---

## Caching

Analysis results are cached to avoid repeated EXPLAIN queries.

### Cache Behavior

- **Cache Key**: SHA256 hash of SQL query + parameters
- **Cache TTL**: 5 minutes (configurable)
- **Storage**: ETS table (in-memory)
- **Expiration**: Automatic (stale entries not returned)

### Cache Management

```elixir
# Clear cache
GreenFairy.Extensions.CQL.QueryComplexityAnalyzer.clear_cache()

# Get cache statistics
stats = GreenFairy.Extensions.CQL.QueryComplexityAnalyzer.cache_stats()
# => %{
#   size: 42,
#   valid_count: 40,
#   expired_count: 2,
#   oldest_entry_age_seconds: 120,
#   cache_ttl_seconds: 300,
#   entries: [...]
# }
```

### Disable Caching

```elixir
# Per-query
QueryComplexityAnalyzer.analyze(query, repo, cache: false)

# Globally
config :green_fairy, :query_complexity, cache: false
```

---

## Adaptive Limits

Under high database load, complexity limits are automatically reduced.

### How It Works

```
Base Limit: 10,000
Load Factor: 0.8 (high load)
Reduction: 70% max

Adaptive Limit = 10,000 * (1.0 - 0.8 * 0.7)
               = 10,000 * 0.44
               = 4,400
```

### Load Metrics

**PostgreSQL:**
- Active connections
- Cache hit ratio
- Transaction rate

**MySQL:**
- Active connections (Threads_connected)

**Load Factor Calculation:**
```
Connection Load = min(active_connections / 100, 1.0)
Cache Load = 1.0 - cache_hit_ratio
Load Factor = (Connection Load + Cache Load) / 2
```

### Disable Adaptive Limits

```elixir
config :green_fairy, :query_complexity,
  adaptive_limits: false
```

---

## Error Responses

When a query is rejected, GraphQL returns:

```json
{
  "errors": [
    {
      "message": "Query complexity too high",
      "extensions": {
        "code": "QUERY_TOO_COMPLEX",
        "complexity_score": 85.3,
        "cost": 12500,
        "suggestions": [
          "Consider adding indexes to: users, posts",
          "Query cost is very high (12500.00). Consider adding filters or limits."
        ]
      }
    }
  ]
}
```

### Custom Error Messages

```elixir
middleware GreenFairy.Middleware.QueryComplexity,
  error_message: "This query is too expensive. Please add filters."
```

---

## Heuristic Analysis

For databases without EXPLAIN support, complexity is estimated using heuristic rules.

### Scoring

| Component                   | Score Impact            |
|-----------------------------|-------------------------|
| WHERE condition             | +5 per condition        |
| Complex WHERE (OR, IN)      | +2 to +15               |
| Subquery in WHERE           | +15                     |
| Fragment in WHERE           | +10 (unknown cost)      |
| JOIN                        | +10 per join            |
| ORDER BY field              | +5 per field            |
| ORDER BY without LIMIT      | +20                     |
| No LIMIT clause             | +20                     |
| Large OFFSET (> 1000)       | +15 to +30              |
| SELECT specific fields      | +2                      |
| SELECT * or all fields      | +5                      |

### Example

```elixir
query =
  from u in "users",
    join: p in "posts", on: p.user_id == u.id,
    where: u.active == true,
    where: p.published == true,
    order_by: [desc: p.created_at]
    # No LIMIT!

# Analysis:
# - 2 WHERE conditions: +10
# - 1 JOIN: +10
# - 1 ORDER BY field: +5
# - ORDER BY without LIMIT: +20
# - No LIMIT: +20
# - SELECT *: +5
# Total: 70 points
```

### Suggestions Generated

- "Add a LIMIT clause to restrict the number of rows returned"
- "Consider adding indexes on JOIN columns for better performance"
- "Add a LIMIT clause when using ORDER BY, or add indexes on sort columns"

---

## Telemetry

Complexity analysis emits telemetry events for monitoring.

### Events

- `[:green_fairy, :query_complexity, :query_accepted]` - Query passed
- `[:green_fairy, :query_complexity, :query_warning]` - Query passed with warning
- `[:green_fairy, :query_complexity, :query_rejected]` - Query rejected

### Subscribe to Events

```elixir
:telemetry.attach_many(
  "query-complexity-handler",
  [
    [:green_fairy, :query_complexity, :query_accepted],
    [:green_fairy, :query_complexity, :query_warning],
    [:green_fairy, :query_complexity, :query_rejected]
  ],
  &handle_query_complexity_event/4,
  nil
)

def handle_query_complexity_event(event, measurements, metadata, _config) do
  %{
    cost: cost,
    complexity_score: score,
    load_factor: load
  } = measurements

  Logger.info("Query complexity: #{event} - score=#{score}, cost=#{cost}, load=#{load}")

  # Send to monitoring system
  MyApp.Metrics.track("query_complexity", score, tags: [event: event])
end
```

### Measurements

```elixir
%{
  cost: 1234.5,              # Database cost units
  complexity_score: 45.6,    # Normalized 0-100 score
  load_factor: 0.3           # Database load 0-1
}
```

### Metadata

```elixir
%{
  analysis: %{
    # Full analysis details
    cost: 1234.5,
    rows: 100,
    complexity_score: 45.6,
    seq_scans: 2,
    index_usage: ["users_idx"],
    suggestions: ["Add indexes to: posts"],
    analysis_method: :explain  # or :heuristic
  },
  load: %{
    # Load metrics
    active_connections: 25,
    cache_hit_ratio: 0.95,
    load_factor: 0.3
  }
}
```

---

## Best Practices

### 1. Set Appropriate Limits

```elixir
# Production - strict
config :green_fairy, :query_complexity,
  max_complexity: 5_000,
  adaptive_limits: true

# Development - permissive
config :green_fairy, :query_complexity,
  max_complexity: 100_000,
  adaptive_limits: false
```

### 2. Monitor Rejections

```elixir
:telemetry.attach(
  "query-rejected-alert",
  [:green_fairy, :query_complexity, :query_rejected],
  fn _event, measurements, _metadata, _config ->
    if measurements.complexity_score > 80 do
      MyApp.Alerts.send("High complexity query rejected: #{measurements.complexity_score}")
    end
  end,
  nil
)
```

### 3. Use Per-Field Limits

```elixir
# Expensive query - low limit
field :analytics, :analytics_result do
  middleware GreenFairy.Middleware.QueryComplexity, max_complexity: 1_000
  resolve &resolve_analytics/3
end

# Simple query - high limit
field :user, :user do
  middleware GreenFairy.Middleware.QueryComplexity, max_complexity: 50_000
  resolve &resolve_user/3
end
```

### 4. Add Indexes

Follow suggestions in error responses:

```json
{
  "suggestions": [
    "Consider adding indexes to: users, posts"
  ]
}
```

```sql
-- Add recommended indexes
CREATE INDEX users_active_idx ON users(active);
CREATE INDEX posts_user_id_idx ON posts(user_id);
```

### 5. Always Use LIMIT

```graphql
# Bad - no limit
query {
  users(filter: { active: { _eq: true } }) {
    id
    name
  }
}

# Good - with limit
query {
  users(
    filter: { active: { _eq: true } }
    limit: 100
  ) {
    id
    name
  }
}
```

### 6. Disable for Internal Queries

```elixir
# Internal admin query - skip complexity check
field :admin_report, :report do
  middleware GreenFairy.Middleware.QueryComplexity, enabled: false
  resolve &resolve_admin_report/3
end
```

---

## Troubleshooting

### Query Always Rejected

**Problem:** Even simple queries are rejected.

**Solution:** Check your limit configuration.

```elixir
# Too low
config :green_fairy, :query_complexity, max_complexity: 10

# Better
config :green_fairy, :query_complexity, max_complexity: 10_000
```

### Analysis Failing

**Problem:** Complexity analysis errors in logs.

**Solution:** Analysis fails open (allows query). Check:

1. Repo is configured correctly
2. Database connection is working
3. EXPLAIN queries are supported

### High Latency

**Problem:** Query execution is slow due to complexity checks.

**Solution:** Ensure caching is enabled:

```elixir
config :green_fairy, :query_complexity, cache: true
```

EXPLAIN queries are fast (< 10ms) and cached for 5 minutes.

### Too Many Warnings

**Problem:** Logs flooded with complexity warnings.

**Solution:** Adjust warning threshold:

```elixir
# Default: warn at 70% of limit
config :green_fairy, :query_complexity, warn_threshold: 0.9  # warn at 90%
```

---

## Performance Impact

### EXPLAIN Overhead

- **PostgreSQL**: ~5-15ms per unique query
- **MySQL**: ~10-20ms per unique query
- **With caching**: ~0.1ms (ETS lookup)

### Heuristic Overhead

- **Analysis time**: ~0.5-2ms (query structure analysis)
- **No database queries**: Pure Elixir computation

### Caching Impact

- **Cache hit rate**: Typically > 95% for production workloads
- **Memory usage**: ~1KB per cached query
- **Cleanup**: Automatic expiration after 5 minutes

### Recommendations

1. **Keep caching enabled** (default)
2. **Use heuristics for SQLite/MSSQL** (automatic)
3. **Monitor telemetry** to track overhead
4. **Disable in development** if overhead is noticeable

---

## Examples

### Example 1: Reject Query Without LIMIT

```graphql
query {
  posts {
    id
    title
  }
}
```

**Response:**
```json
{
  "errors": [{
    "message": "Query complexity too high",
    "extensions": {
      "code": "QUERY_TOO_COMPLEX",
      "complexity_score": 25,
      "suggestions": [
        "Add a LIMIT clause to restrict the number of rows returned"
      ]
    }
  }]
}
```

### Example 2: Warn on Complex Query

```graphql
query {
  users(filter: {
    _or: [
      { name: { _contains: "John" } },
      { email: { _contains: "example" } }
    ]
  }) {
    id
    posts {
      id
      comments {
        id
      }
    }
  }
}
```

**Log:**
```
[warning] Query complexity warning:
  Field: users
  Score: 75.3/100
  Cost: 8234.12
  Suggestions:
    - Consider adding indexes to: users
    - Complex WHERE conditions detected
```

### Example 3: Accept Optimized Query

```graphql
query {
  users(
    filter: { active: { _eq: true } }
    limit: 50
  ) {
    id
    name
  }
}
```

**Log:**
```
[debug] Query complexity check passed:
  Field: users
  Score: 15.2/100
  Cost: 145.67
```

---

## Summary

**Query complexity analysis:**
- ✅ Prevents DoS via expensive queries
- ✅ Protects database under high load
- ✅ Provides actionable optimization suggestions
- ✅ Works across all database adapters
- ✅ Minimal performance overhead with caching
- ✅ Configurable per-field or globally
- ✅ Emits telemetry for monitoring

**Supported databases:**
- ✅ PostgreSQL (EXPLAIN)
- ✅ MySQL (EXPLAIN)
- ✅ SQLite (heuristic)
- ✅ MSSQL (heuristic)
- ✅ All others (heuristic)

Enable it, configure limits, and forget about it. Your database is protected! 🎉
