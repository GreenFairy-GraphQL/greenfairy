defmodule GreenFairy.CQL.SchemaTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.Schema

  describe "cql_filter_type_for/1" do
    # Create a mock type module with CQL enabled
    defmodule MockUser do
      defstruct [:id, :name]
      def __schema__(:fields), do: [:id, :name]
      def __schema__(:type, :id), do: :id
      def __schema__(:type, :name), do: :string
      def __schema__(:type, _), do: nil
    end

    defmodule MockUserType do
      use GreenFairy.Type
      alias GreenFairy.CQL

      type "User", struct: MockUser do
        use CQL

        field :id, non_null(:id)
        field :name, :string
      end
    end

    test "returns filter input type identifier" do
      identifier = MockUserType.__cql_filter_input_identifier__()
      assert identifier == :cql_filter_user_input
    end

    test "cql_filter_type_for returns identifier" do
      identifier = Schema.Helpers.cql_filter_type_for(MockUserType)
      assert identifier == :cql_filter_user_input
    end
  end

  describe "cql_order_type_for/1" do
    # Reuse MockUserType from above
    test "returns order input type identifier" do
      identifier = Schema.Helpers.cql_order_type_for(__MODULE__.MockUserType)
      assert identifier == :cql_order_user_input
    end
  end

  describe "module macros" do
    test "cql_operator_types macro generates AST" do
      # The macro generates operator input types AST
      # We can verify it's callable without full schema compilation
      alias GreenFairy.CQL.Adapters.Postgres
      ast = GreenFairy.CQL.OperatorInput.generate_all(adapter: Postgres)
      assert is_list(ast)
      # PostgreSQL has all operator types including arrays
      assert length(ast) > 10
    end
  end

  describe "GreenFairy.CQL.OperatorInput" do
    test "generate_all returns AST for multiple adapters" do
      # Test with MySQL adapter
      alias GreenFairy.CQL.Adapters.MySQL
      mysql_ast = GreenFairy.CQL.OperatorInput.generate_all(adapter: MySQL)
      assert is_list(mysql_ast)
      assert length(mysql_ast) > 5

      # Test with SQLite adapter
      alias GreenFairy.CQL.Adapters.SQLite
      sqlite_ast = GreenFairy.CQL.OperatorInput.generate_all(adapter: SQLite)
      assert is_list(sqlite_ast)
      assert length(sqlite_ast) > 5
    end
  end

  describe "GreenFairy.CQL.Schema.OrderInput" do
    test "generate_base_types returns order input types AST" do
      ast = GreenFairy.CQL.Schema.OrderInput.generate_base_types()
      assert is_list(ast)
      # Should have sort direction enum and order input types
      assert length(ast) > 0
    end
  end
end
