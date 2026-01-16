defmodule GreenFairy.CQL.Scalars.CoordinatesTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.Scalars.Coordinates
  alias GreenFairy.CQL.Scalars.Coordinates.Generic

  defmodule TestSchema do
    use Ecto.Schema

    schema "locations" do
      field :coordinates, :map
    end
  end

  describe "Coordinates scalar" do
    test "operator_input for postgres returns Postgres adapter config" do
      {operators, type, _desc} = Coordinates.operator_input(:postgres)

      assert is_list(operators)
      assert type == :coordinates
    end

    test "operator_input for mysql returns MySQL adapter config" do
      {operators, type, _desc} = Coordinates.operator_input(:mysql)

      assert is_list(operators)
      assert type == :coordinates
    end

    test "operator_input for unknown adapter returns Generic config" do
      {operators, type, _desc} = Coordinates.operator_input(:unknown)

      assert :_eq in operators
      assert :_ne in operators
      assert :_neq in operators
      assert :_is_null in operators
      assert type == :coordinates
    end

    test "operator_type_identifier returns correct identifier" do
      assert Coordinates.operator_type_identifier(:postgres) == :cql_op_coordinates_input
      assert Coordinates.operator_type_identifier(:mysql) == :cql_op_coordinates_input
      assert Coordinates.operator_type_identifier(:sqlite) == :cql_op_coordinates_input
    end

    test "apply_operator delegates to Postgres for postgres adapter" do
      import Ecto.Query
      query = from(t in TestSchema)
      coords = %{lat: 37.7749, lng: -122.4194}

      result = Coordinates.apply_operator(query, :coordinates, :_eq, coords, :postgres, [])
      assert %Ecto.Query{} = result
    end

    test "apply_operator delegates to MySQL for mysql adapter" do
      import Ecto.Query
      query = from(t in TestSchema)
      coords = %{lat: 37.7749, lng: -122.4194}

      result = Coordinates.apply_operator(query, :coordinates, :_eq, coords, :mysql, [])
      assert %Ecto.Query{} = result
    end

    test "apply_operator delegates to Generic for unknown adapter" do
      import Ecto.Query
      query = from(t in TestSchema)
      coords = %{lat: 37.7749, lng: -122.4194}

      result = Coordinates.apply_operator(query, :coordinates, :_eq, coords, :sqlite, [])
      assert %Ecto.Query{} = result
    end
  end

  describe "Coordinates.Generic" do
    import Ecto.Query

    test "operator_input returns basic operators" do
      {operators, type, desc} = Generic.operator_input()

      assert :_eq in operators
      assert :_ne in operators
      assert :_neq in operators
      assert :_is_null in operators
      assert type == :coordinates
      assert is_binary(desc)
    end

    test "_eq operator" do
      query = from(t in TestSchema)
      coords = %{lat: 37.7749, lng: -122.4194}

      result = Generic.apply_operator(query, :coordinates, :_eq, coords, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_eq operator with binding" do
      query = from(t in TestSchema, as: :location)
      coords = %{lat: 37.7749, lng: -122.4194}

      result = Generic.apply_operator(query, :coordinates, :_eq, coords, binding: :location)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_ne operator delegates to _neq" do
      query = from(t in TestSchema)
      coords = %{lat: 37.7749, lng: -122.4194}

      result = Generic.apply_operator(query, :coordinates, :_ne, coords, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_neq operator" do
      query = from(t in TestSchema)
      coords = %{lat: 37.7749, lng: -122.4194}

      result = Generic.apply_operator(query, :coordinates, :_neq, coords, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_neq operator with binding" do
      query = from(t in TestSchema, as: :location)
      coords = %{lat: 37.7749, lng: -122.4194}

      result = Generic.apply_operator(query, :coordinates, :_neq, coords, binding: :location)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null true operator" do
      query = from(t in TestSchema)

      result = Generic.apply_operator(query, :coordinates, :_is_null, true, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null true operator with binding" do
      query = from(t in TestSchema, as: :location)

      result = Generic.apply_operator(query, :coordinates, :_is_null, true, binding: :location)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null false operator" do
      query = from(t in TestSchema)

      result = Generic.apply_operator(query, :coordinates, :_is_null, false, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null false operator with binding" do
      query = from(t in TestSchema, as: :location)

      result = Generic.apply_operator(query, :coordinates, :_is_null, false, binding: :location)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "unknown operator returns query unchanged" do
      query = from(t in TestSchema)

      result = Generic.apply_operator(query, :coordinates, :_unknown, "value", [])
      assert result == query
    end
  end
end
