defmodule GreenFairy.CQL.Scalars.FloatAdaptersTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.Scalars.Float.Ecto, as: FloatEcto
  alias GreenFairy.CQL.Scalars.Float.Exlasticsearch, as: FloatExlasticsearch

  defmodule TestSchema do
    use Ecto.Schema

    schema "test_records" do
      field :price, :float
    end
  end

  describe "Float.Ecto" do
    import Ecto.Query

    test "_eq operator" do
      query = from(t in TestSchema)
      result = FloatEcto.apply_operator(query, :price, :_eq, 19.99, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_gt operator" do
      query = from(t in TestSchema)
      result = FloatEcto.apply_operator(query, :price, :_gt, 10.0, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_lte operator" do
      query = from(t in TestSchema)
      result = FloatEcto.apply_operator(query, :price, :_lte, 100.0, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end

  describe "Float.Exlasticsearch" do
    test "_eq operator delegates to Integer.Exlasticsearch" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = FloatExlasticsearch.apply_operator(query, :price, :_eq, 19.99, [])

      [term_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{term: %{"price" => 19.99}} = term_clause
    end

    test "_gt operator delegates to Integer.Exlasticsearch" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = FloatExlasticsearch.apply_operator(query, :price, :_gt, 10.0, [])

      [range_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{range: %{"price" => %{gt: 10.0}}} = range_clause
    end

    test "_in operator delegates to Integer.Exlasticsearch" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = FloatExlasticsearch.apply_operator(query, :price, :_in, [9.99, 19.99, 29.99], [])

      [terms_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{terms: %{"price" => [9.99, 19.99, 29.99]}} = terms_clause
    end

    test "with binding option" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = FloatExlasticsearch.apply_operator(query, :price, :_eq, 19.99, binding: :product)

      [term_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{term: %{"product.price" => 19.99}} = term_clause
    end
  end
end
