defmodule GreenFairy.CQL.Scalars.ArrayStringAdaptersTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.Scalars.ArrayString
  alias GreenFairy.CQL.Scalars.ArrayString.Postgres
  alias GreenFairy.CQL.Scalars.ArrayString.MySQL
  alias GreenFairy.CQL.Scalars.ArrayString.SQLite
  alias GreenFairy.CQL.Scalars.ArrayString.MSSQL

  defmodule TestSchema do
    use Ecto.Schema

    schema "test_records" do
      field :tags, {:array, :string}
    end
  end

  describe "ArrayString" do
    test "operator_input for postgres returns Postgres adapter config" do
      {operators, type, _desc} = ArrayString.operator_input(:postgres)

      assert :_includes in operators
      assert :_excludes in operators
      assert type == :string
    end

    test "operator_input for mysql returns MySQL adapter config" do
      {operators, type, _desc} = ArrayString.operator_input(:mysql)

      assert :_includes in operators
      assert type == :string
    end

    test "operator_type_identifier returns correct identifier" do
      assert ArrayString.operator_type_identifier(:postgres) == :cql_op_string_array_input
    end
  end

  describe "ArrayString.Postgres" do
    import Ecto.Query

    test "operator_input returns correct operators" do
      {operators, type, desc} = Postgres.operator_input()

      assert :_includes in operators
      assert :_excludes in operators
      assert :_includes_all in operators
      assert :_excludes_all in operators
      assert :_includes_any in operators
      assert :_excludes_any in operators
      assert :_is_empty in operators
      assert :_is_null in operators
      assert type == :string
      assert is_binary(desc)
    end

    test "_includes operator without binding" do
      query = from(t in TestSchema)

      result = Postgres.apply_operator(query, :tags, :_includes, "tag1", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_includes operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = Postgres.apply_operator(query, :tags, :_includes, "tag1", binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_excludes operator without binding" do
      query = from(t in TestSchema)

      result = Postgres.apply_operator(query, :tags, :_excludes, "tag1", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_excludes operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = Postgres.apply_operator(query, :tags, :_excludes, "tag1", binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_includes_all operator without binding" do
      query = from(t in TestSchema)

      result = Postgres.apply_operator(query, :tags, :_includes_all, ["tag1", "tag2"], [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_includes_all operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = Postgres.apply_operator(query, :tags, :_includes_all, ["tag1", "tag2"], binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_excludes_all operator" do
      query = from(t in TestSchema)

      result = Postgres.apply_operator(query, :tags, :_excludes_all, ["tag1", "tag2"], [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_excludes_all operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = Postgres.apply_operator(query, :tags, :_excludes_all, ["tag1", "tag2"], binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_includes_any operator" do
      query = from(t in TestSchema)

      result = Postgres.apply_operator(query, :tags, :_includes_any, ["tag1", "tag2"], [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_includes_any operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = Postgres.apply_operator(query, :tags, :_includes_any, ["tag1", "tag2"], binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_excludes_any operator" do
      query = from(t in TestSchema)

      result = Postgres.apply_operator(query, :tags, :_excludes_any, ["tag1", "tag2"], [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_excludes_any operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = Postgres.apply_operator(query, :tags, :_excludes_any, ["tag1", "tag2"], binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_empty true operator" do
      query = from(t in TestSchema)

      result = Postgres.apply_operator(query, :tags, :_is_empty, true, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_empty true operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = Postgres.apply_operator(query, :tags, :_is_empty, true, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_empty false operator" do
      query = from(t in TestSchema)

      result = Postgres.apply_operator(query, :tags, :_is_empty, false, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_empty false operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = Postgres.apply_operator(query, :tags, :_is_empty, false, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null true operator" do
      query = from(t in TestSchema)

      result = Postgres.apply_operator(query, :tags, :_is_null, true, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null true operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = Postgres.apply_operator(query, :tags, :_is_null, true, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null false operator" do
      query = from(t in TestSchema)

      result = Postgres.apply_operator(query, :tags, :_is_null, false, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null false operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = Postgres.apply_operator(query, :tags, :_is_null, false, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "unknown operator returns query unchanged" do
      query = from(t in TestSchema)

      result = Postgres.apply_operator(query, :tags, :_unknown, "value", [])

      assert result == query
    end
  end

  describe "ArrayString.MySQL" do
    import Ecto.Query

    test "operator_input returns correct operators" do
      {operators, type, _desc} = MySQL.operator_input()

      assert :_includes in operators
      assert :_excludes in operators
      assert :_is_empty in operators
      assert :_is_null in operators
      assert type == :string
    end

    test "_includes operator" do
      query = from(t in TestSchema)

      result = MySQL.apply_operator(query, :tags, :_includes, "tag1", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_includes operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = MySQL.apply_operator(query, :tags, :_includes, "tag1", binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_excludes operator" do
      query = from(t in TestSchema)

      result = MySQL.apply_operator(query, :tags, :_excludes, "tag1", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_empty true operator" do
      query = from(t in TestSchema)

      result = MySQL.apply_operator(query, :tags, :_is_empty, true, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_empty false operator" do
      query = from(t in TestSchema)

      result = MySQL.apply_operator(query, :tags, :_is_empty, false, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null true operator" do
      query = from(t in TestSchema)

      result = MySQL.apply_operator(query, :tags, :_is_null, true, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null false operator" do
      query = from(t in TestSchema)

      result = MySQL.apply_operator(query, :tags, :_is_null, false, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "unknown operator returns query unchanged" do
      query = from(t in TestSchema)

      result = MySQL.apply_operator(query, :tags, :_unknown, "value", [])

      assert result == query
    end
  end

  describe "ArrayString.SQLite" do
    import Ecto.Query

    test "operator_input returns correct operators" do
      {operators, type, _desc} = SQLite.operator_input()

      assert :_includes in operators
      assert :_is_empty in operators
      assert :_is_null in operators
      assert type == :string
    end

    test "_includes operator" do
      query = from(t in TestSchema)

      result = SQLite.apply_operator(query, :tags, :_includes, "tag1", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_excludes operator" do
      query = from(t in TestSchema)

      result = SQLite.apply_operator(query, :tags, :_excludes, "tag1", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_empty true operator" do
      query = from(t in TestSchema)

      result = SQLite.apply_operator(query, :tags, :_is_empty, true, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null true operator" do
      query = from(t in TestSchema)

      result = SQLite.apply_operator(query, :tags, :_is_null, true, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "unknown operator returns query unchanged" do
      query = from(t in TestSchema)

      result = SQLite.apply_operator(query, :tags, :_unknown, "value", [])

      assert result == query
    end
  end

  describe "ArrayString.MSSQL" do
    import Ecto.Query

    test "operator_input returns correct operators" do
      {operators, type, _desc} = MSSQL.operator_input()

      assert :_includes in operators
      assert :_is_empty in operators
      assert :_is_null in operators
      assert type == :string
    end

    test "_includes operator" do
      query = from(t in TestSchema)

      result = MSSQL.apply_operator(query, :tags, :_includes, "tag1", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_excludes operator" do
      query = from(t in TestSchema)

      result = MSSQL.apply_operator(query, :tags, :_excludes, "tag1", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_empty true operator" do
      query = from(t in TestSchema)

      result = MSSQL.apply_operator(query, :tags, :_is_empty, true, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null true operator" do
      query = from(t in TestSchema)

      result = MSSQL.apply_operator(query, :tags, :_is_null, true, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "unknown operator returns query unchanged" do
      query = from(t in TestSchema)

      result = MSSQL.apply_operator(query, :tags, :_unknown, "value", [])

      assert result == query
    end
  end
end
