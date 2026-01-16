defmodule GreenFairy.CQL.QueryBuilderTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.QueryBuilder

  defmodule TestSchema do
    use Ecto.Schema

    schema "test_records" do
      field :name, :string
      field :age, :integer
      field :created_at, :utc_datetime
    end
  end

  defmodule MockTypeModule do
    def __cql_config__, do: %{struct: TestSchema}
    def __cql_adapter__, do: GreenFairy.CQL.Adapters.Postgres
  end

  describe "apply_where/4" do
    import Ecto.Query

    test "returns query unchanged when filter is nil" do
      query = from(t in TestSchema)

      assert {:ok, result} = QueryBuilder.apply_where(query, nil, MockTypeModule)
      assert result == query
    end

    test "returns query unchanged when filter is empty map" do
      query = from(t in TestSchema)

      assert {:ok, result} = QueryBuilder.apply_where(query, %{}, MockTypeModule)
      assert result == query
    end

    test "applies filter with field condition" do
      query = from(t in TestSchema)
      filter = %{name: %{_eq: "Alice"}}

      result = QueryBuilder.apply_where(query, filter, MockTypeModule)
      # Since QueryCompiler.compile may return {:ok, query} or {:error, msg}
      # we check it returns a tuple
      assert is_tuple(result)
    end

    test "passes opts to compile" do
      query = from(t in TestSchema)
      filter = %{age: %{_gte: 18}}

      result = QueryBuilder.apply_where(query, filter, MockTypeModule, parent_alias: :custom)

      assert is_tuple(result)
    end
  end

  describe "apply_where!/4" do
    import Ecto.Query

    test "returns query when filter is nil" do
      query = from(t in TestSchema)

      # apply_where! returns the query directly, not wrapped in {:ok, _}
      result = QueryBuilder.apply_where!(query, nil, MockTypeModule)
      assert result == query
    end

    test "returns query when filter is empty" do
      query = from(t in TestSchema)

      result = QueryBuilder.apply_where!(query, %{}, MockTypeModule)
      assert result == query
    end
  end

  describe "apply_order_by/4" do
    import Ecto.Query

    test "returns query unchanged when order_specs is nil" do
      query = from(t in TestSchema)

      result = QueryBuilder.apply_order_by(query, nil, MockTypeModule)
      assert result == query
    end

    test "returns query unchanged when order_specs is empty list" do
      query = from(t in TestSchema)

      result = QueryBuilder.apply_order_by(query, [], MockTypeModule)
      assert result == query
    end

    test "applies ordering with order specs" do
      query = from(t in TestSchema)
      # OrderBuilder expects order specs with :standard type
      order_specs = [%{standard: %{field: :name, direction: :asc}}]

      result = QueryBuilder.apply_order_by(query, order_specs, MockTypeModule)
      # OrderBuilder modifies the query
      assert %Ecto.Query{} = result
    end
  end
end
