defmodule GreenFairy.CQL.Adapters.EctoAdapterTest do
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

  describe "String scalar with :ecto adapter" do
    test "operator_input returns conservative set without ilike" do
      {ops, type, _desc} = StringScalar.operator_input(:ecto)

      assert type == :string
      assert :_eq in ops
      assert :_like in ops
      assert :_starts_with in ops
      refute :_ilike in ops
      refute :_istarts_with in ops
    end

    test "apply_operator handles basic equality" do
      query = TestSchema |> Ecto.Query.from()
      result = StringScalar.apply_operator(query, :name, :_eq, "test", :ecto, [])

      assert %Ecto.Query{} = result
      # Verify the where clause was added
      assert result.wheres != []
    end

    test "apply_operator handles like pattern" do
      query = TestSchema |> Ecto.Query.from()
      result = StringScalar.apply_operator(query, :name, :_like, "%test%", :ecto, [])

      assert %Ecto.Query{} = result
      assert result.wheres != []
    end

    test "apply_operator returns unchanged query for unsupported operators" do
      query = TestSchema |> Ecto.Query.from()
      result = StringScalar.apply_operator(query, :name, :_ilike, "test", :ecto, [])

      # Should return query unchanged since :_ilike not supported in generic ecto
      assert result == query
    end

    test "fallback to ecto adapter for unknown adapters" do
      {ops, _type, _desc} = StringScalar.operator_input(:some_unknown_adapter)

      # Should get the generic ecto operators
      assert :_eq in ops
      refute :_ilike in ops
    end
  end

  describe "ArrayString scalar with :ecto adapter" do
    test "operator_input returns minimal set" do
      {ops, _type, _desc} = ArrayString.operator_input(:ecto)

      assert :_is_null in ops
      refute :_includes in ops
      refute :_includes_all in ops
    end

    test "apply_operator handles is_null" do
      query = TestSchema |> Ecto.Query.from()
      result = ArrayString.apply_operator(query, :tags, :_is_null, true, :ecto, [])

      assert %Ecto.Query{} = result
      assert result.wheres != []
    end

    test "apply_operator returns unchanged query for unsupported array operators" do
      query = TestSchema |> Ecto.Query.from()
      result = ArrayString.apply_operator(query, :tags, :_includes, "tag1", :ecto, [])

      # Should return query unchanged
      assert result == query
    end
  end
end
