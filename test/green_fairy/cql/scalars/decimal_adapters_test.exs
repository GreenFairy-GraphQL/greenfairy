defmodule GreenFairy.CQL.Scalars.DecimalAdaptersTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.Scalars.Decimal.Ecto, as: DecimalEcto
  alias GreenFairy.CQL.Scalars.Decimal.Exlasticsearch, as: DecimalExlasticsearch

  defmodule TestSchema do
    use Ecto.Schema

    schema "test_records" do
      field :price, :decimal
      field :tax_rate, :decimal
    end
  end

  describe "Decimal.Ecto" do
    import Ecto.Query

    test "_eq operator delegates to Integer.Ecto" do
      query = from(t in TestSchema)
      result = DecimalEcto.apply_operator(query, :price, :_eq, Decimal.new("19.99"), [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_gt operator delegates to Integer.Ecto" do
      query = from(t in TestSchema)
      result = DecimalEcto.apply_operator(query, :price, :_gt, Decimal.new("10.00"), [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_lte operator delegates to Integer.Ecto" do
      query = from(t in TestSchema)
      result = DecimalEcto.apply_operator(query, :price, :_lte, Decimal.new("100.00"), [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_in operator delegates to Integer.Ecto" do
      query = from(t in TestSchema)
      values = [Decimal.new("9.99"), Decimal.new("19.99"), Decimal.new("29.99")]
      result = DecimalEcto.apply_operator(query, :price, :_in, values, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "with binding option" do
      query = from(t in TestSchema, as: :test)
      result = DecimalEcto.apply_operator(query, :price, :_eq, Decimal.new("19.99"), binding: :test)
      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end

  describe "Decimal.Exlasticsearch" do
    test "_eq operator delegates to Integer.Exlasticsearch" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = DecimalExlasticsearch.apply_operator(query, :price, :_eq, 19.99, [])

      [term_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{term: %{"price" => 19.99}} = term_clause
    end

    test "_gt operator delegates to Integer.Exlasticsearch" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = DecimalExlasticsearch.apply_operator(query, :price, :_gt, 10.0, [])

      [range_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{range: %{"price" => %{gt: 10.0}}} = range_clause
    end

    test "_in operator delegates to Integer.Exlasticsearch" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = DecimalExlasticsearch.apply_operator(query, :price, :_in, [9.99, 19.99, 29.99], [])

      [terms_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{terms: %{"price" => [9.99, 19.99, 29.99]}} = terms_clause
    end

    test "with binding option" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = DecimalExlasticsearch.apply_operator(query, :price, :_eq, 19.99, binding: :product)

      [term_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{term: %{"product.price" => 19.99}} = term_clause
    end
  end
end
