defmodule GreenFairy.CQL.OperatorInputTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.Schema.OperatorInput

  describe "type_for/1" do
    test "returns operator type for id" do
      assert OperatorInput.type_for(:id) == :cql_op_id_input
      assert OperatorInput.type_for(:binary_id) == :cql_op_id_input
    end

    test "returns operator type for string" do
      assert OperatorInput.type_for(:string) == :cql_op_string_input
    end

    test "returns operator type for integer" do
      assert OperatorInput.type_for(:integer) == :cql_op_integer_input
    end

    test "returns operator type for float and decimal" do
      assert OperatorInput.type_for(:float) == :cql_op_float_input
      assert OperatorInput.type_for(:decimal) == :cql_op_decimal_input
    end

    test "returns operator type for boolean" do
      assert OperatorInput.type_for(:boolean) == :cql_op_boolean_input
    end

    test "returns operator type for datetime types" do
      assert OperatorInput.type_for(:naive_datetime) == :cql_op_naive_date_time_input
      assert OperatorInput.type_for(:utc_datetime) == :cql_op_date_time_input
      assert OperatorInput.type_for(:naive_datetime_usec) == :cql_op_naive_date_time_input
      assert OperatorInput.type_for(:utc_datetime_usec) == :cql_op_date_time_input
    end

    test "returns operator type for date" do
      assert OperatorInput.type_for(:date) == :cql_op_date_input
    end

    test "returns operator type for time types" do
      assert OperatorInput.type_for(:time) == :cql_op_time_input
      assert OperatorInput.type_for(:time_usec) == :cql_op_time_input
    end

    test "returns nil for complex types" do
      assert OperatorInput.type_for(:map) == nil
      assert OperatorInput.type_for(:array) == nil
      # Array types with inner types now return proper array input types
      assert OperatorInput.type_for({:array, :string}) == :cql_op_string_array_input
      assert OperatorInput.type_for({:map, :string}) == nil
    end

    test "returns operator type for Ecto.Enum parameterized type" do
      assert OperatorInput.type_for({:parameterized, Ecto.Enum, %{}}) == :cql_op_enum_input
    end

    test "returns nil for Ecto.Embedded parameterized type" do
      assert OperatorInput.type_for({:parameterized, Ecto.Embedded, %{}}) == nil
    end

    test "returns generic operator type for unknown types" do
      assert OperatorInput.type_for(:unknown_type) == :cql_op_generic_input
    end
  end

  describe "scalar_for/1" do
    test "returns scalar for id types" do
      assert OperatorInput.scalar_for(:id) == :id
      assert OperatorInput.scalar_for(:binary_id) == :id
    end

    test "returns scalar for string" do
      assert OperatorInput.scalar_for(:string) == :string
    end

    test "returns scalar for integer" do
      assert OperatorInput.scalar_for(:integer) == :integer
    end

    test "returns scalar for float and decimal" do
      assert OperatorInput.scalar_for(:float) == :float
      assert OperatorInput.scalar_for(:decimal) == :float
    end

    test "returns scalar for boolean" do
      assert OperatorInput.scalar_for(:boolean) == :boolean
    end

    test "returns datetime scalar for datetime types" do
      assert OperatorInput.scalar_for(:naive_datetime) == :datetime
      assert OperatorInput.scalar_for(:utc_datetime) == :datetime
    end

    test "returns date scalar for date" do
      assert OperatorInput.scalar_for(:date) == :date
    end

    test "returns time scalar for time types" do
      assert OperatorInput.scalar_for(:time) == :time
      assert OperatorInput.scalar_for(:time_usec) == :time
    end

    test "returns string scalar for Ecto.Enum" do
      assert OperatorInput.scalar_for({:parameterized, Ecto.Enum, %{}}) == :string
    end

    test "returns string scalar for unknown types" do
      assert OperatorInput.scalar_for(:unknown_type) == :string
    end
  end

  describe "operator_types/0" do
    test "returns map of operator types" do
      types = OperatorInput.operator_types()

      assert is_map(types)
      assert Map.has_key?(types, :cql_op_id_input)
      assert Map.has_key?(types, :cql_op_string_input)
      assert Map.has_key?(types, :cql_op_integer_input)
      assert Map.has_key?(types, :cql_op_float_input)
      assert Map.has_key?(types, :cql_op_decimal_input)
      assert Map.has_key?(types, :cql_op_boolean_input)
      assert Map.has_key?(types, :cql_op_date_time_input)
      assert Map.has_key?(types, :cql_op_naive_date_time_input)
      assert Map.has_key?(types, :cql_op_date_input)
      assert Map.has_key?(types, :cql_op_time_input)
      assert Map.has_key?(types, :cql_op_enum_input)
    end

    test "each operator type has operators, scalar, and description" do
      for {_identifier, {operators, scalar, description}} <- OperatorInput.operator_types() do
        assert is_list(operators)
        assert is_atom(scalar)
        assert is_binary(description)
      end
    end

    test "id operators include eq, neq, in, is_nil" do
      {operators, _scalar, _desc} = OperatorInput.operator_types()[:cql_op_id_input]
      assert :_eq in operators
      assert :_neq in operators
      assert :_in in operators
      assert :_is_null in operators
    end

    test "string operators include text operations" do
      {operators, _scalar, _desc} = OperatorInput.operator_types()[:cql_op_string_input]
      assert :_eq in operators
      assert :_neq in operators
      assert :_contains in operators
      assert :_starts_with in operators
      assert :_ends_with in operators
      assert :_in in operators
      assert :_is_null in operators
    end

    test "integer operators include comparison operations" do
      {operators, _scalar, _desc} = OperatorInput.operator_types()[:cql_op_integer_input]
      assert :_eq in operators
      assert :_neq in operators
      assert :_gt in operators
      assert :_gte in operators
      assert :_lt in operators
      assert :_lte in operators
      assert :_in in operators
      assert :_is_null in operators
    end

    test "boolean operators are limited" do
      {operators, _scalar, _desc} = OperatorInput.operator_types()[:cql_op_boolean_input]
      assert :_eq in operators
      assert :_is_null in operators
      refute :gt in operators
      refute :contains in operators
    end
  end

  describe "generate_all/0" do
    test "returns list of AST for all operator types" do
      alias GreenFairy.CQL.Adapters.Postgres
      ast_list = OperatorInput.generate_all(adapter: Postgres)

      assert is_list(ast_list)
      # PostgreSQL has many operator types including arrays
      assert length(ast_list) > 10
    end

    test "each generated AST is valid quoted expression" do
      alias GreenFairy.CQL.Adapters.Postgres
      for ast <- OperatorInput.generate_all(adapter: Postgres) do
        assert is_tuple(ast)
        assert elem(ast, 0) == :__block__
      end
    end
  end

  describe "generate_input/4" do
    test "generates input_object AST" do
      ast = OperatorInput.generate_input(:test_input, [:eq, :neq], :string, "Test input")

      assert {:__block__, _, _} = ast
    end
  end
end
