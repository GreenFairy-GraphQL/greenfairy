defmodule GreenFairy.CQL.Adapter do
  @moduledoc """
  Behavior for CQL database adapters.

  Each database adapter (PostgreSQL, MySQL, SQLite, MSSQL, etc.) implements
  this behavior to provide adapter-specific capabilities and metadata.

  ## Architecture

  Adapters are thin wrappers that:
  1. Declare database capabilities (sort directions, geo support, etc.)
  2. Delegate operator implementations to scalar modules
  3. Provide adapter-specific metadata for schema generation

  Scalar modules own all operator logic - adapters just coordinate.

  ## Usage

  Create an adapter module:

      defmodule MyApp.CQL.PostgresAdapter do
        @behaviour GreenFairy.CQL.Adapter

        @impl true
        def sort_directions do
          [:asc, :desc, :asc_nulls_first, :asc_nulls_last,
           :desc_nulls_first, :desc_nulls_last]
        end

        @impl true
        def apply_operator(query, field, operator, value, opts) do
          field_type = Keyword.get(opts, :field_type)
          scalar = GreenFairy.CQL.ScalarMapper.scalar_for(field_type)
          scalar.apply_operator(query, field, operator, value, :postgres, opts)
        end
      end

  Configure in your schema or application:

      config :green_fairy, :cql_adapter, MyApp.CQL.PostgresAdapter

  ## Adapter Selection

  GreenFairy automatically detects the adapter from your Ecto repo:
  - `Ecto.Adapters.Postgres` → `GreenFairy.CQL.Adapters.Postgres`
  - `Ecto.Adapters.MyXQL` → `GreenFairy.CQL.Adapters.MySQL`
  - `Ecto.Adapters.SQLite3` → `GreenFairy.CQL.Adapters.SQLite`
  - Custom → Manually configure

  """

  @doc """
  Returns the operator input type definitions for this adapter.

  This defines the GraphQL schema for CQL operators. The adapter declares
  what operator input types exist and which operators each type supports.

  ## Returns

  Map of `%{identifier => {operators, scalar_type, description}}` where:
  - `identifier` - GraphQL input type name (e.g., `:cql_op_string_input`)
  - `operators` - List of operator atoms (e.g., `[:_eq, :_neq, :_like]`)
  - `scalar_type` - GraphQL scalar type for values (e.g., `:string`, `:integer`)
  - `description` - Documentation string

  ## Examples

      def operator_inputs() do
        %{
          cql_op_string_input: {
            [:_eq, :_neq, :_like, :_ilike, :_in, :_nin, :_is_null],
            :string,
            "PostgreSQL string operators"
          },
          cql_op_arr_string_input: {
            [:_includes, :_excludes, :_includes_all, :_excludes_all, :_includes_any, :_excludes_any, :_is_empty, :_is_null],
            :string,
            "PostgreSQL array operators for strings"
          }
        }
      end

  """
  @callback operator_inputs() :: %{
              atom() => {operators :: [atom()], scalar_type :: atom(), description :: String.t()}
            }

  @doc """
  Returns the list of operators supported by this adapter for a given field category.

  ## Parameters

  - `category` - The field category (`:scalar`, `:array`, `:json`, etc.)
  - `field_type` - The specific field type (`:string`, `:integer`, `:enum`, etc.)

  ## Returns

  List of operator atoms (e.g., `[:_eq, :_neq, :_gt, :_includes]`)

  ## Examples

      supported_operators(:scalar, :string)
      # => [:_eq, :_neq, :_gt, :_gte, :_lt, :_lte, :_like, :_ilike, :_in, :_nin, :_is_null]

      supported_operators(:array, :string)
      # => [:_includes, :_excludes, :_includes_all, :_includes_any, :_is_empty, :_is_null]

  """
  @callback supported_operators(category :: atom(), field_type :: atom()) :: [atom()]

  @doc """
  Applies a database-specific operator to an Ecto query.

  ## Parameters

  - `query` - Base Ecto query
  - `field` - Field name (atom)
  - `operator` - Operator atom (e.g., `:_includes`)
  - `value` - Filter value
  - `opts` - Options including:
    - `:binding` - Named binding for association queries (optional)
    - `:field_type` - Field type for type-specific handling
    - `:cast_type` - Type to cast values to

  ## Returns

  Modified Ecto query with the operator applied.

  ## Examples

      # Base table query
      apply_operator(query, :tags, :_includes, "premium", [])

      # Association query
      apply_operator(query, :status, :_eq, "active", binding: :posts_assoc)

  """
  @callback apply_operator(
              query :: Ecto.Query.t(),
              field :: atom(),
              operator :: atom(),
              value :: any(),
              opts :: keyword()
            ) :: Ecto.Query.t()

  @doc """
  Returns metadata about operator capabilities and requirements.

  Allows adapters to declare special requirements or limitations.

  ## Returns

  Map with optional keys:
  - `:array_operators_require_type_cast` - Boolean, whether array ops need explicit casts
  - `:supports_json_operators` - Boolean
  - `:supports_full_text_search` - Boolean
  - `:max_in_clause_items` - Integer, max items in _in operator (nil = unlimited)

  """
  @callback capabilities() :: map()

  @doc """
  Returns the list of sort direction values supported by this adapter.

  Each adapter declares which sort directions it supports. This prevents
  PostgreSQL-specific features (like NULLS FIRST/LAST) from appearing in
  schemas for databases that don't support them.

  ## Returns

  List of atoms representing supported sort directions.

  ## Examples

      # PostgreSQL - full support
      def sort_directions() do
        [:asc, :desc, :asc_nulls_first, :asc_nulls_last,
         :desc_nulls_first, :desc_nulls_last]
      end

      # MySQL - basic support
      def sort_directions() do
        [:asc, :desc]
      end

      # Elasticsearch - with scoring
      def sort_directions() do
        [:asc, :desc, :_score]
      end

  """
  @callback sort_directions() :: [atom()]

  @doc """
  Returns the sort direction enum identifier for this adapter.

  This identifier is used to generate adapter/repo-specific sort direction enums.
  The default repo uses `:cql_sort_direction` (no prefix), while non-default
  repos are namespaced (e.g., `:cql_analytics_sort_direction`).

  ## Parameters

  - `repo_namespace` - The repository namespace atom (e.g., `:analytics`, `:search`) or `nil` for default

  ## Returns

  Atom representing the sort direction enum identifier.

  ## Examples

      # Default repo - no namespace
      def sort_direction_enum(nil), do: :cql_sort_direction

      # Non-default repo - with namespace
      def sort_direction_enum(:analytics), do: :cql_analytics_sort_direction
      def sort_direction_enum(:search), do: :cql_search_sort_direction

  """
  @callback sort_direction_enum(repo_namespace :: atom() | nil) :: atom()

  @doc """
  Returns the CQL operator input type identifier for a given Ecto/adapter type.

  This allows adapters to map their internal types to CQL operator types.
  Different adapters may map the same Ecto type differently based on
  their capabilities.

  ## Parameters

  - `ecto_type` - Ecto type (e.g., `:string`, `{:array, :string}`, `{:parameterized, Ecto.Enum, _}`)

  ## Returns

  Atom representing the CQL operator input type identifier, or `nil` if not filterable.

  ## Examples

      # PostgreSQL with native arrays
      def operator_type_for({:array, :string}), do: :cql_op_string_array_input

      # MySQL with JSON arrays
      def operator_type_for({:array, :string}), do: :cql_op_string_array_input

      # Adapter that doesn't support arrays
      def operator_type_for({:array, _}), do: nil

  """
  @callback operator_type_for(ecto_type :: any()) :: atom() | nil

  @doc """
  Returns whether this adapter supports geo/location-based ordering.

  ## Examples

      def supports_geo_ordering?(), do: true   # PostgreSQL with PostGIS
      def supports_geo_ordering?(), do: false  # MySQL without spatial extensions

  """
  @callback supports_geo_ordering?() :: boolean()

  @doc """
  Returns whether this adapter supports priority-based enum ordering.

  Priority ordering allows specifying custom sort order for enum values
  (e.g., sort status by [pending, active, completed] instead of alphabetically).

  ## Examples

      def supports_priority_ordering?(), do: true   # PostgreSQL with CASE
      def supports_priority_ordering?(), do: false  # SQLite (limited)

  """
  @callback supports_priority_ordering?() :: boolean()

  @optional_callbacks [capabilities: 0]

  # Default implementation
  def capabilities(_adapter), do: %{}

  @doc """
  Detects the appropriate CQL adapter from an Ecto repo module.

  ## Supported Adapters

  - `Ecto.Adapters.Postgres` → `GreenFairy.CQL.Adapters.Postgres`
  - `Ecto.Adapters.MyXQL` → `GreenFairy.CQL.Adapters.MySQL`
  - `Ecto.Adapters.SQLite3` → `GreenFairy.CQL.Adapters.SQLite`
  - `Ecto.Adapters.Tds` → `GreenFairy.CQL.Adapters.MSSQL`
  - `Ecto.Adapters.ClickHouse` / `Ch` → `GreenFairy.CQL.Adapters.ClickHouse`
  - Unknown → `GreenFairy.CQL.Adapters.Ecto` (generic fallback)

  ## Examples

      detect_adapter(MyApp.Repo)
      # => GreenFairy.CQL.Adapters.Postgres

      detect_adapter(MyApp.ClickHouseRepo)
      # => GreenFairy.CQL.Adapters.ClickHouse

      detect_adapter(MyApp.UnknownRepo)
      # => GreenFairy.CQL.Adapters.Ecto (generic fallback)

      detect_adapter(MyApp.Repo, default: MyCustomAdapter)
      # => MyCustomAdapter (if detection fails)

  """
  def detect_adapter(repo_module, opts \\ []) do
    # Check application config first
    case Application.get_env(:green_fairy, :cql_adapter) do
      nil ->
        detect_from_repo(repo_module, opts)

      configured ->
        configured
    end
  end

  # Try to detect adapter from repo module
  defp detect_from_repo(nil, opts) do
    Keyword.get(opts, :default, GreenFairy.CQL.Adapters.Ecto)
  end

  defp detect_from_repo(repo_module, opts) when is_atom(repo_module) do
    # Check if module exists and has __adapter__/0
    # Use :erlang.module_loaded/1 for already-compiled modules (e.g., test modules)
    # and Code.ensure_loaded/1 as fallback for beam files
    cond do
      # Module already loaded in VM (works for inline-compiled test modules)
      :erlang.module_loaded(repo_module) and function_exported?(repo_module, :__adapter__, 0) ->
        adapter_module = repo_module.__adapter__()
        map_ecto_adapter(adapter_module, opts)

      # Try to load from beam file
      match?({:module, _}, Code.ensure_loaded(repo_module)) and
          function_exported?(repo_module, :__adapter__, 0) ->
        adapter_module = repo_module.__adapter__()
        map_ecto_adapter(adapter_module, opts)

      # Module doesn't exist or doesn't have __adapter__/0
      true ->
        Keyword.get(opts, :default, GreenFairy.CQL.Adapters.Ecto)
    end
  end

  defp detect_from_repo(_repo_module, opts) do
    Keyword.get(opts, :default, GreenFairy.CQL.Adapters.Ecto)
  end

  # Map Ecto adapter modules to GreenFairy CQL adapters
  defp map_ecto_adapter(adapter_module, opts) do
    adapter_name = to_string(adapter_module)

    cond do
      adapter_module == Ecto.Adapters.Postgres ->
        GreenFairy.CQL.Adapters.Postgres

      adapter_module == Ecto.Adapters.MyXQL ->
        GreenFairy.CQL.Adapters.MySQL

      adapter_module == Ecto.Adapters.SQLite3 ->
        GreenFairy.CQL.Adapters.SQLite

      adapter_module == Ecto.Adapters.Tds ->
        GreenFairy.CQL.Adapters.MSSQL

      # ClickHouse adapters (ecto_ch uses Ecto.Adapters.ClickHouse or Ch)
      String.contains?(adapter_name, "ClickHouse") or
      String.contains?(adapter_name, "Ch.") or
      adapter_module == Ch ->
        GreenFairy.CQL.Adapters.ClickHouse

      # Unknown adapter - use generic Ecto fallback
      true ->
        Keyword.get(opts, :default, GreenFairy.CQL.Adapters.Ecto)
    end
  end

  @doc """
  Validates that an operator is supported by the adapter for a given field type.

  Returns `:ok` if supported, `{:error, reason}` otherwise.
  """
  def validate_operator(adapter, field_type, operator) do
    category = categorize_field_type(field_type)
    supported = adapter.supported_operators(category, field_type)

    if operator in supported do
      :ok
    else
      {:error, "Operator #{operator} not supported for #{field_type} on #{inspect(adapter)}"}
    end
  end

  # Categorize field types into broad categories
  defp categorize_field_type({:array, _}), do: :array
  defp categorize_field_type(:map), do: :json
  defp categorize_field_type({:map, _}), do: :json
  defp categorize_field_type({:parameterized, Ecto.Enum, _}), do: :scalar
  defp categorize_field_type(_), do: :scalar
end
