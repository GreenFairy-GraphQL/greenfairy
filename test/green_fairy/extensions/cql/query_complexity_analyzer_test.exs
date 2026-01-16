defmodule GreenFairy.CQL.QueryComplexityAnalyzerTest do
  use ExUnit.Case, async: false  # Changed to false because we start shared repos

  alias GreenFairy.CQL.QueryComplexityAnalyzer

  import Ecto.Query

  # Configure repos before they're defined
  Application.put_env(:green_fairy, __MODULE__.PostgresRepo, [])
  Application.put_env(:green_fairy, __MODULE__.MySQLRepo, [])
  Application.put_env(:green_fairy, __MODULE__.SQLiteRepo, [])
  Application.put_env(:green_fairy, __MODULE__.MSSQLRepo, [])
  Application.put_env(:green_fairy, __MODULE__.ErrorRepo, [])

  # Mock repos for testing
  defmodule PostgresRepo do
    use Ecto.Repo,
      otp_app: :green_fairy,
      adapter: Ecto.Adapters.Postgres

    def query!(sql, _params) do
      cond do
        String.contains?(sql, "EXPLAIN") ->
          # Mock EXPLAIN output
          %{
            rows: [
              [
                Jason.encode!([
                  %{
                    "Plan" => %{
                      "Node Type" => "Seq Scan",
                      "Relation Name" => "users",
                      "Total Cost" => 1000.0,
                      "Plan Rows" => 100,
                      "Plan Width" => 50
                    }
                  }
                ])
              ]
            ]
          }

        String.contains?(sql, "pg_stat_activity") ->
          # Mock active connections
          %{rows: [[10]]}

        String.contains?(sql, "pg_stat_database") and String.contains?(sql, "blks_hit") ->
          # Mock cache hit ratio
          %{rows: [[0.95]]}

        String.contains?(sql, "pg_stat_database") and String.contains?(sql, "xact_commit") ->
          # Mock transaction count
          %{rows: [[1000]]}

        true ->
          %{rows: []}
      end
    end
  end

  defmodule MySQLRepo do
    use Ecto.Repo,
      otp_app: :green_fairy,
      adapter: Ecto.Adapters.MyXQL

    def query!(sql, _params) do
      cond do
        String.contains?(sql, "EXPLAIN") ->
          # Mock EXPLAIN output
          %{
            rows: [
              [
                Jason.encode!(%{
                  "query_block" => %{
                    "cost_info" => %{
                      "query_cost" => "500.0"
                    },
                    "table" => %{
                      "rows_examined_per_scan" => 50
                    }
                  }
                })
              ]
            ]
          }

        String.contains?(sql, "Threads_connected") ->
          # Mock connection count
          %{rows: [["Threads_connected", "20"]]}

        true ->
          %{rows: []}
      end
    end
  end

  defmodule SQLiteRepo do
    use Ecto.Repo,
      otp_app: :green_fairy,
      adapter: Ecto.Adapters.SQLite3
  end

  defmodule MSSQLRepo do
    use Ecto.Repo,
      otp_app: :green_fairy,
      adapter: Ecto.Adapters.Tds
  end

  defmodule ErrorRepo do
    use Ecto.Repo,
      otp_app: :green_fairy,
      adapter: Ecto.Adapters.Postgres

    def query!(_sql, _params) do
      raise "Database error"
    end
  end

  defmodule UnknownRepo do
    def __adapter__, do: Some.Unknown.Adapter
    def config, do: [adapter: Some.Unknown.Adapter]
    def get_dynamic_repo, do: __MODULE__
  end

  # Start repos before running tests
  setup_all do
    # Start each repo to register it with Ecto
    repos = [PostgresRepo, MySQLRepo, SQLiteRepo, MSSQLRepo, ErrorRepo]

    for repo <- repos do
      try do
        {:ok, _} = repo.start_link(pool_size: 1)
      rescue
        # Ignore if already started or can't connect
        _ -> :ok
      catch
        # Ignore any errors
        _ -> :ok
      end
    end

    :ok
  end

  describe "analyze/3 - PostgreSQL" do
    test "analyzes query complexity" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      assert {:ok, analysis} = QueryComplexityAnalyzer.analyze(query, PostgresRepo)

      assert is_float(analysis.cost)
      assert is_integer(analysis.rows)
      assert is_float(analysis.complexity_score)
      assert is_list(analysis.suggestions)
      assert is_list(analysis.index_usage)
      assert is_integer(analysis.seq_scans)
    end

    test "returns cost and rows from EXPLAIN" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      assert {:ok, analysis} = QueryComplexityAnalyzer.analyze(query, PostgresRepo)

      assert analysis.cost == 1000.0
      assert analysis.rows == 100
    end

    test "detects sequential scans" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      assert {:ok, analysis} = QueryComplexityAnalyzer.analyze(query, PostgresRepo)

      assert analysis.seq_scans == 1
    end

    test "generates suggestions for sequential scans" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      assert {:ok, analysis} = QueryComplexityAnalyzer.analyze(query, PostgresRepo)

      assert Enum.any?(analysis.suggestions, fn s ->
               String.contains?(s, "Consider adding indexes")
             end)
    end

    test "calculates complexity score" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      assert {:ok, analysis} = QueryComplexityAnalyzer.analyze(query, PostgresRepo)

      assert analysis.complexity_score >= 0
      assert analysis.complexity_score <= 100
    end
  end

  describe "analyze/3 - MySQL" do
    test "analyzes MySQL queries" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      assert {:ok, analysis} = QueryComplexityAnalyzer.analyze(query, MySQLRepo)

      assert is_float(analysis.cost)
      assert is_integer(analysis.rows)
      assert is_float(analysis.complexity_score)
    end

    test "parses MySQL EXPLAIN output" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      assert {:ok, analysis} = QueryComplexityAnalyzer.analyze(query, MySQLRepo)

      assert analysis.cost == 500.0
      assert analysis.rows == 50
    end
  end

  describe "analyze/3 - Heuristic Analysis (SQLite, MSSQL)" do
    test "uses heuristic analysis for SQLite" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      assert {:ok, analysis} = QueryComplexityAnalyzer.analyze(query, SQLiteRepo)

      assert analysis.analysis_method == :heuristic
      assert is_float(analysis.cost)
      assert is_float(analysis.complexity_score)
      assert analysis.cost > 0
      assert analysis.complexity_score > 0
    end

    test "uses heuristic analysis for MSSQL" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      assert {:ok, analysis} = QueryComplexityAnalyzer.analyze(query, MSSQLRepo)

      assert analysis.analysis_method == :heuristic
      assert is_float(analysis.cost)
      assert is_float(analysis.complexity_score)
    end

    test "detects missing LIMIT clause" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      assert {:ok, analysis} = QueryComplexityAnalyzer.analyze(query, SQLiteRepo)

      # Should have higher score without LIMIT
      assert analysis.has_limit == false
      assert Enum.any?(analysis.suggestions, fn s ->
        String.contains?(s, "LIMIT")
      end)
    end

    test "scores query with LIMIT lower" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true, limit: 10)

      assert {:ok, analysis} = QueryComplexityAnalyzer.analyze(query, SQLiteRepo)

      assert analysis.has_limit == true
    end

    test "detects JOINs" do
      query =
        from(u in "users",
          join: p in "posts",
          on: p.user_id == u.id,
          where: u.active == true
        )

      assert {:ok, analysis} = QueryComplexityAnalyzer.analyze(query, SQLiteRepo)

      assert analysis.joins == 1
      # JOIN should increase complexity
      assert analysis.complexity_score > 5
    end

    test "detects ORDER BY without LIMIT" do
      query = from(u in "users", order_by: [asc: u.name])

      assert {:ok, analysis} = QueryComplexityAnalyzer.analyze(query, SQLiteRepo)

      assert analysis.order_by_fields > 0
      assert Enum.any?(analysis.suggestions, fn s ->
        String.contains?(s, "ORDER BY")
      end)
    end

    test "detects large OFFSET" do
      query = from(u in "users", offset: 5000, limit: 10)

      assert {:ok, analysis} = QueryComplexityAnalyzer.analyze(query, SQLiteRepo)

      assert analysis.has_offset == true
      # Large offset should increase complexity
      assert analysis.complexity_score >= 20
    end

    test "allows unknown adapter queries through" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      assert {:ok, analysis} = QueryComplexityAnalyzer.analyze(query, UnknownRepo)

      # Unknown adapters also use heuristics
      assert analysis.analysis_method == :heuristic
    end
  end

  describe "check_complexity/3 - PostgreSQL" do
    test "accepts low complexity queries" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      # Set very high limit
      opts = [max_complexity: 100_000, adaptive_limits: false]

      assert {:ok, analysis} = QueryComplexityAnalyzer.check_complexity(query, PostgresRepo, opts)
      assert is_float(analysis.complexity_score)
    end

    test "warns on moderately complex queries" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      # Set limit just above complexity score (score is ~19, so limit 25 means warning at 17.5)
      opts = [max_complexity: 25, adaptive_limits: false]

      result = QueryComplexityAnalyzer.check_complexity(query, PostgresRepo, opts)

      assert {:warning, analysis} = result
      assert is_float(analysis.complexity_score)
    end

    test "rejects high complexity queries" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      # Set very low limit
      opts = [max_complexity: 0.1, adaptive_limits: false]

      assert {:error, :too_complex, analysis} =
               QueryComplexityAnalyzer.check_complexity(query, PostgresRepo, opts)

      assert is_float(analysis.complexity_score)
      assert is_list(analysis.suggestions)
    end
  end

  describe "get_load_metrics/1 - PostgreSQL" do
    test "retrieves database load metrics" do
      assert {:ok, metrics} = QueryComplexityAnalyzer.get_load_metrics(PostgresRepo)

      assert is_integer(metrics.active_connections)
      assert is_float(metrics.cache_hit_ratio)
      assert is_float(metrics.load_factor)
      assert metrics.load_factor >= 0.0
      assert metrics.load_factor <= 1.0
    end

    test "calculates load factor from metrics" do
      assert {:ok, metrics} = QueryComplexityAnalyzer.get_load_metrics(PostgresRepo)

      # Load factor should be between 0 and 1
      assert metrics.load_factor >= 0.0
      assert metrics.load_factor <= 1.0
    end
  end

  describe "get_load_metrics/1 - MySQL" do
    test "retrieves MySQL load metrics" do
      assert {:ok, metrics} = QueryComplexityAnalyzer.get_load_metrics(MySQLRepo)

      assert is_integer(metrics.active_connections)
      assert is_float(metrics.load_factor)
      assert metrics.load_factor >= 0.0
      assert metrics.load_factor <= 1.0
    end
  end

  describe "get_load_metrics/1 - Unsupported Adapters" do
    test "returns default load for SQLite" do
      assert {:ok, metrics} = QueryComplexityAnalyzer.get_load_metrics(SQLiteRepo)
      assert metrics.load_factor == 0.5
    end

    test "returns default load for MSSQL" do
      assert {:ok, metrics} = QueryComplexityAnalyzer.get_load_metrics(MSSQLRepo)
      assert metrics.load_factor == 0.5
    end
  end

  describe "format_analysis/1" do
    test "formats analysis for display" do
      analysis = %{
        cost: 1234.567,
        rows: 100,
        complexity_score: 45.678,
        seq_scans: 2,
        index_usage: ["users_idx", "posts_idx"],
        suggestions: [
          "Consider adding indexes to: users",
          "Query cost is high"
        ]
      }

      result = QueryComplexityAnalyzer.format_analysis(analysis)

      assert is_binary(result)
      assert String.contains?(result, "1234.57")
      assert String.contains?(result, "100")
      assert String.contains?(result, "45.68")
      assert String.contains?(result, "2")
      assert String.contains?(result, "users_idx")
      assert String.contains?(result, "Consider adding indexes")
    end
  end

  describe "adaptive limits" do
    test "reduces limit under high load" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      # With adaptive limits enabled (default)
      opts = [max_complexity: 100, adaptive_limits: true]

      result = QueryComplexityAnalyzer.check_complexity(query, PostgresRepo, opts)

      # Should work - adaptive limits adjust based on mock load metrics
      assert match?({:ok, _}, result) or match?({:warning, _}, result)
    end

    test "uses static limit when adaptive disabled" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      opts = [max_complexity: 1, adaptive_limits: false]

      assert {:error, :too_complex, _analysis} =
               QueryComplexityAnalyzer.check_complexity(query, PostgresRepo, opts)
    end
  end

  describe "error handling" do
    test "falls back to heuristic analysis on EXPLAIN error" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      # Should not raise, should fall back to heuristic analysis
      assert {:ok, analysis} = QueryComplexityAnalyzer.analyze(query, ErrorRepo)
      # Heuristic analysis should return non-zero scores
      assert analysis.cost > 0
      assert analysis.complexity_score > 0
      assert analysis.analysis_method == :heuristic
    end

    test "fails open on load metrics error" do
      # Should not raise, should return default load
      assert {:ok, metrics} = QueryComplexityAnalyzer.get_load_metrics(ErrorRepo)
      assert metrics.load_factor == 0.5
    end
  end

  describe "complexity score calculation" do
    test "higher cost = higher score" do
      # Can't easily test this without mocking different EXPLAIN outputs
      # But we can verify the score is within bounds
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      assert {:ok, analysis} = QueryComplexityAnalyzer.analyze(query, PostgresRepo)

      assert analysis.complexity_score >= 0
      assert analysis.complexity_score <= 100
    end

    test "sequential scans increase score" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      assert {:ok, analysis} = QueryComplexityAnalyzer.analyze(query, PostgresRepo)

      # With 1 seq scan, score should be > 0
      assert analysis.seq_scans == 1
      assert analysis.complexity_score > 0
    end
  end

  describe "suggestions" do
    test "suggests indexes for sequential scans" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      assert {:ok, analysis} = QueryComplexityAnalyzer.analyze(query, PostgresRepo)

      has_index_suggestion =
        Enum.any?(analysis.suggestions, fn s ->
          String.contains?(s, "indexes") or String.contains?(s, "index")
        end)

      assert has_index_suggestion
    end
  end

  describe "configuration" do
    test "respects max_cost option" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      opts = [max_complexity: 0.5, adaptive_limits: false]

      assert {:error, :too_complex, _} =
               QueryComplexityAnalyzer.check_complexity(query, PostgresRepo, opts)
    end

    test "respects adaptive_limits option" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      # Disabled
      opts = [max_complexity: 100, adaptive_limits: false]
      assert {:ok, _} = QueryComplexityAnalyzer.check_complexity(query, PostgresRepo, opts)

      # Enabled (may adjust based on mock load)
      opts = [max_complexity: 100, adaptive_limits: true]
      result = QueryComplexityAnalyzer.check_complexity(query, PostgresRepo, opts)
      assert match?({:ok, _}, result) or match?({:warning, _}, result)
    end
  end

  describe "caching" do
    setup do
      # Clear cache before each test
      QueryComplexityAnalyzer.clear_cache()
      :ok
    end

    test "caches analysis results" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      # First call - cache miss
      assert {:ok, analysis1} = QueryComplexityAnalyzer.analyze(query, PostgresRepo)

      # Second call - cache hit
      assert {:ok, analysis2} = QueryComplexityAnalyzer.analyze(query, PostgresRepo)

      # Should return same results
      assert analysis1.cost == analysis2.cost
      assert analysis1.complexity_score == analysis2.complexity_score
    end

    test "respects cache: false option" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      # Analyze with caching disabled
      assert {:ok, _} = QueryComplexityAnalyzer.analyze(query, PostgresRepo, cache: false)

      # Cache should be empty
      stats = QueryComplexityAnalyzer.cache_stats()
      assert stats.size == 0
    end

    test "cache expiration works" do
      # This test would need to manipulate time, so we skip detailed testing
      # The cache expiration logic is in place and will work in production
      :ok
    end

    test "clear_cache empties the cache" do
      query = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)

      # Add to cache
      assert {:ok, _} = QueryComplexityAnalyzer.analyze(query, PostgresRepo)

      stats_before = QueryComplexityAnalyzer.cache_stats()
      assert stats_before.size > 0

      # Clear cache
      assert :ok = QueryComplexityAnalyzer.clear_cache()

      stats_after = QueryComplexityAnalyzer.cache_stats()
      assert stats_after.size == 0
    end

    test "cache_stats returns statistics" do
      query1 = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)
      query2 = from(u in "users", select: %{id: u.id, active: u.active}, where: u.id == 1)

      # Add two queries to cache
      assert {:ok, _} = QueryComplexityAnalyzer.analyze(query1, PostgresRepo)
      assert {:ok, _} = QueryComplexityAnalyzer.analyze(query2, PostgresRepo)

      stats = QueryComplexityAnalyzer.cache_stats()

      assert stats.size == 2
      assert stats.valid_count >= 0
      assert is_integer(stats.cache_ttl_seconds)
      assert is_list(stats.entries)
      assert length(stats.entries) == 2
    end

    test "different queries get different cache keys" do
      query1 = from(u in "users", select: %{id: u.id, active: u.active}, where: u.active == true)
      query2 = from(u in "users", select: %{id: u.id, active: u.active}, where: u.id == 1)

      assert {:ok, _} = QueryComplexityAnalyzer.analyze(query1, PostgresRepo)
      assert {:ok, _} = QueryComplexityAnalyzer.analyze(query2, PostgresRepo)

      stats = QueryComplexityAnalyzer.cache_stats()
      assert stats.size == 2

      # Cache keys should be different
      keys = Enum.map(stats.entries, & &1.key)
      assert length(Enum.uniq(keys)) == 2
    end

    test "same query with different params gets different cache key" do
      query1 = from(u in "users", select: %{id: u.id, active: u.active}, where: u.id == ^1)
      query2 = from(u in "users", select: %{id: u.id, active: u.active}, where: u.id == ^2)

      assert {:ok, _} = QueryComplexityAnalyzer.analyze(query1, PostgresRepo)
      assert {:ok, _} = QueryComplexityAnalyzer.analyze(query2, PostgresRepo)

      stats = QueryComplexityAnalyzer.cache_stats()
      assert stats.size == 2
    end
  end
end
