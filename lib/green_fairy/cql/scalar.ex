defmodule GreenFairy.CQL.Scalar do
  @moduledoc """
  Behavior for CQL scalar types.

  Each scalar type owns its complete implementation including:
  - GraphQL operator input type definition
  - Query operator implementations for each database adapter
  - Type-specific validation and casting

  ## Scalar Ownership

  Scalars are the single source of truth for their CQL behavior. They decide
  whether to implement operators inline or delegate to adapter-specific modules.

  ## Implementation Patterns

  ### Pattern 1: Inline Implementation (Simple scalars)

      defmodule MyApp.Scalars.Email do
        use GreenFairy.Scalar
        @behaviour GreenFairy.CQL.Scalar

        @impl true
        def operator_input(_adapter) do
          {[:_eq, :_neq, :_in, :_like], :string, "Email operators"}
        end

        @impl true
        def apply_operator(query, field, :_eq, value, _adapter, _opts) do
          where(query, [q], field(q, ^field) == ^value)
        end
      end

  ### Pattern 2: Adapter Delegation (Complex scalars)

      defmodule MyApp.Scalars.GeoPoint do
        use GreenFairy.Scalar
        @behaviour GreenFairy.CQL.Scalar

        @impl true
        def operator_input(:postgres), do: Postgres.operator_input()
        def operator_input(:elasticsearch), do: Elasticsearch.operator_input()
        def operator_input(_), do: {[:_eq], :string, "Basic geo"}

        @impl true
        def apply_operator(query, field, op, value, :postgres, opts) do
          Postgres.apply_operator(query, field, op, value, opts)
        end

        defmodule Postgres do
          def operator_input() do
            {[:_within_radius, :_bbox, :_intersects], :geo_point, "PostGIS operators"}
          end

          def apply_operator(query, field, :_within_radius, %{center: center, radius: radius}, opts) do
            # PostGIS ST_Distance implementation
          end
        end
      end

  ### Pattern 3: Inheritance (Specialized scalars)

      defmodule MyApp.Scalars.Username do
        use GreenFairy.Scalar
        @behaviour GreenFairy.CQL.Scalar

        # Delegate most behavior to String scalar
        defdelegate operator_input(adapter), to: GreenFairy.CQL.Scalars.String

        @impl true
        def apply_operator(query, field, :_eq, value, adapter, opts) do
          # Override for case-insensitive comparison
          where(query, [q], fragment("LOWER(?)", field(q, ^field)) == ^String.downcase(value))
        end

        def apply_operator(query, field, op, value, adapter, opts) do
          # Delegate everything else to String
          GreenFairy.CQL.Scalars.String.apply_operator(query, field, op, value, adapter, opts)
        end
      end

  ## Adapter Parameter

  The `adapter` parameter is an atom identifying the database adapter:
  - `:postgres` - PostgreSQL
  - `:mysql` - MySQL/MariaDB
  - `:sqlite` - SQLite
  - `:mssql` - Microsoft SQL Server
  - `:elasticsearch` - Elasticsearch

  This allows scalars to provide different implementations per database.

  ## Options

  The `opts` keyword list may include:
  - `:binding` - Named binding for association queries
  - `:field_type` - Full Ecto type for specialized handling
  - `:cast_type` - Type to cast values to
  """

  @doc """
  Returns the operator input type definition for this scalar.

  ## Parameters

  - `adapter` - The database adapter atom (`:postgres`, `:mysql`, etc.)

  ## Returns

  A tuple `{operators, scalar_type, description}` where:
  - `operators` - List of operator atoms (e.g., `[:_eq, :_neq, :_gt]`)
  - `scalar_type` - GraphQL scalar type for values (e.g., `:string`, `:integer`)
  - `description` - Documentation string for the input type

  ## Examples

      def operator_input(:postgres) do
        {[:_eq, :_neq, :_gt, :_gte, :_lt, :_lte, :_in, :_nin, :_is_null,
          :_like, :_ilike, :_starts_with, :_contains],
         :string,
         "PostgreSQL string operators with native ILIKE"}
      end

      def operator_input(:mysql) do
        {[:_eq, :_neq, :_gt, :_gte, :_lt, :_lte, :_in, :_nin, :_is_null,
          :_like, :_ilike, :_starts_with, :_contains],
         :string,
         "MySQL string operators (ILIKE emulated with LOWER)"}
      end
  """
  @callback operator_input(adapter :: atom()) :: {
              operators :: [atom()],
              scalar_type :: atom(),
              description :: String.t()
            }

  @doc """
  Applies a CQL operator to an Ecto query.

  ## Parameters

  - `query` - Base Ecto query
  - `field` - Field name (atom)
  - `operator` - Operator atom (e.g., `:_eq`, `:_gt`, `:_like`)
  - `value` - Filter value
  - `adapter` - Database adapter atom (`:postgres`, `:mysql`, etc.)
  - `opts` - Options including:
    - `:binding` - Named binding for association queries (optional)
    - `:field_type` - Field type for type-specific handling
    - `:cast_type` - Type to cast values to

  ## Returns

  Modified Ecto query with the operator applied.

  ## Examples

      # Base query
      def apply_operator(query, :name, :_eq, "Alice", :postgres, _opts) do
        where(query, [q], field(q, :name) == ^"Alice")
      end

      # Association query with binding
      def apply_operator(query, :status, :_eq, "active", :postgres, binding: :posts) do
        where(query, [{:posts, p}], field(p, :status) == ^"active")
      end

      # Adapter-specific implementation
      def apply_operator(query, :name, :_ilike, pattern, :postgres, _opts) do
        where(query, [q], ilike(field(q, :name), ^pattern))
      end

      def apply_operator(query, :name, :_ilike, pattern, :mysql, _opts) do
        # MySQL doesn't have ILIKE, emulate with LOWER
        where(query, [q], fragment("LOWER(?) LIKE LOWER(?)", field(q, :name), ^pattern))
      end
  """
  @callback apply_operator(
              query :: Ecto.Query.t(),
              field :: atom(),
              operator :: atom(),
              value :: any(),
              adapter :: atom(),
              opts :: keyword()
            ) :: Ecto.Query.t()

  @doc """
  Returns the CQL operator input type identifier for this scalar.

  This is used to generate the GraphQL input type name. Defaults to a standard
  naming convention but can be overridden.

  ## Examples

      def operator_type_identifier(:postgres), do: :cql_op_string_input
      def operator_type_identifier(:mysql), do: :cql_op_string_input
  """
  @callback operator_type_identifier(adapter :: atom()) :: atom()

  @optional_callbacks [operator_type_identifier: 1]
end
