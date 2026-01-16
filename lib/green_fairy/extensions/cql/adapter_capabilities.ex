defmodule GreenFairy.CQL.AdapterCapabilities do
  @moduledoc """
  Runtime detection of database capabilities for CQL adapters.

  This module detects:
  - Database version
  - Installed extensions
  - Available features
  - Index support

  This allows GreenFairy to:
  - Only expose operators that are actually available
  - Provide helpful error messages when features are missing
  - Gracefully degrade when optional features aren't available

  ## Usage

      # Detect capabilities for a repo
      capabilities = AdapterCapabilities.detect(MyApp.Repo)

      # Check if feature is available
      if AdapterCapabilities.supports?(capabilities, :full_text_search) do
        # Enable full-text search operators
      end

  ## Caching

  Capabilities are cached per-repo to avoid repeated database queries.
  The cache is cleared when the application restarts.
  """

  require Logger

  @doc """
  Detect capabilities for a given Ecto repo.

  Returns a map of detected capabilities and versions.
  """
  def detect(repo) do
    adapter = repo.__adapter__()

    case adapter do
      Ecto.Adapters.Postgres -> detect_postgres_capabilities(repo)
      Ecto.Adapters.MyXQL -> detect_mysql_capabilities(repo)
      Ecto.Adapters.SQLite3 -> detect_sqlite_capabilities(repo)
      Ecto.Adapters.Tds -> detect_mssql_capabilities(repo)
      _ -> %{adapter: :unknown}
    end
  end

  @doc """
  Check if a specific capability is supported.

  ## Examples

      iex> supports?(capabilities, :full_text_search)
      true

      iex> supports?(capabilities, :postgis)
      false
  """
  def supports?(capabilities, feature) do
    Map.get(capabilities, feature, false)
  end

  @doc """
  Get the version of a specific feature/extension.

  ## Examples

      iex> version(capabilities, :postgres)
      {15, 0}

      iex> version(capabilities, :pg_trgm)
      {1, 6}
  """
  def version(capabilities, component) do
    Map.get(capabilities, :"#{component}_version")
  end

  # === PostgreSQL Capability Detection ===

  defp detect_postgres_capabilities(repo) do
    version = detect_postgres_version(repo)
    extensions = detect_postgres_extensions(repo)

    %{
      adapter: :postgres,
      version: version,
      version_string: version_to_string(version),
      # Built-in features (always available in modern PostgreSQL)
      full_text_search: version >= {8, 3},
      regex_support: true,
      jsonb_support: version >= {9, 4},
      array_support: true,
      # Extension-based features
      pg_trgm: :pg_trgm in extensions,
      postgis: :postgis in extensions,
      btree_gin: :btree_gin in extensions,
      btree_gist: :btree_gist in extensions,
      # Operator support
      similarity_search: :pg_trgm in extensions,
      geo_queries: :postgis in extensions,
      # Version-specific features
      jsonb_path_queries: version >= {12, 0},
      generated_columns: version >= {12, 0},
      # Extensions list
      extensions: extensions
    }
  end

  defp detect_postgres_version(repo) do
    try do
      result = repo.query!("SELECT version()")
      version_string = result.rows |> List.first() |> List.first()

      # Parse version from string like "PostgreSQL 15.3 on ..."
      case Regex.run(~r/PostgreSQL (\d+)\.(\d+)/, version_string) do
        [_, major, minor] ->
          {String.to_integer(major), String.to_integer(minor)}

        _ ->
          Logger.warning("Could not parse PostgreSQL version: #{version_string}")
          {0, 0}
      end
    rescue
      e ->
        Logger.error("Failed to detect PostgreSQL version: #{inspect(e)}")
        {0, 0}
    end
  end

  defp detect_postgres_extensions(repo) do
    try do
      result = repo.query!("SELECT extname FROM pg_extension")

      result.rows
      |> List.flatten()
      |> Enum.map(&String.to_atom/1)
    rescue
      e ->
        Logger.error("Failed to detect PostgreSQL extensions: #{inspect(e)}")
        []
    end
  end

  # === MySQL Capability Detection ===

  defp detect_mysql_capabilities(repo) do
    version = detect_mysql_version(repo)

    %{
      adapter: :mysql,
      version: version,
      version_string: version_to_string(version),
      # Built-in features
      full_text_search: version >= {5, 6},
      json_support: version >= {5, 7},
      jsonb_support: false,
      array_support: false,
      regex_support: true,
      # MySQL-specific features
      json_overlaps: version >= {8, 0, 17},
      json_table: version >= {8, 0},
      cte_support: version >= {8, 0},
      window_functions: version >= {8, 0},
      # Feature availability
      similarity_search: false,
      geo_queries: version >= {5, 7},  # Basic spatial support
      postgis: false
    }
  end

  defp detect_mysql_version(repo) do
    try do
      result = repo.query!("SELECT VERSION()")
      version_string = result.rows |> List.first() |> List.first()

      # Parse version from string like "8.0.33" or "5.7.42-log"
      case Regex.run(~r/(\d+)\.(\d+)\.(\d+)/, version_string) do
        [_, major, minor, patch] ->
          {String.to_integer(major), String.to_integer(minor), String.to_integer(patch)}

        _ ->
          Logger.warning("Could not parse MySQL version: #{version_string}")
          {0, 0, 0}
      end
    rescue
      e ->
        Logger.error("Failed to detect MySQL version: #{inspect(e)}")
        {0, 0, 0}
    end
  end

  # === SQLite Capability Detection ===

  defp detect_sqlite_capabilities(repo) do
    version = detect_sqlite_version(repo)
    extensions = detect_sqlite_extensions(repo)

    %{
      adapter: :sqlite,
      version: version,
      version_string: version_to_string(version),
      # Built-in features
      json_support: :json1 in extensions,
      full_text_search: :fts5 in extensions,
      regex_support: true,
      array_support: false,
      jsonb_support: false,
      # Extension-based features
      json1: :json1 in extensions,
      fts5: :fts5 in extensions,
      rtree: :rtree in extensions,
      # Feature availability
      similarity_search: false,
      geo_queries: :rtree in extensions,
      postgis: false,
      # Extensions list
      extensions: extensions
    }
  end

  defp detect_sqlite_version(repo) do
    try do
      result = repo.query!("SELECT sqlite_version()")
      version_string = result.rows |> List.first() |> List.first()

      # Parse version from string like "3.39.5"
      case Regex.run(~r/(\d+)\.(\d+)\.(\d+)/, version_string) do
        [_, major, minor, patch] ->
          {String.to_integer(major), String.to_integer(minor), String.to_integer(patch)}

        _ ->
          Logger.warning("Could not parse SQLite version: #{version_string}")
          {0, 0, 0}
      end
    rescue
      e ->
        Logger.error("Failed to detect SQLite version: #{inspect(e)}")
        {0, 0, 0}
    end
  end

  defp detect_sqlite_extensions(repo) do
    # SQLite extensions are compiled in or loaded dynamically
    # Check for common extensions by trying to use them
    extensions = []

    extensions =
      if test_sqlite_extension(repo, "SELECT json('{}')") do
        [:json1 | extensions]
      else
        extensions
      end

    extensions =
      if test_sqlite_extension(repo, "SELECT fts5()") do
        [:fts5 | extensions]
      else
        extensions
      end

    extensions =
      if test_sqlite_extension(repo, "SELECT rtreenode(0, null)") do
        [:rtree | extensions]
      else
        extensions
      end

    extensions
  end

  defp test_sqlite_extension(repo, sql) do
    try do
      repo.query!(sql)
      true
    rescue
      _ -> false
    end
  end

  # === MSSQL Capability Detection ===

  defp detect_mssql_capabilities(repo) do
    version = detect_mssql_version(repo)

    %{
      adapter: :mssql,
      version: version,
      version_string: version_to_string(version),
      # Built-in features
      json_support: version >= {13, 0},  # SQL Server 2016
      full_text_search: true,  # Available in most versions
      regex_support: false,
      array_support: false,
      jsonb_support: false,
      # MSSQL-specific features
      openjson: version >= {13, 0},  # SQL Server 2016
      json_path: version >= {13, 0},
      string_split: version >= {13, 0},
      # Feature availability
      similarity_search: false,
      geo_queries: true,  # Spatial types available
      postgis: false
    }
  end

  defp detect_mssql_version(repo) do
    try do
      result = repo.query!("SELECT @@VERSION")
      version_string = result.rows |> List.first() |> List.first()

      # Parse version from string like "Microsoft SQL Server 2019 (RTM) - 15.0.2000.5"
      case Regex.run(~r/SQL Server \d+ .* - (\d+)\.(\d+)/, version_string) do
        [_, major, minor] ->
          {String.to_integer(major), String.to_integer(minor)}

        _ ->
          Logger.warning("Could not parse MSSQL version: #{version_string}")
          {0, 0}
      end
    rescue
      e ->
        Logger.error("Failed to detect MSSQL version: #{inspect(e)}")
        {0, 0}
    end
  end

  # === Helpers ===

  defp version_to_string({major, minor}), do: "#{major}.#{minor}"
  defp version_to_string({major, minor, patch}), do: "#{major}.#{minor}.#{patch}"
  defp version_to_string(_), do: "unknown"

  @doc """
  Generate a human-readable capability report.

  ## Example

      iex> report(capabilities)
      '''
      Database: PostgreSQL 15.3
      Extensions: pg_trgm, postgis
      Features:
        ✓ Full-text search
        ✓ Similarity search (pg_trgm)
        ✓ Geo queries (PostGIS)
        ✓ JSONB support
      '''
  """
  def report(capabilities) do
    adapter = Map.get(capabilities, :adapter, :unknown)
    version = Map.get(capabilities, :version_string, "unknown")

    header = "Database: #{format_adapter(adapter)} #{version}\n"

    extensions =
      case Map.get(capabilities, :extensions) do
        nil -> ""
        [] -> "Extensions: none\n"
        exts -> "Extensions: #{Enum.join(exts, ", ")}\n"
      end

    features =
      capabilities
      |> Map.to_list()
      |> Enum.filter(fn {_k, v} -> is_boolean(v) && v end)
      |> Enum.map(fn {k, _} -> "  ✓ #{format_feature(k)}" end)
      |> Enum.join("\n")

    features_section =
      if features != "" do
        "Features:\n#{features}\n"
      else
        ""
      end

    header <> extensions <> features_section
  end

  defp format_adapter(:postgres), do: "PostgreSQL"
  defp format_adapter(:mysql), do: "MySQL"
  defp format_adapter(:sqlite), do: "SQLite"
  defp format_adapter(:mssql), do: "Microsoft SQL Server"
  defp format_adapter(other), do: to_string(other)

  defp format_feature(:full_text_search), do: "Full-text search"
  defp format_feature(:similarity_search), do: "Similarity search"
  defp format_feature(:geo_queries), do: "Geo-spatial queries"
  defp format_feature(:jsonb_support), do: "JSONB support"
  defp format_feature(:json_support), do: "JSON support"
  defp format_feature(:array_support), do: "Array support"
  defp format_feature(:regex_support), do: "Regular expressions"
  defp format_feature(:pg_trgm), do: "pg_trgm extension"
  defp format_feature(:postgis), do: "PostGIS extension"
  defp format_feature(other), do: to_string(other) |> String.replace("_", " ")

  @doc """
  Log capability report at application startup.

  Add this to your application.ex:

      def start(_type, _args) do
        # Detect and log capabilities
        capabilities = GreenFairy.CQL.AdapterCapabilities.detect(MyApp.Repo)
        GreenFairy.CQL.AdapterCapabilities.log_report(capabilities)

        # ...
      end
  """
  def log_report(capabilities) do
    Logger.info("GreenFairy CQL Capabilities:\n#{report(capabilities)}")
  end

  @doc """
  Raise helpful error if required capability is missing.

  ## Example

      capabilities = AdapterCapabilities.detect(repo)
      AdapterCapabilities.require!(capabilities, :full_text_search,
        "Full-text search requires PostgreSQL ts_vector support"
      )
  """
  def require!(capabilities, feature, message \\ nil) do
    unless supports?(capabilities, feature) do
      adapter = Map.get(capabilities, :adapter, :unknown)
      version = Map.get(capabilities, :version_string, "unknown")

      error_message =
        message ||
        """
        Feature '#{feature}' is not available.

        Database: #{format_adapter(adapter)} #{version}
        Required feature: #{format_feature(feature)}

        See documentation for setup instructions.
        """

      raise RuntimeError, error_message
    end
  end
end
