defmodule GreenFairy.Middleware.QueryComplexity do
  @moduledoc """
  Absinthe middleware that automatically analyzes and limits query complexity.

  This middleware intercepts CQL queries before execution and uses EXPLAIN
  to estimate their complexity. Queries that exceed limits are rejected with
  helpful error messages.

  ## Adapter Support

  Query complexity analysis is supported on adapters that provide EXPLAIN:

  - ✅ **PostgreSQL** - Full support with detailed metrics
  - ✅ **MySQL** - Full support with cost analysis
  - ❌ **SQLite** - Not supported (limited EXPLAIN)
  - ❌ **MSSQL** - Not supported (different execution plan format)
  - ❌ **Elasticsearch** - Not supported (no EXPLAIN)

  For unsupported adapters, the middleware automatically skips complexity
  checking and allows queries through.

  ## Features

  1. **Automatic EXPLAIN Analysis** - Analyzes queries before execution (PostgreSQL, MySQL only)
  2. **Load-Based Limits** - Adjusts limits based on current database load
  3. **Helpful Errors** - Returns suggestions for optimization
  4. **Telemetry Integration** - Emits metrics for monitoring
  5. **Configurable** - Per-field or global configuration
  6. **Adapter-Aware** - Automatically detects adapter support

  ## Usage

  ### Per-Field Configuration

  ```elixir
  field :users, list_of(:user) do
    arg :filter, :cql_filter_user_input
    arg :order, :cql_order_user_input

    # Add middleware with custom limits
    middleware GreenFairy.Middleware.QueryComplexity, max_complexity: 5_000

    resolve &resolve_users/3
  end
  ```

  ### Global Configuration

  Add to your schema:

  ```elixir
  def middleware(middleware, _field, _object) do
    # Add query complexity checking to all CQL fields
    [GreenFairy.Middleware.QueryComplexity | middleware]
  end
  ```

  ### Conditional Configuration

  Only apply to specific types:

  ```elixir
  def middleware(middleware, field, %Absinthe.Type.Object{identifier: type})
      when type in [:query, :mutation] do

    # Check if field uses CQL
    if has_cql_args?(field) do
      [GreenFairy.Middleware.QueryComplexity | middleware]
    else
      middleware
    end
  end

  def middleware(middleware, _field, _object), do: middleware
  ```

  ## Configuration

  ### Per-Field Options

  ```elixir
  middleware GreenFairy.Middleware.QueryComplexity,
    max_complexity: 10_000,      # Maximum complexity score
    adaptive_limits: true,        # Adjust limits based on load
    warn_threshold: 0.7,          # Warn at 70% of limit
    enabled: true                 # Enable/disable checking
  ```

  ### Application Config

  ```elixir
  config :green_fairy, :query_complexity,
    # Global maximum complexity (can be overridden per-field)
    max_complexity: 10_000,

    # Enable adaptive limits based on database load
    adaptive_limits: true,

    # Threshold for warnings (0.0 - 1.0)
    warn_threshold: 0.7,

    # Enable/disable globally
    enabled: true,

    # Repo to use for analysis (required)
    repo: MyApp.Repo
  ```

  ## Error Responses

  When a query is rejected:

  ```json
  {
    "errors": [
      {
        "message": "Query complexity too high",
        "extensions": {
          "code": "QUERY_TOO_COMPLEX",
          "complexity_score": 85.3,
          "limit": 50.0,
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

  When a query triggers a warning (logged but not rejected):

  ```
  [warning] Query complexity high: score=72.5, limit=100, field=users
  Suggestions:
    - Consider adding indexes to: posts
  ```

  ## Telemetry Events

  This middleware emits the same telemetry events as `QueryComplexityAnalyzer`:

  - `[:green_fairy, :query_complexity, :query_accepted]`
  - `[:green_fairy, :query_complexity, :query_warning]`
  - `[:green_fairy, :query_complexity, :query_rejected]`

  Subscribe to events:

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

  def handle_query_complexity_event(event_name, measurements, metadata, _config) do
    # Log or send to monitoring system
    Logger.info("Query complexity event: \#{inspect(event_name)}")
    Logger.info("Measurements: \#{inspect(measurements)}")
  end
  ```

  ## Performance Considerations

  - EXPLAIN queries are fast (< 10ms typically)
  - Results can be cached for identical queries
  - Minimal overhead for simple queries
  - Load metrics are sampled periodically (not per-query)

  ## Disabling for Development

  Disable in dev environment:

  ```elixir
  # config/dev.exs
  config :green_fairy, :query_complexity,
    enabled: false
  ```

  Or conditionally:

  ```elixir
  def middleware(middleware, _field, _object) do
    if Application.get_env(:green_fairy, :check_complexity, false) do
      [GreenFairy.Middleware.QueryComplexity | middleware]
    else
      middleware
    end
  end
  ```
  """

  @behaviour Absinthe.Middleware

  require Logger
  alias GreenFairy.CQL.QueryComplexityAnalyzer
  alias Absinthe.Resolution

  @impl true
  def call(%Resolution{state: :unresolved} = resolution, opts) do
    # Check if complexity checking is enabled
    if enabled?(opts) do
      check_complexity(resolution, opts)
    else
      resolution
    end
  end

  def call(resolution, _opts), do: resolution

  # === Complexity Checking ===

  defp check_complexity(resolution, opts) do
    # Extract repo from config or opts
    repo = get_repo(opts)

    if is_nil(repo) do
      Logger.warning("QueryComplexity middleware: No repo configured, skipping check")
      resolution
    else
      # Check if adapter supports complexity analysis
      if supports_complexity_analysis?(repo) do
        # Continue with analysis
        do_check_complexity(resolution, repo, opts)
      else
        Logger.debug("QueryComplexity middleware: Adapter does not support EXPLAIN, skipping check")
        resolution
      end
    end
  end

  defp do_check_complexity(resolution, repo, opts) do

    # Get the query from resolution context
    # The query would be built by the CQL resolver
    case extract_query(resolution) do
      {:ok, query} ->
        analyze_and_check(resolution, query, repo, opts)

      {:error, :no_query} ->
        # Not a CQL query, skip complexity check
        resolution

      {:error, reason} ->
        Logger.warning("QueryComplexity middleware: Failed to extract query: #{inspect(reason)}")
        resolution
    end
  end

  # === Adapter Support ===

  defp supports_complexity_analysis?(repo) do
    adapter = repo.__adapter__()

    case adapter do
      # Supported adapters with EXPLAIN
      Ecto.Adapters.Postgres -> true
      Ecto.Adapters.MyXQL -> true

      # Unsupported adapters
      Ecto.Adapters.SQLite3 -> false
      Ecto.Adapters.Tds -> false  # MSSQL

      # Unknown adapter
      _ ->
        Logger.debug("QueryComplexity: Unknown adapter #{inspect(adapter)}, skipping check")
        false
    end
  end

  defp analyze_and_check(resolution, query, repo, opts) do
    result = case QueryComplexityAnalyzer.check_complexity(query, repo, opts) do
      {:ok, analysis} ->
        # Query accepted
        log_accepted(resolution, analysis)
        resolution

      {:warning, analysis} ->
        # Query accepted but with warning
        log_warning(resolution, analysis)
        resolution

      {:error, :too_complex, analysis} ->
        # Query rejected
        log_rejected(resolution, analysis)
        rejected_resolution = reject_query(resolution, analysis, opts)
        Logger.debug("After reject_query - state: #{rejected_resolution.state}, value: #{inspect(rejected_resolution.value)}")
        rejected_resolution

      other ->
        Logger.error("Unexpected check_complexity result: #{inspect(other)}")
        resolution
    end

    Logger.debug("analyze_and_check returning - state: #{result.state}, value: #{inspect(result.value)}")
    result
  rescue
    e ->
      Logger.error("QueryComplexity middleware error caught in rescue: #{inspect(e)}")
      Logger.error(Exception.format(:error, e, __STACKTRACE__))
      # Fail open - allow query on error
      resolution
  end

  # === Query Extraction ===

  defp extract_query(resolution) do
    # Try to extract Ecto query from resolution
    # The query would typically be in the resolution context or private state
    cond do
      # Check if there's a query in the private state (Absinthe 1.9+)
      is_map(resolution.private) and Map.has_key?(resolution.private, :cql_query) ->
        {:ok, resolution.private.cql_query}

      # Check resolution context
      is_map(resolution.context) and Map.has_key?(resolution.context, :cql_query) ->
        {:ok, resolution.context.cql_query}

      # Check if resolver will build a query
      # We need to check arguments to see if CQL is being used
      has_cql_arguments?(resolution) ->
        # Build the query to analyze it
        build_query_from_resolution(resolution)

      true ->
        {:error, :no_query}
    end
  end

  defp has_cql_arguments?(resolution) do
    args = resolution.arguments
    Map.has_key?(args, :filter) or Map.has_key?(args, :order)
  end

  defp build_query_from_resolution(resolution) do
    # Try to extract schema from field definition
    with {:ok, schema} <- get_schema_from_resolution(resolution),
         {:ok, query} <- build_base_query(schema, resolution) do
      {:ok, query}
    else
      error -> error
    end
  end

  defp get_schema_from_resolution(resolution) do
    # Get the schema from the field definition
    # This is stored in the field's middleware configuration
    case resolution.definition.schema_node.identifier do
      identifier when is_atom(identifier) ->
        # Try to find the Ecto schema
        # Convention: GraphQL type :user -> MyApp.Accounts.User
        case get_schema_from_identifier(identifier, resolution) do
          nil -> {:error, :no_schema}
          schema -> {:ok, schema}
        end

      _ ->
        {:error, :no_schema}
    end
  end

  defp get_schema_from_identifier(_identifier, resolution) do
    # Check if schema is provided in context
    case resolution.context do
      %{cql_schema: schema} -> schema
      _ -> nil
    end
  end

  defp build_base_query(schema, _resolution) do
    import Ecto.Query
    {:ok, from(s in schema, as: :root)}
  end

  # === Logging ===

  defp log_accepted(resolution, analysis) do
    field_name = resolution.definition.schema_node.identifier

    Logger.debug("""
    Query complexity check passed:
      Field: #{field_name}
      Score: #{Float.round(analysis.complexity_score, 2)}/100
      Cost: #{Float.round(analysis.cost, 2)}
    """)
  end

  defp log_warning(resolution, analysis) do
    field_name = resolution.definition.schema_node.identifier

    Logger.warning("""
    Query complexity warning:
      Field: #{field_name}
      Score: #{Float.round(analysis.complexity_score, 2)}/100
      Cost: #{Float.round(analysis.cost, 2)}
      Suggestions:
    #{format_suggestions(analysis.suggestions)}
    """)
  end

  defp log_rejected(resolution, analysis) do
    field_name = resolution.definition.schema_node.identifier

    Logger.warning("""
    Query complexity rejected:
      Field: #{field_name}
      Score: #{Float.round(analysis.complexity_score, 2)}/100
      Cost: #{Float.round(analysis.cost, 2)}
      Suggestions:
    #{format_suggestions(analysis.suggestions)}
    """)
  end

  defp format_suggestions(suggestions) do
    suggestions
    |> Enum.map(fn s -> "    - #{s}" end)
    |> Enum.join("\n")
  end

  # === Error Response ===

  defp reject_query(resolution, analysis, opts) do
    error_message = get_error_message(opts)

    error = %{
      message: error_message,
      extensions: %{
        code: "QUERY_TOO_COMPLEX",
        complexity_score: Map.get(analysis, :complexity_score, 0.0),
        cost: Map.get(analysis, :cost, 0.0),
        suggestions: Map.get(analysis, :suggestions, [])
      }
    }

    # Absinthe middleware should return %{resolution | state: :resolved, value: {:error, error}}
    %{resolution | state: :resolved, value: {:error, error}}
  end

  # === Configuration ===

  defp enabled?(opts) do
    Keyword.get(opts, :enabled, get_config(:enabled, true))
  end

  defp get_repo(opts) do
    Keyword.get(opts, :repo, get_config(:repo, nil))
  end

  defp get_error_message(opts) do
    Keyword.get(
      opts,
      :error_message,
      "Query complexity too high. Please add filters to reduce the result set."
    )
  end

  defp get_config(key, default) do
    Application.get_env(:green_fairy, :query_complexity, [])
    |> Keyword.get(key, default)
  end
end
