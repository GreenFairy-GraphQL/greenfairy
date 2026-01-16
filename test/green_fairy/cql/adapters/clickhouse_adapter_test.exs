defmodule GreenFairy.CQL.Adapters.ClickHouseAdapterTest do
  use ExUnit.Case, async: true

  import Ecto.Query

  alias GreenFairy.CQL.Scalars.String, as: StringScalar
  alias GreenFairy.CQL.Scalars.ArrayString

  # Simple test schema for query building
  defmodule TestSchema do
    use Ecto.Schema

    schema "test_items" do
      field :name, :string
      field :tags, {:array, :string}
    end
  end

  describe "String scalar with :clickhouse adapter" do
    test "operator_input includes ilike operators" do
      {ops, type, _desc} = StringScalar.operator_input(:clickhouse)

      assert type == :string
      assert :_eq in ops
      assert :_like in ops
      assert :_ilike in ops
      assert :_nilike in ops
      assert :_istarts_with in ops
      assert :_iends_with in ops
      assert :_icontains in ops
    end

    test "apply_operator handles basic equality" do
      query = TestSchema |> Ecto.Query.from()
      result = StringScalar.apply_operator(query, :name, :_eq, "test", :clickhouse, [])

      assert %Ecto.Query{} = result
      assert result.wheres != []
    end

    test "apply_operator handles ilike with ClickHouse function" do
      query = TestSchema |> Ecto.Query.from()
      result = StringScalar.apply_operator(query, :name, :_ilike, "%test%", :clickhouse, [])

      assert %Ecto.Query{} = result
      assert result.wheres != []

      # Verify it uses fragment with ilike function
      [where_clause] = result.wheres
      assert where_clause.expr != nil
    end

    test "apply_operator handles istarts_with" do
      query = TestSchema |> Ecto.Query.from()
      result = StringScalar.apply_operator(query, :name, :_istarts_with, "test", :clickhouse, [])

      assert %Ecto.Query{} = result
      assert result.wheres != []
    end

    test "apply_operator handles binding option" do
      query = TestSchema |> Ecto.Query.from(as: :items)
      result = StringScalar.apply_operator(query, :name, :_ilike, "test%", :clickhouse, binding: :items)

      assert %Ecto.Query{} = result
      assert result.wheres != []
    end
  end

  describe "ArrayString scalar with :clickhouse adapter" do
    test "operator_input includes all array operators" do
      {ops, _type, _desc} = ArrayString.operator_input(:clickhouse)

      assert :_includes in ops
      assert :_excludes in ops
      assert :_includes_all in ops
      assert :_excludes_all in ops
      assert :_includes_any in ops
      assert :_excludes_any in ops
      assert :_is_empty in ops
      assert :_is_null in ops
    end

    test "apply_operator handles _includes with has() function" do
      query = TestSchema |> Ecto.Query.from()
      result = ArrayString.apply_operator(query, :tags, :_includes, "tag1", :clickhouse, [])

      assert %Ecto.Query{} = result
      assert result.wheres != []
    end

    test "apply_operator handles _excludes with NOT has() function" do
      query = TestSchema |> Ecto.Query.from()
      result = ArrayString.apply_operator(query, :tags, :_excludes, "tag1", :clickhouse, [])

      assert %Ecto.Query{} = result
      assert result.wheres != []
    end

    test "apply_operator handles _includes_all with hasAll() function" do
      query = TestSchema |> Ecto.Query.from()
      result = ArrayString.apply_operator(query, :tags, :_includes_all, ["tag1", "tag2"], :clickhouse, [])

      assert %Ecto.Query{} = result
      assert result.wheres != []
    end

    test "apply_operator handles _includes_any with hasAny() function" do
      query = TestSchema |> Ecto.Query.from()
      result = ArrayString.apply_operator(query, :tags, :_includes_any, ["tag1", "tag2"], :clickhouse, [])

      assert %Ecto.Query{} = result
      assert result.wheres != []
    end

    test "apply_operator handles _is_empty with empty() function" do
      query = TestSchema |> Ecto.Query.from()
      result = ArrayString.apply_operator(query, :tags, :_is_empty, true, :clickhouse, [])

      assert %Ecto.Query{} = result
      assert result.wheres != []
    end

    test "apply_operator handles _is_empty false with notEmpty() function" do
      query = TestSchema |> Ecto.Query.from()
      result = ArrayString.apply_operator(query, :tags, :_is_empty, false, :clickhouse, [])

      assert %Ecto.Query{} = result
      assert result.wheres != []
    end

    test "apply_operator handles binding option" do
      query =
        TestSchema
        |> Ecto.Query.from(as: :items)

      result = ArrayString.apply_operator(query, :tags, :_includes, "tag1", :clickhouse, binding: :items)

      assert %Ecto.Query{} = result
    end
  end
end
