defmodule GreenFairy.CQL.Scalars.ArrayIntegerTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.Scalars.ArrayInteger
  alias GreenFairy.CQL.Scalars.ArrayInteger.Postgres

  defmodule TestSchema do
    use Ecto.Schema

    schema "test_records" do
      field :tags, {:array, :integer}
    end
  end

  describe "ArrayInteger" do
    test "operator_input for postgres returns Postgres adapter config" do
      {operators, type, _desc} = ArrayInteger.operator_input(:postgres)

      assert :_includes in operators
      assert :_excludes in operators
      assert :_includes_all in operators
      assert :_excludes_all in operators
      assert :_includes_any in operators
      assert :_excludes_any in operators
      assert :_is_empty in operators
      assert :_is_null in operators
      assert type == :integer
    end

    test "operator_input for mysql delegates to ArrayString with integer type" do
      {operators, type, _desc} = ArrayInteger.operator_input(:mysql)

      assert is_list(operators)
      assert type == :integer
    end

    test "operator_type_identifier returns correct identifier" do
      assert ArrayInteger.operator_type_identifier(:postgres) == :cql_op_integer_array_input
      assert ArrayInteger.operator_type_identifier(:mysql) == :cql_op_integer_array_input
    end

    test "apply_operator delegates to Postgres for postgres adapter" do
      import Ecto.Query
      query = from(t in TestSchema)

      result = ArrayInteger.apply_operator(query, :tags, :_includes, 5, :postgres, [])
      assert %Ecto.Query{} = result
    end

    test "apply_operator delegates to ArrayString for non-postgres adapters" do
      import Ecto.Query
      query = from(t in TestSchema)

      result = ArrayInteger.apply_operator(query, :tags, :_is_null, true, :mysql, [])
      assert %Ecto.Query{} = result
    end
  end

  describe "ArrayInteger.Postgres" do
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
      assert type == :integer
      assert is_binary(desc)
    end

    test "_includes operator without binding" do
      query = from(t in TestSchema)

      result = Postgres.apply_operator(query, :tags, :_includes, 5, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_includes operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = Postgres.apply_operator(query, :tags, :_includes, 5, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_excludes operator without binding" do
      query = from(t in TestSchema)

      result = Postgres.apply_operator(query, :tags, :_excludes, 5, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_excludes operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = Postgres.apply_operator(query, :tags, :_excludes, 5, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_includes_all operator without binding" do
      query = from(t in TestSchema)

      result = Postgres.apply_operator(query, :tags, :_includes_all, [1, 2, 3], [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_includes_all operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = Postgres.apply_operator(query, :tags, :_includes_all, [1, 2, 3], binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_excludes_all operator without binding" do
      query = from(t in TestSchema)

      result = Postgres.apply_operator(query, :tags, :_excludes_all, [1, 2, 3], [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_excludes_all operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = Postgres.apply_operator(query, :tags, :_excludes_all, [1, 2, 3], binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_includes_any operator without binding" do
      query = from(t in TestSchema)

      result = Postgres.apply_operator(query, :tags, :_includes_any, [1, 2, 3], [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_includes_any operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = Postgres.apply_operator(query, :tags, :_includes_any, [1, 2, 3], binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_excludes_any operator without binding" do
      query = from(t in TestSchema)

      result = Postgres.apply_operator(query, :tags, :_excludes_any, [1, 2, 3], [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_excludes_any operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = Postgres.apply_operator(query, :tags, :_excludes_any, [1, 2, 3], binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_empty true operator without binding" do
      query = from(t in TestSchema)

      result = Postgres.apply_operator(query, :tags, :_is_empty, true, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_empty true operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = Postgres.apply_operator(query, :tags, :_is_empty, true, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_empty false operator without binding" do
      query = from(t in TestSchema)

      result = Postgres.apply_operator(query, :tags, :_is_empty, false, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_empty false operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = Postgres.apply_operator(query, :tags, :_is_empty, false, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null true operator without binding" do
      query = from(t in TestSchema)

      result = Postgres.apply_operator(query, :tags, :_is_null, true, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null true operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = Postgres.apply_operator(query, :tags, :_is_null, true, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null false operator without binding" do
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
end
