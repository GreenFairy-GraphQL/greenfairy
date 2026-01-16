defmodule GreenFairy.CQL.Scalars.StringAdaptersTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.Scalars.String.MySQL, as: StringMySQL
  alias GreenFairy.CQL.Scalars.String.SQLite, as: StringSQLite
  alias GreenFairy.CQL.Scalars.String.MSSQL, as: StringMSSQL

  defmodule TestSchema do
    use Ecto.Schema

    schema "test_records" do
      field :name, :string
      field :description, :string
    end
  end

  describe "String.MySQL" do
    import Ecto.Query

    test "operator_input returns MySQL operators" do
      {operators, type, _desc} = StringMySQL.operator_input()

      assert :_eq in operators
      assert :_like in operators
      assert :_nlike in operators
      assert :_contains in operators
      assert :_starts_with in operators
      assert :_ends_with in operators
      assert :_ilike in operators
      assert :_icontains in operators
      assert type == :string
    end

    test "_eq operator" do
      query = from(t in TestSchema)

      result = StringMySQL.apply_operator(query, :name, :_eq, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_eq operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = StringMySQL.apply_operator(query, :name, :_eq, "test", binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_ne operator" do
      query = from(t in TestSchema)

      result = StringMySQL.apply_operator(query, :name, :_ne, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_ne operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = StringMySQL.apply_operator(query, :name, :_ne, "test", binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_like operator" do
      query = from(t in TestSchema)

      result = StringMySQL.apply_operator(query, :name, :_like, "%test%", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_like operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = StringMySQL.apply_operator(query, :name, :_like, "%test%", binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_nlike operator" do
      query = from(t in TestSchema)

      result = StringMySQL.apply_operator(query, :name, :_nlike, "%test%", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_nlike operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = StringMySQL.apply_operator(query, :name, :_nlike, "%test%", binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_contains operator" do
      query = from(t in TestSchema)

      result = StringMySQL.apply_operator(query, :name, :_contains, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_starts_with operator" do
      query = from(t in TestSchema)

      result = StringMySQL.apply_operator(query, :name, :_starts_with, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_ends_with operator" do
      query = from(t in TestSchema)

      result = StringMySQL.apply_operator(query, :name, :_ends_with, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_in operator" do
      query = from(t in TestSchema)

      result = StringMySQL.apply_operator(query, :name, :_in, ["a", "b", "c"], [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_nin operator" do
      query = from(t in TestSchema)

      result = StringMySQL.apply_operator(query, :name, :_nin, ["x", "y"], [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null true operator" do
      query = from(t in TestSchema)

      result = StringMySQL.apply_operator(query, :name, :_is_null, true, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null false operator" do
      query = from(t in TestSchema)

      result = StringMySQL.apply_operator(query, :name, :_is_null, false, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "unknown operator returns query unchanged" do
      query = from(t in TestSchema)

      result = StringMySQL.apply_operator(query, :name, :_unknown, "value", [])

      assert result == query
    end

    test "_ilike operator" do
      query = from(t in TestSchema)

      result = StringMySQL.apply_operator(query, :name, :_ilike, "%test%", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_ilike operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = StringMySQL.apply_operator(query, :name, :_ilike, "%test%", binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_nilike operator" do
      query = from(t in TestSchema)

      result = StringMySQL.apply_operator(query, :name, :_nilike, "%test%", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_nilike operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = StringMySQL.apply_operator(query, :name, :_nilike, "%test%", binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_istarts_with operator" do
      query = from(t in TestSchema)

      result = StringMySQL.apply_operator(query, :name, :_istarts_with, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_istarts_with operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = StringMySQL.apply_operator(query, :name, :_istarts_with, "test", binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_iends_with operator" do
      query = from(t in TestSchema)

      result = StringMySQL.apply_operator(query, :name, :_iends_with, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_iends_with operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = StringMySQL.apply_operator(query, :name, :_iends_with, "test", binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_icontains operator" do
      query = from(t in TestSchema)

      result = StringMySQL.apply_operator(query, :name, :_icontains, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_icontains operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = StringMySQL.apply_operator(query, :name, :_icontains, "test", binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_gt operator" do
      query = from(t in TestSchema)

      result = StringMySQL.apply_operator(query, :name, :_gt, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_gte operator" do
      query = from(t in TestSchema)

      result = StringMySQL.apply_operator(query, :name, :_gte, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_lt operator" do
      query = from(t in TestSchema)

      result = StringMySQL.apply_operator(query, :name, :_lt, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_lte operator" do
      query = from(t in TestSchema)

      result = StringMySQL.apply_operator(query, :name, :_lte, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_neq operator" do
      query = from(t in TestSchema)

      result = StringMySQL.apply_operator(query, :name, :_neq, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end

  describe "String.SQLite" do
    import Ecto.Query

    test "operator_input returns SQLite operators" do
      {operators, type, _desc} = StringSQLite.operator_input()

      assert :_eq in operators
      assert :_like in operators
      assert :_nlike in operators
      assert :_contains in operators
      assert :_starts_with in operators
      assert :_ends_with in operators
      assert type == :string
    end

    test "_eq operator" do
      query = from(t in TestSchema)

      result = StringSQLite.apply_operator(query, :name, :_eq, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_eq operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = StringSQLite.apply_operator(query, :name, :_eq, "test", binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_ne operator" do
      query = from(t in TestSchema)

      result = StringSQLite.apply_operator(query, :name, :_ne, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_like operator" do
      query = from(t in TestSchema)

      result = StringSQLite.apply_operator(query, :name, :_like, "%test%", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_nlike operator" do
      query = from(t in TestSchema)

      result = StringSQLite.apply_operator(query, :name, :_nlike, "%test%", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_contains operator" do
      query = from(t in TestSchema)

      result = StringSQLite.apply_operator(query, :name, :_contains, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_starts_with operator" do
      query = from(t in TestSchema)

      result = StringSQLite.apply_operator(query, :name, :_starts_with, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_ends_with operator" do
      query = from(t in TestSchema)

      result = StringSQLite.apply_operator(query, :name, :_ends_with, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_in operator" do
      query = from(t in TestSchema)

      result = StringSQLite.apply_operator(query, :name, :_in, ["a", "b", "c"], [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_nin operator" do
      query = from(t in TestSchema)

      result = StringSQLite.apply_operator(query, :name, :_nin, ["x", "y"], [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null true operator" do
      query = from(t in TestSchema)

      result = StringSQLite.apply_operator(query, :name, :_is_null, true, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null false operator" do
      query = from(t in TestSchema)

      result = StringSQLite.apply_operator(query, :name, :_is_null, false, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "unknown operator returns query unchanged" do
      query = from(t in TestSchema)

      result = StringSQLite.apply_operator(query, :name, :_unknown, "value", [])

      assert result == query
    end

    test "_gt operator" do
      query = from(t in TestSchema)

      result = StringSQLite.apply_operator(query, :name, :_gt, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_gte operator" do
      query = from(t in TestSchema)

      result = StringSQLite.apply_operator(query, :name, :_gte, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_lt operator" do
      query = from(t in TestSchema)

      result = StringSQLite.apply_operator(query, :name, :_lt, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_lte operator" do
      query = from(t in TestSchema)

      result = StringSQLite.apply_operator(query, :name, :_lte, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_neq operator" do
      query = from(t in TestSchema)

      result = StringSQLite.apply_operator(query, :name, :_neq, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end

  describe "String.MSSQL" do
    import Ecto.Query

    test "operator_input returns MSSQL operators" do
      {operators, type, _desc} = StringMSSQL.operator_input()

      assert :_eq in operators
      assert :_like in operators
      assert :_nlike in operators
      assert :_contains in operators
      assert :_starts_with in operators
      assert :_ends_with in operators
      assert type == :string
    end

    test "_eq operator" do
      query = from(t in TestSchema)

      result = StringMSSQL.apply_operator(query, :name, :_eq, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_eq operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = StringMSSQL.apply_operator(query, :name, :_eq, "test", binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_ne operator" do
      query = from(t in TestSchema)

      result = StringMSSQL.apply_operator(query, :name, :_ne, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_like operator" do
      query = from(t in TestSchema)

      result = StringMSSQL.apply_operator(query, :name, :_like, "%test%", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_nlike operator" do
      query = from(t in TestSchema)

      result = StringMSSQL.apply_operator(query, :name, :_nlike, "%test%", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_contains operator" do
      query = from(t in TestSchema)

      result = StringMSSQL.apply_operator(query, :name, :_contains, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_starts_with operator" do
      query = from(t in TestSchema)

      result = StringMSSQL.apply_operator(query, :name, :_starts_with, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_ends_with operator" do
      query = from(t in TestSchema)

      result = StringMSSQL.apply_operator(query, :name, :_ends_with, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_in operator" do
      query = from(t in TestSchema)

      result = StringMSSQL.apply_operator(query, :name, :_in, ["a", "b", "c"], [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_nin operator" do
      query = from(t in TestSchema)

      result = StringMSSQL.apply_operator(query, :name, :_nin, ["x", "y"], [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null true operator" do
      query = from(t in TestSchema)

      result = StringMSSQL.apply_operator(query, :name, :_is_null, true, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null false operator" do
      query = from(t in TestSchema)

      result = StringMSSQL.apply_operator(query, :name, :_is_null, false, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "unknown operator returns query unchanged" do
      query = from(t in TestSchema)

      result = StringMSSQL.apply_operator(query, :name, :_unknown, "value", [])

      assert result == query
    end

    test "_ilike operator" do
      query = from(t in TestSchema)

      result = StringMSSQL.apply_operator(query, :name, :_ilike, "%test%", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_ilike operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = StringMSSQL.apply_operator(query, :name, :_ilike, "%test%", binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_nilike operator" do
      query = from(t in TestSchema)

      result = StringMSSQL.apply_operator(query, :name, :_nilike, "%test%", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_nilike operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = StringMSSQL.apply_operator(query, :name, :_nilike, "%test%", binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_istarts_with operator" do
      query = from(t in TestSchema)

      result = StringMSSQL.apply_operator(query, :name, :_istarts_with, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_istarts_with operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = StringMSSQL.apply_operator(query, :name, :_istarts_with, "test", binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_iends_with operator" do
      query = from(t in TestSchema)

      result = StringMSSQL.apply_operator(query, :name, :_iends_with, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_iends_with operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = StringMSSQL.apply_operator(query, :name, :_iends_with, "test", binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_icontains operator" do
      query = from(t in TestSchema)

      result = StringMSSQL.apply_operator(query, :name, :_icontains, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_icontains operator with binding" do
      query = from(t in TestSchema, as: :record)

      result = StringMSSQL.apply_operator(query, :name, :_icontains, "test", binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_gt operator" do
      query = from(t in TestSchema)

      result = StringMSSQL.apply_operator(query, :name, :_gt, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_gte operator" do
      query = from(t in TestSchema)

      result = StringMSSQL.apply_operator(query, :name, :_gte, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_lt operator" do
      query = from(t in TestSchema)

      result = StringMSSQL.apply_operator(query, :name, :_lt, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_lte operator" do
      query = from(t in TestSchema)

      result = StringMSSQL.apply_operator(query, :name, :_lte, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_neq operator" do
      query = from(t in TestSchema)

      result = StringMSSQL.apply_operator(query, :name, :_neq, "test", [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end
end
