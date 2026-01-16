defmodule GreenFairy.Middleware.QueryComplexityTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Middleware.QueryComplexity
  alias Absinthe.Resolution

  import Ecto.Query

  # Mock repos for testing
  defmodule PostgresRepo do
    def __adapter__, do: Ecto.Adapters.Postgres

    def query!(sql, _params) do
      cond do
        String.contains?(sql, "EXPLAIN") ->
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
          %{rows: [[10]]}

        String.contains?(sql, "pg_stat_database") and String.contains?(sql, "blks_hit") ->
          %{rows: [[0.95]]}

        String.contains?(sql, "pg_stat_database") and String.contains?(sql, "xact_commit") ->
          %{rows: [[1000]]}

        true ->
          %{rows: []}
      end
    end
  end

  defmodule MySQLRepo do
    def __adapter__, do: Ecto.Adapters.MyXQL

    def query!(sql, _params) do
      cond do
        String.contains?(sql, "EXPLAIN") ->
          %{
            rows: [
              [
                Jason.encode!(%{
                  "query_block" => %{
                    "cost_info" => %{"query_cost" => "500.0"},
                    "table" => %{"rows_examined_per_scan" => 50}
                  }
                })
              ]
            ]
          }

        String.contains?(sql, "Threads_connected") ->
          %{rows: [["Threads_connected", "20"]]}

        true ->
          %{rows: []}
      end
    end
  end

  defmodule SQLiteRepo do
    def __adapter__, do: Ecto.Adapters.SQLite3
  end

  defmodule MSSQLRepo do
    def __adapter__, do: Ecto.Adapters.Tds
  end

  defmodule UnknownRepo do
    def __adapter__, do: SomeUnknownAdapter
  end

  defmodule User do
    use Ecto.Schema

    schema "users" do
      field(:name, :string)
      field(:active, :boolean)
    end
  end

  describe "adapter support" do
    test "runs for PostgreSQL" do
      resolution = build_resolution(PostgresRepo)
      opts = [repo: PostgresRepo, max_complexity: 1000]

      result = QueryComplexity.call(resolution, opts)

      # Should not error, should process
      assert result.state == :unresolved
    end

    test "runs for MySQL" do
      resolution = build_resolution(MySQLRepo)
      opts = [repo: MySQLRepo, max_complexity: 1000]

      result = QueryComplexity.call(resolution, opts)

      assert result.state == :unresolved
    end

    test "skips for SQLite" do
      resolution = build_resolution(SQLiteRepo)
      opts = [repo: SQLiteRepo, max_complexity: 1000]

      result = QueryComplexity.call(resolution, opts)

      # Should pass through unchanged
      assert result == resolution
    end

    test "skips for MSSQL (Tds adapter)" do
      resolution = build_resolution(MSSQLRepo)
      opts = [repo: MSSQLRepo, max_complexity: 1000]

      result = QueryComplexity.call(resolution, opts)

      # Should pass through unchanged - MSSQL doesn't support EXPLAIN
      assert result == resolution
    end

    test "skips for unknown adapters" do
      resolution = build_resolution(UnknownRepo)
      opts = [repo: UnknownRepo, max_complexity: 1000]

      result = QueryComplexity.call(resolution, opts)

      # Should pass through unchanged - unknown adapter
      assert result == resolution
    end
  end

  describe "call/2 with query in middleware state" do
    test "analyzes query from middleware state" do
      query = from(u in User, where: u.active == true)
      resolution = build_resolution(PostgresRepo, cql_query: query)

      opts = [repo: PostgresRepo, max_complexity: 100_000]

      result = QueryComplexity.call(resolution, opts)

      # Should pass through (high limit)
      assert result.state == :unresolved
    end

    test "rejects complex query" do
      query = from(u in User, where: u.active == true)
      resolution = build_resolution(PostgresRepo, cql_query: query)

      # Very low limit
      opts = [repo: PostgresRepo, max_complexity: 0.1, adaptive_limits: false]

      result = QueryComplexity.call(resolution, opts)

      # Should be resolved with error
      assert result.state == :resolved
      assert {:error, error} = result.value
      assert error.message =~ "complexity"
      assert error.extensions.code == "QUERY_TOO_COMPLEX"
      assert is_float(error.extensions.complexity_score)
      assert is_list(error.extensions.suggestions)
    end
  end

  describe "call/2 with query in context" do
    test "analyzes query from context" do
      query = from(u in User, where: u.active == true)
      resolution = build_resolution_with_context(PostgresRepo, cql_query: query)

      opts = [repo: PostgresRepo, max_complexity: 100_000]

      result = QueryComplexity.call(resolution, opts)

      assert result.state == :unresolved
    end
  end

  describe "call/2 without query" do
    test "skips non-CQL queries" do
      resolution = build_resolution(PostgresRepo)
      opts = [repo: PostgresRepo, max_complexity: 1000]

      result = QueryComplexity.call(resolution, opts)

      # Should pass through - no CQL query to analyze
      assert result == resolution
    end
  end

  describe "call/2 with CQL arguments" do
    test "detects filter arguments and attempts to build query" do
      resolution = build_resolution_with_args(PostgresRepo, %{filter: %{name: "test"}})
      opts = [repo: PostgresRepo, max_complexity: 1000]

      result = QueryComplexity.call(resolution, opts)

      # Should attempt to analyze but pass through (no schema)
      assert result == resolution
    end

    test "detects order arguments and attempts to build query" do
      resolution = build_resolution_with_args(PostgresRepo, %{order: [%{field: :name, direction: :asc}]})
      opts = [repo: PostgresRepo, max_complexity: 1000]

      result = QueryComplexity.call(resolution, opts)

      # Should attempt to analyze but pass through (no schema)
      assert result == resolution
    end

    test "uses cql_schema from context when available" do
      resolution = build_resolution_with_schema(PostgresRepo, User, %{filter: %{name: "test"}})
      opts = [repo: PostgresRepo, max_complexity: 100_000]

      result = QueryComplexity.call(resolution, opts)

      # With schema in context, should build and analyze query
      assert result.state == :unresolved
    end
  end

  describe "call/2 with resolved state" do
    test "skips already resolved queries" do
      resolution = build_resolution(PostgresRepo)
      resolution = %{resolution | state: :resolved}

      opts = [repo: PostgresRepo, max_complexity: 1000]

      result = QueryComplexity.call(resolution, opts)

      # Should pass through unchanged
      assert result == resolution
    end
  end

  describe "enabled option" do
    test "respects enabled: false" do
      query = from(u in User, where: u.active == true)
      resolution = build_resolution(PostgresRepo, cql_query: query)

      # Very low limit but disabled
      opts = [repo: PostgresRepo, max_complexity: 0.1, enabled: false]

      result = QueryComplexity.call(resolution, opts)

      # Should pass through - checking disabled
      assert result == resolution
    end

    test "respects enabled: true" do
      query = from(u in User, where: u.active == true)
      resolution = build_resolution(PostgresRepo, cql_query: query)

      opts = [repo: PostgresRepo, max_complexity: 0.1, enabled: true, adaptive_limits: false]

      result = QueryComplexity.call(resolution, opts)

      # Should reject - checking enabled
      assert result.state == :resolved
      assert {:error, _} = result.value
    end
  end

  describe "repo configuration" do
    test "uses repo from opts" do
      query = from(u in User, where: u.active == true)
      resolution = build_resolution(PostgresRepo, cql_query: query)

      opts = [repo: PostgresRepo, max_complexity: 100_000]

      result = QueryComplexity.call(resolution, opts)

      assert result.state == :unresolved
    end

    test "skips when no repo configured" do
      query = from(u in User, where: u.active == true)
      resolution = build_resolution(PostgresRepo, cql_query: query)

      opts = [max_complexity: 1000]  # No repo

      result = QueryComplexity.call(resolution, opts)

      # Should pass through - no repo
      assert result == resolution
    end
  end

  describe "error message configuration" do
    test "uses custom error message" do
      query = from(u in User, where: u.active == true)
      resolution = build_resolution(PostgresRepo, cql_query: query)

      custom_message = "Your query is too expensive!"

      opts = [
        repo: PostgresRepo,
        max_complexity: 0.1,
        error_message: custom_message,
        adaptive_limits: false
      ]

      result = QueryComplexity.call(resolution, opts)

      assert result.state == :resolved
      assert {:error, error} = result.value
      assert error.message == custom_message
    end

    test "uses default error message when not provided" do
      query = from(u in User, where: u.active == true)
      resolution = build_resolution(PostgresRepo, cql_query: query)

      opts = [repo: PostgresRepo, max_complexity: 0.1, adaptive_limits: false]

      result = QueryComplexity.call(resolution, opts)

      assert result.state == :resolved
      assert {:error, error} = result.value
      assert error.message =~ "complexity"
    end
  end

  describe "adaptive limits" do
    test "applies adaptive limits when enabled" do
      query = from(u in User, where: u.active == true)
      resolution = build_resolution(PostgresRepo, cql_query: query)

      opts = [
        repo: PostgresRepo,
        max_complexity: 100,
        adaptive_limits: true
      ]

      result = QueryComplexity.call(resolution, opts)

      # With mocked load, should pass
      assert result.state == :unresolved
    end

    test "uses static limits when disabled" do
      query = from(u in User, where: u.active == true)
      resolution = build_resolution(PostgresRepo, cql_query: query)

      opts = [
        repo: PostgresRepo,
        max_complexity: 1,
        adaptive_limits: false
      ]

      result = QueryComplexity.call(resolution, opts)

      # Should reject with static low limit
      assert result.state == :resolved
      assert {:error, _} = result.value
    end
  end

  describe "error response format" do
    test "includes all required fields" do
      query = from(u in User, where: u.active == true)
      resolution = build_resolution(PostgresRepo, cql_query: query)

      opts = [repo: PostgresRepo, max_complexity: 0.1, adaptive_limits: false]

      result = QueryComplexity.call(resolution, opts)

      assert {:error, error} = result.value
      assert is_binary(error.message)
      assert error.extensions.code == "QUERY_TOO_COMPLEX"
      assert is_float(error.extensions.complexity_score)
      assert is_float(error.extensions.cost)
      assert is_list(error.extensions.suggestions)
    end
  end

  # Helper functions

  defp build_resolution(repo, state \\ []) do
    query = Keyword.get(state, :cql_query)

    private_state =
      if query do
        %{cql_query: query}
      else
        %{}
      end

    %Resolution{
      state: :unresolved,
      context: %{repo: repo},
      definition: %{
        schema_node: %{identifier: :users}
      },
      arguments: %{},
      private: private_state,
      value: nil
    }
  end

  defp build_resolution_with_context(repo, state \\ []) do
    query = Keyword.get(state, :cql_query)

    context =
      if query do
        %{repo: repo, cql_query: query}
      else
        %{repo: repo}
      end

    %Resolution{
      state: :unresolved,
      context: context,
      definition: %{
        schema_node: %{identifier: :users}
      },
      arguments: %{},
      private: %{},
      value: nil
    }
  end

  defp build_resolution_with_args(repo, arguments) do
    %Resolution{
      state: :unresolved,
      context: %{repo: repo},
      definition: %{
        schema_node: %{identifier: :users}
      },
      arguments: arguments,
      private: %{},
      value: nil
    }
  end

  defp build_resolution_with_schema(repo, schema, arguments) do
    %Resolution{
      state: :unresolved,
      context: %{repo: repo, cql_schema: schema},
      definition: %{
        schema_node: %{identifier: :users}
      },
      arguments: arguments,
      private: %{},
      value: nil
    }
  end
end
