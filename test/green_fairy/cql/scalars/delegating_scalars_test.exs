defmodule GreenFairy.CQL.Scalars.DelegatingScalarsTest do
  @moduledoc """
  Tests for scalars that delegate to other implementations.
  These are the top-level modules that route to adapter-specific implementations.
  """
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.Scalars.Date
  alias GreenFairy.CQL.Scalars.Decimal
  alias GreenFairy.CQL.Scalars.Enum, as: EnumScalar
  alias GreenFairy.CQL.Scalars.Float
  alias GreenFairy.CQL.Scalars.ID

  defmodule TestSchema do
    use Ecto.Schema

    schema "test_records" do
      field :date_field, :date
      field :decimal_field, :decimal
      field :enum_field, Ecto.Enum, values: [:active, :inactive]
      field :float_field, :float
      field :id_field, :id
    end
  end

  describe "Date scalar" do
    import Ecto.Query

    test "operator_input returns date type" do
      {operators, type, desc} = Date.operator_input(:postgres)

      assert is_list(operators)
      assert type == :date
      assert is_binary(desc)
    end

    test "operator_type_identifier returns correct identifier" do
      assert Date.operator_type_identifier(:postgres) == :cql_op_date_input
      assert Date.operator_type_identifier(:mysql) == :cql_op_date_input
    end

    test "apply_operator delegates to DateTime" do
      query = from(t in TestSchema)

      result = Date.apply_operator(query, :date_field, :_eq, ~D[2024-01-15], :postgres, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end

  describe "Decimal scalar" do
    import Ecto.Query

    test "operator_input returns decimal type" do
      {operators, type, _desc} = Decimal.operator_input(:postgres)

      assert is_list(operators)
      assert type == :decimal
    end

    test "operator_type_identifier returns correct identifier" do
      assert Decimal.operator_type_identifier(:postgres) == :cql_op_decimal_input
      assert Decimal.operator_type_identifier(:mysql) == :cql_op_decimal_input
    end

    test "apply_operator for postgres adapter" do
      query = from(t in TestSchema)

      result = Decimal.apply_operator(query, :decimal_field, :_eq, Elixir.Decimal.new("10.5"), :postgres, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "apply_operator for elasticsearch adapter" do
      query = %{query: %{bool: %{must: [], must_not: []}}}

      result = Decimal.apply_operator(query, :decimal_field, :_eq, 10.5, :elasticsearch, [])

      assert is_map(result)
    end
  end

  describe "Enum scalar" do
    import Ecto.Query

    test "operator_input returns correct operators" do
      {operators, type, _desc} = EnumScalar.operator_input(:postgres)

      assert :_eq in operators
      assert :_ne in operators
      assert :_neq in operators
      assert :_in in operators
      assert :_nin in operators
      assert :_is_null in operators
      # Enums use string type for operator input
      assert type == :string
    end

    test "operator_type_identifier returns correct identifier" do
      assert EnumScalar.operator_type_identifier(:postgres) == :cql_op_enum_input
    end

    test "apply_operator for Ecto adapters" do
      query = from(t in TestSchema)

      result = EnumScalar.apply_operator(query, :enum_field, :_eq, :active, :postgres, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "apply_operator for elasticsearch" do
      query = %{query: %{bool: %{must: [], must_not: []}}}

      result = EnumScalar.apply_operator(query, :enum_field, :_eq, :active, :elasticsearch, [])

      assert is_map(result)
    end
  end

  describe "Float scalar" do
    import Ecto.Query

    test "operator_input returns float type" do
      {operators, type, _desc} = Float.operator_input(:postgres)

      assert is_list(operators)
      assert type == :float
    end

    test "operator_type_identifier returns correct identifier" do
      assert Float.operator_type_identifier(:postgres) == :cql_op_float_input
      assert Float.operator_type_identifier(:mysql) == :cql_op_float_input
    end

    test "apply_operator for postgres adapter" do
      query = from(t in TestSchema)

      result = Float.apply_operator(query, :float_field, :_eq, 3.14, :postgres, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "apply_operator for elasticsearch adapter" do
      query = %{query: %{bool: %{must: [], must_not: []}}}

      result = Float.apply_operator(query, :float_field, :_eq, 3.14, :elasticsearch, [])

      assert is_map(result)
    end
  end

  describe "ID scalar" do
    import Ecto.Query

    test "operator_input returns id type" do
      {operators, type, _desc} = ID.operator_input(:postgres)

      assert is_list(operators)
      assert type == :id
    end

    test "operator_type_identifier returns correct identifier" do
      assert ID.operator_type_identifier(:postgres) == :cql_op_id_input
      assert ID.operator_type_identifier(:mysql) == :cql_op_id_input
    end

    test "apply_operator for postgres adapter" do
      query = from(t in TestSchema)

      result = ID.apply_operator(query, :id_field, :_eq, 123, :postgres, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "apply_operator for elasticsearch adapter" do
      query = %{query: %{bool: %{must: [], must_not: []}}}

      result = ID.apply_operator(query, :id_field, :_eq, "123", :elasticsearch, [])

      assert is_map(result)
    end
  end
end
