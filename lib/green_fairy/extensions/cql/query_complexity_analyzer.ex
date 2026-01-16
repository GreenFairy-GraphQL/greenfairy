defmodule GreenFairy.CQL.QueryComplexityAnalyzer do
  @moduledoc """
  Automatic query complexity detection using EXPLAIN analysis.

  This module:
  - Analyzes queries using database EXPLAIN
  - Estimates query cost before execution
  - Tracks database load metrics
  - Enforces dynamic complexity limits
  - Suggests query optimizations

  ## Features

  1. **Cost Estimation** - Uses EXPLAIN to estimate query cost
  2. **Load-Based Limits** - Adjusts limits based on current database load
  3. **Automatic Rejection** - Rejects expensive queries during high load
  4. **Query Suggestions** - Recommends indexes and optimizations
  5. **Telemetry Events** - Emits metrics for monitoring

  ## Usage

      # Analyze query before execution
      case QueryComplexityAnalyzer.analyze(query, repo) do
        {:ok, _analysis} ->
          # Execute query
          repo.all(query)

        {:error, :too_complex, analysis_result} ->
          # Reject query
          {:error, "Query too complex: estimated cost \#{analysis_result.cost}"}
      end

  ## Configuration

      config :green_fairy, :query_complexity,
        # Maximum query cost (PostgreSQL cost units)
        max_cost: 10_000,
        # Enable dynamic limits based on load
        adaptive_limits: true,
        # Database load sampling interval
        load_sample_interval: 5_000,
        # Cost threshold for warnings
        warn_cost: 5_000,
        # Enable caching of complexity analysis results
        cache: true,
        # Cache TTL in milliseconds
        cache_ttl: 300_000  # 5 minutes

  ## Caching

  Complexity analysis results are cached to avoid repeated EXPLAIN queries:

  - Cache key: SHA256 hash of SQL query + parameters
  - Cache TTL: 5 minutes (configurable)
  - Storage: ETS table (in-memory)
  - Automatic cleanup: Expired entries are not returned

  Disable caching:

      # Per-query
      QueryComplexityAnalyzer.analyze(query, repo, cache: false)

      # Globally in config
      config :green_fairy, :query_complexity, cache: false

  Clear cache manually:

      QueryComplexityAnalyzer.clear_cache()

  ## Heuristic Analysis

  For databases without EXPLAIN support (SQLite, MSSQL, Elasticsearch),
  complexity is estimated using heuristic rules:

  - WHERE condition count and complexity
  - JOIN count (10 points each)
  - ORDER BY without LIMIT (expensive)
  - Large OFFSET values (expensive)
  - Missing LIMIT clause (expensive)
  - Subqueries and OR conditions (expensive)

  While less accurate than EXPLAIN, heuristics catch common performance issues.

  ## GraphQL Integration

  Automatically analyze and limit queries in resolvers:

      field :users, list_of(:user) do
        arg :filter, :cql_filter_user_input
        middleware GreenFairy.Middleware.QueryComplexity
        resolve &resolve_users/3
      end
  """

  # Suppress warnings for optional ecto_sql dependency
  @compile {:no_warn_undefined, Ecto.Adapters.SQL}

  require Logger

  @cache_table :query_complexity_cache
  @cache_ttl :timer.minutes(5)  # Cache results for 5 minutes

  # Initialize ETS cache on module load
  def __on_definition__(_env, _kind, _name, _args, _guards, _body), do: :ok

  def start_cache do
    case :ets.whereis(@cache_table) do
      :undefined ->
        :ets.new(@cache_table, [:set, :public, :named_table, read_concurrency: true])

      _table ->
        :ok
    end
  end

  @type analysis :: %{
    cost: float(),
    rows: integer(),
    width: integer(),
    execution_time_estimate: float(),
    index_usage: [String.t()],
    seq_scans: integer(),
    suggestions: [String.t()],
    complexity_score: float()
  }

  @type load_metrics :: %{
    active_connections: integer(),
    cpu_usage: float(),
    cache_hit_ratio: float(),
    transaction_rate: float(),
    load_factor: float()  # 0.0 - 1.0
  }

  @doc """
  Analyze query complexity using database EXPLAIN.

  Returns {:ok, analysis} if query is acceptable,
  or {:error, :too_complex, analysis} if query exceeds limits.
  """
  def analyze(query, repo, opts \\ []) do
    # Check if caching is enabled
    if Keyword.get(opts, :cache, true) do
      analyze_with_cache(query, repo, opts)
    else
      analyze_uncached(query, repo, opts)
    end
  end

  defp analyze_with_cache(query, repo, opts) do
    # Generate cache key from query SQL
    cache_key = generate_cache_key(query, repo)

    # Ensure cache table exists
    start_cache()

    # Try to get from cache
    case :ets.lookup(@cache_table, cache_key) do
      [{^cache_key, analysis, cached_at}] ->
        # Check if cache is still valid
        age = System.monotonic_time(:millisecond) - cached_at

        if age < @cache_ttl do
          Logger.debug("Query complexity cache hit: #{cache_key}")
          {:ok, analysis}
        else
          # Cache expired, re-analyze
          analyze_and_cache(query, repo, opts, cache_key)
        end

      [] ->
        # Not in cache, analyze and cache
        analyze_and_cache(query, repo, opts, cache_key)
    end
  rescue
    _e ->
      # If caching fails, fall back to uncached analysis
      analyze_uncached(query, repo, opts)
  end

  defp analyze_and_cache(query, repo, opts, cache_key) do
    Logger.debug("Query complexity cache miss: #{cache_key}")

    case analyze_uncached(query, repo, opts) do
      {:ok, analysis} ->
        # Cache the result
        now = System.monotonic_time(:millisecond)
        :ets.insert(@cache_table, {cache_key, analysis, now})
        {:ok, analysis}

      error ->
        error
    end
  end

  defp analyze_uncached(query, repo, opts) do
    adapter = repo.__adapter__()

    case adapter do
      Ecto.Adapters.Postgres ->
        analyze_postgres(query, repo, opts)

      Ecto.Adapters.MyXQL ->
        analyze_mysql(query, repo, opts)

      _ ->
        # Use heuristic analysis for adapters without EXPLAIN
        analyze_heuristic(query, repo, opts)
    end
  end

  defp generate_cache_key(query, repo) do
    # Convert query to SQL for cache key
    {sql, params} = Ecto.Adapters.SQL.to_sql(:all, repo, query)

    # Hash SQL + params for cache key
    content = "#{sql}_#{inspect(params)}"
    :crypto.hash(:sha256, content) |> Base.encode16()
  rescue
    _e ->
      # If we can't generate SQL, use a random key (won't cache effectively)
      :rand.uniform(1_000_000) |> to_string()
  end

  @doc """
  Check if query should be executed based on current load.

  Returns:

  * `{:ok, analysis}` - Execute query
  * `{:error, :too_complex, analysis}` - Reject query
  * `{:warning, analysis}` - Execute but warn
  """
  def check_complexity(query, repo, opts \\ []) do
    with {:ok, analysis} <- analyze(query, repo, opts),
         {:ok, load} <- get_load_metrics(repo),
         {:ok, limit} <- calculate_adaptive_limit(load, opts) do

      cond do
        analysis.complexity_score > limit ->
          emit_telemetry(:query_rejected, analysis, load)
          {:error, :too_complex, analysis}

        analysis.complexity_score > limit * 0.7 ->
          emit_telemetry(:query_warning, analysis, load)
          {:warning, analysis}

        true ->
          emit_telemetry(:query_accepted, analysis, load)
          {:ok, analysis}
      end
    end
  end

  # === PostgreSQL EXPLAIN Analysis ===

  defp analyze_postgres(query, repo, opts) do
    try do
      # Convert Ecto query to SQL
      {sql, params} = Ecto.Adapters.SQL.to_sql(:all, repo, query)

      # Run EXPLAIN (not ANALYZE - we don't actually execute)
      explain_sql = "EXPLAIN (FORMAT JSON, VERBOSE TRUE) #{sql}"

      result = repo.query!(explain_sql, params)
      plan = result.rows |> List.first() |> List.first() |> Jason.decode!()

      analysis = parse_postgres_plan(plan)

      Logger.debug("Query complexity analysis: #{inspect(analysis)}")

      {:ok, analysis}
    rescue
      e ->
        Logger.error("Failed to analyze query complexity: #{inspect(e)}")
        # Fall back to heuristic analysis instead of returning 0.0
        analyze_heuristic(query, repo, opts)
    end
  end

  defp parse_postgres_plan([%{"Plan" => plan}]) do
    cost = plan["Total Cost"] || 0
    rows = plan["Plan Rows"] || 0
    width = plan["Plan Width"] || 0

    # Recursively find all nodes
    nodes = collect_plan_nodes(plan)

    # Count sequential scans (expensive without indexes)
    seq_scans = Enum.count(nodes, fn node ->
      node["Node Type"] == "Seq Scan"
    end)

    # Extract index usage
    index_usage = nodes
      |> Enum.filter(fn node -> node["Node Type"] == "Index Scan" end)
      |> Enum.map(fn node -> node["Index Name"] end)
      |> Enum.reject(&is_nil/1)

    # Generate suggestions
    suggestions = generate_suggestions(nodes, cost)

    # Estimate execution time (rough heuristic)
    execution_time_estimate = estimate_execution_time(cost, rows)

    # Calculate complexity score (0-100)
    complexity_score = calculate_complexity_score(cost, rows, seq_scans, nodes)

    %{
      cost: cost,
      rows: rows,
      width: width,
      execution_time_estimate: execution_time_estimate,
      index_usage: index_usage,
      seq_scans: seq_scans,
      suggestions: suggestions,
      complexity_score: complexity_score,
      plan_nodes: length(nodes)
    }
  end

  defp collect_plan_nodes(node, acc \\ []) do
    acc = [node | acc]

    # Recursively collect child nodes
    acc = case node["Plans"] do
      nil -> acc
      plans when is_list(plans) ->
        Enum.reduce(plans, acc, fn child, a -> collect_plan_nodes(child, a) end)
    end

    acc
  end

  defp generate_suggestions(nodes, cost) do
    suggestions = []

    # Suggest indexes for sequential scans
    seq_scan_nodes = Enum.filter(nodes, fn node ->
      node["Node Type"] == "Seq Scan"
    end)

    suggestions = if length(seq_scan_nodes) > 0 do
      table_names = seq_scan_nodes
        |> Enum.map(fn node -> node["Relation Name"] end)
        |> Enum.uniq()
        |> Enum.join(", ")

      ["Consider adding indexes to: #{table_names}" | suggestions]
    else
      suggestions
    end

    # Suggest query optimization if very expensive
    suggestions = if cost > 10_000 do
      ["Query cost is very high (#{Float.round(cost, 2)}). Consider adding filters or limits." | suggestions]
    else
      suggestions
    end

    # Suggest materialized views for complex joins
    join_nodes = Enum.filter(nodes, fn node ->
      node["Node Type"] in ["Nested Loop", "Hash Join", "Merge Join"]
    end)

    suggestions = if length(join_nodes) > 3 do
      ["Consider using a materialized view for this complex join query" | suggestions]
    else
      suggestions
    end

    suggestions
  end

  defp estimate_execution_time(cost, rows) do
    # Very rough estimate: cost units roughly correlate to milliseconds
    # This is database and hardware dependent
    base_time = cost * 0.1  # 1 cost unit ≈ 0.1ms
    row_penalty = rows * 0.001  # Each row adds small overhead
    base_time + row_penalty
  end

  defp calculate_complexity_score(cost, rows, seq_scans, nodes) do
    # Normalize different factors to 0-100 scale
    cost_score = min(cost / 1000, 100)  # 10,000 cost = 100
    row_score = min(rows / 100, 50)     # 10,000 rows = 50
    seq_scan_score = seq_scans * 15    # Each seq scan adds 15
    node_score = length(nodes) * 2      # Complexity from plan depth

    total = cost_score + row_score + seq_scan_score + node_score
    min(total, 100)
  end

  # === MySQL EXPLAIN Analysis ===

  defp analyze_mysql(query, repo, opts) do
    {sql, params} = Ecto.Adapters.SQL.to_sql(:all, repo, query)

    # MySQL EXPLAIN
    explain_sql = "EXPLAIN FORMAT=JSON #{sql}"

    try do
      result = repo.query!(explain_sql, params)
      plan = result.rows |> List.first() |> List.first() |> Jason.decode!()

      analysis = parse_mysql_plan(plan)

      {:ok, analysis}
    rescue
      e ->
        Logger.error("Failed to analyze MySQL query: #{inspect(e)}")
        # Fall back to heuristic analysis instead of returning 0.0
        analyze_heuristic(query, repo, opts)
    end
  end

  defp parse_mysql_plan(%{"query_block" => query_block}) do
    # MySQL provides cost_info
    cost_info = query_block["cost_info"] || %{}
    query_cost = cost_info["query_cost"] || "0"

    cost = String.to_float(query_cost)

    # Estimate rows
    rows = estimate_mysql_rows(query_block)

    # Check for table scans
    using_filesort = query_block["ordering_operation"] != nil
    using_temporary = query_block["grouping_operation"] != nil

    suggestions = []

    suggestions = if using_filesort do
      ["Query uses filesort - consider adding index for ORDER BY" | suggestions]
    else
      suggestions
    end

    suggestions = if using_temporary do
      ["Query uses temporary table - consider optimizing GROUP BY" | suggestions]
    else
      suggestions
    end

    complexity_score = min(cost / 100, 100)

    %{
      cost: cost,
      rows: rows,
      using_filesort: using_filesort,
      using_temporary: using_temporary,
      suggestions: suggestions,
      complexity_score: complexity_score
    }
  end

  defp estimate_mysql_rows(query_block) do
    case query_block["table"] do
      %{"rows_examined_per_scan" => rows} -> rows
      _ -> 0
    end
  end

  # === Heuristic Analysis ===

  # Heuristic-based complexity analysis for adapters without EXPLAIN support.
  #
  # Analyzes the Ecto query structure to estimate complexity:
  # - WHERE conditions
  # - JOIN complexity
  # - ORDER BY clauses
  # - LIMIT/OFFSET
  # - Subqueries
  # - Selected fields
  #
  # This is less accurate than EXPLAIN but provides reasonable estimates
  # for SQLite, MSSQL, and other adapters.
  defp analyze_heuristic(query, _repo, _opts) do
    try do
      # Extract query components
      wheres = extract_wheres(query)
      joins = extract_joins(query)
      order_bys = extract_order_bys(query)
      limit = extract_limit(query)
      offset = extract_offset(query)
      select = extract_select(query)

      # Calculate component scores
      where_score = calculate_where_score(wheres)
      join_score = calculate_join_score(joins)
      order_score = calculate_order_score(order_bys, limit)
      pagination_score = calculate_pagination_score(limit, offset)
      select_score = calculate_select_score(select)

      # Total complexity score
      complexity_score =
        where_score + join_score + order_score + pagination_score + select_score

      # Estimate cost (heuristic) - ensure float
      estimated_cost = complexity_score * 100.0

      # Estimate rows
      estimated_rows =
        if limit do
          min(limit, 1000)
        else
          1000
        end

      # Generate suggestions
      suggestions = generate_heuristic_suggestions(query, limit, joins, order_bys)

      analysis = %{
        cost: estimated_cost * 1.0,
        rows: estimated_rows,
        complexity_score: min(complexity_score, 100) * 1.0,
        where_conditions: length(wheres),
        joins: length(joins),
        order_by_fields: length(order_bys),
        has_limit: limit != nil,
        has_offset: offset != nil,
        suggestions: suggestions,
        analysis_method: :heuristic
      }

      Logger.debug("Heuristic complexity analysis: #{inspect(analysis)}")

      {:ok, analysis}
    rescue
      e ->
        Logger.error("Failed heuristic analysis: #{inspect(e)}")
        # Fail open
        {:ok, %{cost: 0.0, complexity_score: 0.0, analysis_method: :heuristic_failed}}
    end
  end

  defp extract_wheres(query) do
    query.wheres || []
  end

  defp extract_joins(query) do
    query.joins || []
  end

  defp extract_order_bys(query) do
    query.order_bys || []
  end

  defp extract_limit(query) do
    case query.limit do
      %{expr: limit} when is_integer(limit) -> limit
      _ -> nil
    end
  end

  defp extract_offset(query) do
    case query.offset do
      %{expr: offset} when is_integer(offset) -> offset
      _ -> nil
    end
  end

  defp extract_select(query) do
    query.select
  end

  # Calculate score for WHERE conditions
  defp calculate_where_score(wheres) do
    base_score = length(wheres) * 5

    # Add complexity for OR conditions and subqueries
    complex_score =
      Enum.reduce(wheres, 0, fn where, acc ->
        expr_score = analyze_expr_complexity(where.expr)
        acc + expr_score
      end)

    base_score + complex_score
  end

  # Analyze expression complexity (recursive)
  defp analyze_expr_complexity(expr) when is_tuple(expr) do
    case expr do
      {:or, _, _} -> 5  # OR is expensive
      {:and, _, _} -> 2  # AND is moderate
      {:in, _, _} -> 3   # IN is moderate
      {:fragment, _, _} -> 10  # Fragments are expensive (unknown complexity)
      {:subquery, _} -> 15  # Subqueries are very expensive
      _ -> 1
    end
  end

  defp analyze_expr_complexity(_), do: 1

  # Calculate score for JOINs
  defp calculate_join_score(joins) do
    # Each join adds significant complexity
    length(joins) * 10
  end

  # Calculate score for ORDER BY
  defp calculate_order_score(order_bys, limit) do
    order_count = Enum.reduce(order_bys, 0, fn order, acc ->
      acc + length(order.expr)
    end)

    base_score = order_count * 5

    # Sorting without LIMIT is very expensive
    if limit == nil and order_count > 0 do
      base_score + 20
    else
      base_score
    end
  end

  # Calculate score for pagination
  defp calculate_pagination_score(limit, offset) do
    cond do
      # Large offset without limit is bad
      offset != nil and offset > 1000 and limit == nil ->
        30

      # Large offset with limit is moderate
      offset != nil and offset > 1000 ->
        15

      # No limit at all is expensive
      limit == nil ->
        20

      # Reasonable pagination
      true ->
        0
    end
  end

  # Calculate score for SELECT
  defp calculate_select_score(select) do
    # SELECT * or many fields adds some overhead
    case select do
      nil -> 5  # SELECT *
      %{expr: {:&, _, _}} -> 5  # SELECT all fields
      _ -> 2  # Specific fields
    end
  end

  defp generate_heuristic_suggestions(query, limit, joins, order_bys) do
    suggestions = []

    # Suggest LIMIT if missing
    suggestions =
      if limit == nil do
        ["Add a LIMIT clause to restrict the number of rows returned" | suggestions]
      else
        suggestions
      end

    # Suggest indexes for JOINs
    suggestions =
      if length(joins) > 2 do
        ["Consider adding indexes on JOIN columns for better performance" | suggestions]
      else
        suggestions
      end

    # Suggest indexes for ORDER BY
    suggestions =
      if length(order_bys) > 0 and limit == nil do
        ["Add a LIMIT clause when using ORDER BY, or add indexes on sort columns" | suggestions]
      else
        suggestions
      end

    # Suggest reducing WHERE complexity
    where_count = length(query.wheres || [])

    suggestions =
      if where_count > 5 do
        ["Complex WHERE conditions detected. Consider simplifying or adding indexes" | suggestions]
      else
        suggestions
      end

    suggestions
  end

  # === Database Load Metrics ===

  @doc """
  Get current database load metrics.
  """
  def get_load_metrics(repo) do
    adapter = repo.__adapter__()

    case adapter do
      Ecto.Adapters.Postgres ->
        get_postgres_load_metrics(repo)

      Ecto.Adapters.MyXQL ->
        get_mysql_load_metrics(repo)

      _ ->
        {:ok, %{load_factor: 0.5}}  # Default moderate load
    end
  end

  defp get_postgres_load_metrics(repo) do
    try do
      # Get connection count
      conn_result = repo.query!("""
        SELECT count(*) as active_connections
        FROM pg_stat_activity
        WHERE state = 'active'
      """)
      active_connections = conn_result.rows |> List.first() |> List.first()

      # Get cache hit ratio
      cache_result = repo.query!("""
        SELECT
          sum(blks_hit) / NULLIF(sum(blks_hit + blks_read), 0) as cache_hit_ratio
        FROM pg_stat_database
      """)
      cache_hit_ratio = cache_result.rows |> List.first() |> List.first() || 1.0

      # Get transaction rate
      tx_result = repo.query!("""
        SELECT
          xact_commit + xact_rollback as total_transactions
        FROM pg_stat_database
        WHERE datname = current_database()
      """)
      total_transactions = tx_result.rows |> List.first() |> List.first()

      # Calculate load factor (0.0 - 1.0)
      # Higher values = higher load
      connection_load = min(active_connections / 100, 1.0)  # 100 connections = max
      cache_load = 1.0 - (cache_hit_ratio || 0.95)  # Lower cache hit = higher load

      load_factor = (connection_load + cache_load) / 2

      {:ok, %{
        active_connections: active_connections,
        cache_hit_ratio: cache_hit_ratio,
        transaction_rate: total_transactions,
        load_factor: load_factor
      }}
    rescue
      e ->
        Logger.error("Failed to get load metrics: #{inspect(e)}")
        # Return default metrics with all expected fields
        {:ok, %{
          active_connections: 10,
          cache_hit_ratio: 0.95,
          transaction_rate: 100,
          load_factor: 0.5
        }}
    end
  end

  defp get_mysql_load_metrics(repo) do
    try do
      # Get connection count
      conn_result = repo.query!("SHOW STATUS LIKE 'Threads_connected'")
      active_connections = conn_result.rows |> List.first() |> List.last() |> String.to_integer()

      # Calculate load factor
      connection_load = min(active_connections / 100, 1.0)

      {:ok, %{
        active_connections: active_connections,
        load_factor: connection_load
      }}
    rescue
      e ->
        Logger.error("Failed to get MySQL load metrics: #{inspect(e)}")
        # Return default metrics with all expected fields
        {:ok, %{
          active_connections: 10,
          load_factor: 0.5
        }}
    end
  end

  # === Adaptive Limits ===

  defp calculate_adaptive_limit(load, opts) do
    base_limit = Keyword.get(opts, :max_complexity, get_config(:max_cost, 10_000))
    adaptive = Keyword.get(opts, :adaptive_limits, get_config(:adaptive_limits, true))

    limit = if adaptive do
      # Reduce limit under high load
      # load_factor: 0.0 (low) -> 1.0 (high)
      # Under high load, reduce limit by up to 70%
      reduction_factor = 1.0 - (load.load_factor * 0.7)
      base_limit * reduction_factor
    else
      base_limit
    end

    {:ok, limit}
  end

  # === Telemetry ===

  defp emit_telemetry(event, analysis, load) do
    :telemetry.execute(
      [:green_fairy, :query_complexity, event],
      %{
        cost: analysis.cost,
        complexity_score: analysis.complexity_score,
        load_factor: load.load_factor
      },
      %{analysis: analysis, load: load}
    )
  end

  # === Configuration ===

  defp get_config(key, default) do
    Application.get_env(:green_fairy, :query_complexity, [])
    |> Keyword.get(key, default)
  end

  @doc """
  Format analysis results for logging/display.
  """
  def format_analysis(analysis) do
    """
    Query Complexity Analysis:
      Cost: #{Float.round(analysis.cost, 2)}
      Estimated rows: #{analysis.rows}
      Complexity score: #{Float.round(analysis.complexity_score, 2)}/100
      Sequential scans: #{Map.get(analysis, :seq_scans, 0)}
      Indexes used: #{Enum.join(Map.get(analysis, :index_usage, []), ", ")}
      Analysis method: #{Map.get(analysis, :analysis_method, :explain)}

    Suggestions:
    #{Enum.map_join(Map.get(analysis, :suggestions, []), "\n", fn s -> "  - #{s}" end)}
    """
  end

  @doc """
  Clear the complexity analysis cache.

  Useful for testing or when you want to force re-analysis of queries.

  ## Examples

      # Clear entire cache
      QueryComplexityAnalyzer.clear_cache()

      # Returns :ok
  """
  def clear_cache do
    start_cache()
    :ets.delete_all_objects(@cache_table)
    :ok
  end

  @doc """
  Get cache statistics.

  Returns information about the cache:
  - Size: Number of cached queries
  - Hit rate: Percentage of cache hits (since last clear)
  - Oldest entry: Age of oldest cached result

  ## Examples

      stats = QueryComplexityAnalyzer.cache_stats()
      # => %{size: 42, entries: [...]}
  """
  def cache_stats do
    start_cache()

    entries = :ets.tab2list(@cache_table)
    now = System.monotonic_time(:millisecond)

    entries_with_age =
      Enum.map(entries, fn {key, _analysis, cached_at} ->
        age_ms = now - cached_at
        %{
          key: key,
          age_ms: age_ms,
          age_seconds: div(age_ms, 1000),
          expired: age_ms > @cache_ttl
        }
      end)

    oldest =
      entries_with_age
      |> Enum.max_by(& &1.age_ms, fn -> %{age_ms: 0} end)

    expired_count = Enum.count(entries_with_age, & &1.expired)

    %{
      size: length(entries),
      expired_count: expired_count,
      valid_count: length(entries) - expired_count,
      oldest_entry_age_seconds: div(oldest[:age_ms] || 0, 1000),
      cache_ttl_seconds: div(@cache_ttl, 1000),
      entries: entries_with_age
    }
  end
end
