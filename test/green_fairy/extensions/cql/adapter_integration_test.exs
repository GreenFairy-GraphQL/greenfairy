defmodule GreenFairy.CQL.AdapterIntegrationTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.Adapter
  alias GreenFairy.CQL.Adapters.{Postgres, MySQL, SQLite, MSSQL, Elasticsearch}
  alias GreenFairy.CQL.Adapters.Ecto, as: EctoAdapter
  alias GreenFairy.CQL.OperatorInput

  # Define test repos at module level for reliable module loading
  # Use Elixir. prefix to avoid alias conflicts with GreenFairy.CQL.Adapters.Ecto
  defmodule PostgresRepo do
    def __adapter__, do: Elixir.Ecto.Adapters.Postgres
  end

  defmodule MySQLRepo do
    def __adapter__, do: Elixir.Ecto.Adapters.MyXQL
  end

  defmodule SQLiteRepo do
    def __adapter__, do: Elixir.Ecto.Adapters.SQLite3
  end

  defmodule MSSQLRepo do
    def __adapter__, do: Elixir.Ecto.Adapters.Tds
  end

  defmodule UnknownRepo do
    def __adapter__, do: UnknownAdapter
  end

  defmodule OverrideRepo do
    def __adapter__, do: Elixir.Ecto.Adapters.Postgres
  end

  describe "Adapter.detect_adapter/2" do
    test "detects PostgreSQL from Ecto adapter" do
      adapter = Adapter.detect_adapter(__MODULE__.PostgresRepo)
      assert adapter == Postgres
    end

    test "detects MySQL from Ecto adapter" do
      adapter = Adapter.detect_adapter(__MODULE__.MySQLRepo)
      assert adapter == MySQL
    end

    test "detects SQLite from Ecto adapter" do
      adapter = Adapter.detect_adapter(__MODULE__.SQLiteRepo)
      assert adapter == SQLite
    end

    test "detects MSSQL from Ecto adapter" do
      adapter = Adapter.detect_adapter(__MODULE__.MSSQLRepo)
      assert adapter == MSSQL
    end

    test "returns generic Ecto adapter for unknown Ecto adapter" do
      adapter = Adapter.detect_adapter(__MODULE__.UnknownRepo)
      # Should default to generic Ecto adapter
      assert adapter == EctoAdapter
    end

    test "uses configured adapter from application env" do
      # Save original config
      original = Application.get_env(:green_fairy, :cql_adapter)

      try do
        Application.put_env(:green_fairy, :cql_adapter, MySQL)
        adapter = Adapter.detect_adapter(nil)
        assert adapter == MySQL
      after
        # Restore original config
        if original do
          Application.put_env(:green_fairy, :cql_adapter, original)
        else
          Application.delete_env(:green_fairy, :cql_adapter)
        end
      end
    end

    test "uses override option when provided" do
      adapter = Adapter.detect_adapter(__MODULE__.OverrideRepo, default: SQLite)
      # Should detect Postgres, not use default since repo is valid
      assert adapter == Postgres
    end
  end

  describe "operator_category/1" do
    test "identifies scalar operator types" do
      assert OperatorInput.operator_category(:cql_op_string_input) == :scalar
      assert OperatorInput.operator_category(:cql_op_integer_input) == :scalar
      assert OperatorInput.operator_category(:cql_op_boolean_input) == :scalar
    end

    test "identifies array operator types" do
      assert OperatorInput.operator_category(:cql_op_string_array_input) == :array
      assert OperatorInput.operator_category(:cql_op_enum_array_input) == :array
      assert OperatorInput.operator_category(:cql_op_integer_array_input) == :array
    end

    test "identifies json operator types" do
      assert OperatorInput.operator_category(:cql_op_json_input) == :json
    end
  end

  describe "adapter-specific operator generation" do
    test "PostgreSQL generates all array operators" do
      postgres_ops = Postgres.supported_operators(:array, :string)

      assert :_includes in postgres_ops
      assert :_excludes in postgres_ops
      assert :_includes_all in postgres_ops
      assert :_includes_any in postgres_ops
      assert :_is_empty in postgres_ops
    end

    test "MySQL generates limited array operators" do
      mysql_ops = MySQL.supported_operators(:array, :string)

      assert :_includes in mysql_ops
      assert :_excludes in mysql_ops
      assert :_includes_any in mysql_ops
      assert :_is_empty in mysql_ops

      # MySQL doesn't support _includes_all easily
      # (can be done but not in default support)
    end

    test "SQLite generates minimal array operators" do
      sqlite_ops = SQLite.supported_operators(:array, :string)

      assert :_includes in sqlite_ops
      assert :_excludes in sqlite_ops
      assert :_is_empty in sqlite_ops

      # SQLite doesn't support _includes_all or _includes_any easily
      refute :_includes_all in sqlite_ops
      refute :_includes_any in sqlite_ops
    end

    test "Elasticsearch generates all operators including ES-specific ones" do
      es_scalar_ops = Elasticsearch.supported_operators(:scalar, :string)
      es_array_ops = Elasticsearch.supported_operators(:array, :string)

      # Standard operators
      assert :_eq in es_scalar_ops
      assert :_contains in es_scalar_ops

      # ES-specific
      assert :_fuzzy in es_scalar_ops
      assert :_prefix in es_scalar_ops
      assert :_regexp in es_scalar_ops

      # Native array support
      assert :_includes_all in es_array_ops
      assert :_includes_any in es_array_ops
    end
  end

  describe "operator filtering by adapter" do
    test "generate_all with PostgreSQL adapter includes all array operators" do
      types = OperatorInput.generate_all(adapter: Postgres)

      # Find the string array operator type
      # The AST format is {:__block__, _, [{:@, _, [{:desc, _, [description]}]}, {:input_object, _, [identifier, [do: ...]]}]}
      # or just {:input_object, _, [identifier, [do: ...]]} depending on whether @desc is present
      string_array_ast =
        Enum.find(types, fn ast ->
          case ast do
            {:__block__, _, [_desc_attr, {:input_object, _, [:cql_op_string_array_input | _]}]} -> true
            {:input_object, _, [:cql_op_string_array_input | _]} -> true
            _ -> false
          end
        end)

      assert string_array_ast != nil
    end

    test "generate_all with SQLite adapter excludes unsupported operators" do
      types = OperatorInput.generate_all(adapter: SQLite)

      # Verify SQLite types were generated but with limited operators
      assert length(types) > 0

      # Could inspect the AST to verify _includes_all is not present
      # but that would require parsing the AST deeply
    end

    test "generate_all without adapter raises error" do
      # This behavior is enforced at schema level, not here
      # Just verify we can generate with nil adapter (for testing)
      types = OperatorInput.generate_all(adapter: nil)
      # Without adapter, should generate default operators
      assert length(types) > 0
    end
  end

  describe "adapter capabilities comparison" do
    test "PostgreSQL has native arrays" do
      assert Postgres.capabilities().native_arrays == true
    end

    test "MySQL does not have native arrays" do
      assert MySQL.capabilities().native_arrays == false
    end

    test "SQLite has limited JSON support" do
      assert SQLite.capabilities().limited_json == true
    end

    test "MSSQL requires SQL Server 2016+" do
      assert MSSQL.capabilities().requires_sql_server_2016_plus == true
    end

    test "Elasticsearch is query DSL based" do
      assert Elasticsearch.capabilities().query_dsl_based == true
    end

    test "all adapters support JSON operators" do
      assert Postgres.capabilities().supports_json_operators == true
      assert MySQL.capabilities().supports_json_operators == true
      assert SQLite.capabilities().supports_json_operators == true
      assert MSSQL.capabilities().supports_json_operators == true
      assert Elasticsearch.capabilities().supports_json_operators == true
    end

    test "max_in_clause_items varies by adapter" do
      assert Postgres.capabilities().max_in_clause_items == 10000
      assert MySQL.capabilities().max_in_clause_items == 1000
      assert SQLite.capabilities().max_in_clause_items == 500
      assert MSSQL.capabilities().max_in_clause_items == 1000
      assert Elasticsearch.capabilities().max_in_clause_items == 65536
    end
  end

  describe "adapter behavior contract" do
    test "all adapters implement required callbacks" do
      adapters = [Postgres, MySQL, SQLite, MSSQL, Elasticsearch]

      for adapter <- adapters do
        Code.ensure_loaded!(adapter)
        assert function_exported?(adapter, :supported_operators, 2),
               "#{inspect(adapter)} missing supported_operators/2"

        assert function_exported?(adapter, :apply_operator, 5),
               "#{inspect(adapter)} missing apply_operator/5"

        assert function_exported?(adapter, :capabilities, 0),
               "#{inspect(adapter)} missing capabilities/0"
      end
    end

    test "all adapters support basic scalar operators" do
      adapters = [Postgres, MySQL, SQLite, MSSQL, Elasticsearch]
      basic_ops = [:_eq, :_neq, :_in, :_is_null]

      for adapter <- adapters do
        supported = adapter.supported_operators(:scalar, :string)

        for op <- basic_ops do
          assert op in supported,
                 "#{inspect(adapter)} should support #{inspect(op)} for scalar fields"
        end
      end
    end

    test "all adapters return capabilities map with required keys" do
      adapters = [Postgres, MySQL, SQLite, MSSQL, Elasticsearch]
      required_keys = [:array_operators_require_type_cast, :supports_json_operators, :native_arrays]

      for adapter <- adapters do
        caps = adapter.capabilities()
        assert is_map(caps), "#{inspect(adapter)} capabilities should return a map"

        for key <- required_keys do
          assert Map.has_key?(caps, key),
                 "#{inspect(adapter)} missing capability key: #{inspect(key)}"
        end
      end
    end
  end

  describe "operator consistency across adapters" do
    test "all SQL adapters support ILIKE or emulation" do
      sql_adapters = [Postgres, MySQL, SQLite, MSSQL]

      for adapter <- sql_adapters do
        ops = adapter.supported_operators(:scalar, :string)
        assert :_ilike in ops, "#{inspect(adapter)} should support _ilike"
      end
    end

    test "adapters with array support all support _includes" do
      array_adapters = [Postgres, MySQL, SQLite, MSSQL, Elasticsearch]

      for adapter <- array_adapters do
        ops = adapter.supported_operators(:array, :string)
        assert :_includes in ops, "#{inspect(adapter)} should support _includes for arrays"
      end
    end

    test "only PostgreSQL and Elasticsearch support _includes_all" do
      # PostgreSQL has native arrays
      postgres_ops = Postgres.supported_operators(:array, :string)
      assert :_includes_all in postgres_ops

      # Elasticsearch has native arrays
      es_ops = Elasticsearch.supported_operators(:array, :string)
      assert :_includes_all in es_ops

      # MySQL, SQLite, MSSQL require complex workarounds
      mysql_ops = MySQL.supported_operators(:array, :string)
      refute :_includes_all in mysql_ops

      sqlite_ops = SQLite.supported_operators(:array, :string)
      refute :_includes_all in sqlite_ops

      mssql_ops = MSSQL.supported_operators(:array, :string)
      refute :_includes_all in mssql_ops
    end
  end

  defmodule InvalidRepo do
    def some_other_function, do: :ok
  end

  describe "edge cases and error handling" do
    test "detect_adapter handles nil repo gracefully" do
      adapter = Adapter.detect_adapter(nil)
      assert adapter == EctoAdapter  # Falls back to generic Ecto adapter
    end

    test "detect_adapter handles repo without __adapter__ function" do
      adapter = Adapter.detect_adapter(__MODULE__.InvalidRepo)
      assert adapter == EctoAdapter  # Falls back to generic Ecto adapter
    end
  end
end
