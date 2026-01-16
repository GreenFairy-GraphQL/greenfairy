defmodule GreenFairy.CQL.Scalars.IntegerAdaptersTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.Scalars.Integer.Ecto, as: IntegerEcto
  alias GreenFairy.CQL.Scalars.Integer.Exlasticsearch, as: IntegerExlasticsearch

  defmodule TestSchema do
    use Ecto.Schema

    schema "test_records" do
      field :age, :integer
      field :score, :integer
    end
  end

  describe "Integer.Ecto" do
    import Ecto.Query

    test "_eq operator" do
      query = from(t in TestSchema)
      result = IntegerEcto.apply_operator(query, :age, :_eq, 25, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_eq operator with binding" do
      query = from(t in TestSchema, as: :test)
      result = IntegerEcto.apply_operator(query, :age, :_eq, 25, binding: :test)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_ne operator" do
      query = from(t in TestSchema)
      result = IntegerEcto.apply_operator(query, :age, :_ne, 25, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_ne operator with binding" do
      query = from(t in TestSchema, as: :test)
      result = IntegerEcto.apply_operator(query, :age, :_ne, 25, binding: :test)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_neq operator" do
      query = from(t in TestSchema)
      result = IntegerEcto.apply_operator(query, :age, :_neq, 25, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_neq operator with binding" do
      query = from(t in TestSchema, as: :test)
      result = IntegerEcto.apply_operator(query, :age, :_neq, 25, binding: :test)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_gt operator" do
      query = from(t in TestSchema)
      result = IntegerEcto.apply_operator(query, :age, :_gt, 18, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_gt operator with binding" do
      query = from(t in TestSchema, as: :test)
      result = IntegerEcto.apply_operator(query, :age, :_gt, 18, binding: :test)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_gte operator" do
      query = from(t in TestSchema)
      result = IntegerEcto.apply_operator(query, :age, :_gte, 18, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_gte operator with binding" do
      query = from(t in TestSchema, as: :test)
      result = IntegerEcto.apply_operator(query, :age, :_gte, 18, binding: :test)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_lt operator" do
      query = from(t in TestSchema)
      result = IntegerEcto.apply_operator(query, :age, :_lt, 65, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_lt operator with binding" do
      query = from(t in TestSchema, as: :test)
      result = IntegerEcto.apply_operator(query, :age, :_lt, 65, binding: :test)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_lte operator" do
      query = from(t in TestSchema)
      result = IntegerEcto.apply_operator(query, :age, :_lte, 65, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_lte operator with binding" do
      query = from(t in TestSchema, as: :test)
      result = IntegerEcto.apply_operator(query, :age, :_lte, 65, binding: :test)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_in operator" do
      query = from(t in TestSchema)
      result = IntegerEcto.apply_operator(query, :age, :_in, [18, 21, 25], [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_in operator with binding" do
      query = from(t in TestSchema, as: :test)
      result = IntegerEcto.apply_operator(query, :age, :_in, [18, 21, 25], binding: :test)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_nin operator" do
      query = from(t in TestSchema)
      result = IntegerEcto.apply_operator(query, :age, :_nin, [0, -1], [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_nin operator with binding" do
      query = from(t in TestSchema, as: :test)
      result = IntegerEcto.apply_operator(query, :age, :_nin, [0, -1], binding: :test)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null true operator" do
      query = from(t in TestSchema)
      result = IntegerEcto.apply_operator(query, :age, :_is_null, true, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null true operator with binding" do
      query = from(t in TestSchema, as: :test)
      result = IntegerEcto.apply_operator(query, :age, :_is_null, true, binding: :test)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null false operator" do
      query = from(t in TestSchema)
      result = IntegerEcto.apply_operator(query, :age, :_is_null, false, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null false operator with binding" do
      query = from(t in TestSchema, as: :test)
      result = IntegerEcto.apply_operator(query, :age, :_is_null, false, binding: :test)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "unknown operator returns query unchanged" do
      query = from(t in TestSchema)
      result = IntegerEcto.apply_operator(query, :age, :_unknown, 25, [])
      assert result == query
    end
  end

  describe "Integer.Exlasticsearch" do
    test "_eq operator" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IntegerExlasticsearch.apply_operator(query, :age, :_eq, 25, [])

      [term_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{term: %{"age" => 25}} = term_clause
    end

    test "_ne operator" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IntegerExlasticsearch.apply_operator(query, :age, :_ne, 25, [])

      [term_clause | _] = get_in(result, [:query, :bool, :must_not])
      assert %{term: %{"age" => 25}} = term_clause
    end

    test "_neq operator" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IntegerExlasticsearch.apply_operator(query, :age, :_neq, 25, [])

      [term_clause | _] = get_in(result, [:query, :bool, :must_not])
      assert %{term: %{"age" => 25}} = term_clause
    end

    test "_gt operator" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IntegerExlasticsearch.apply_operator(query, :age, :_gt, 18, [])

      [range_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{range: %{"age" => %{gt: 18}}} = range_clause
    end

    test "_gte operator" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IntegerExlasticsearch.apply_operator(query, :age, :_gte, 18, [])

      [range_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{range: %{"age" => %{gte: 18}}} = range_clause
    end

    test "_lt operator" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IntegerExlasticsearch.apply_operator(query, :age, :_lt, 65, [])

      [range_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{range: %{"age" => %{lt: 65}}} = range_clause
    end

    test "_lte operator" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IntegerExlasticsearch.apply_operator(query, :age, :_lte, 65, [])

      [range_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{range: %{"age" => %{lte: 65}}} = range_clause
    end

    test "_in operator" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IntegerExlasticsearch.apply_operator(query, :age, :_in, [18, 21, 25], [])

      [terms_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{terms: %{"age" => [18, 21, 25]}} = terms_clause
    end

    test "_nin operator" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IntegerExlasticsearch.apply_operator(query, :age, :_nin, [0, -1], [])

      [terms_clause | _] = get_in(result, [:query, :bool, :must_not])
      assert %{terms: %{"age" => [0, -1]}} = terms_clause
    end

    test "_is_null true operator" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IntegerExlasticsearch.apply_operator(query, :age, :_is_null, true, [])

      [exists_clause | _] = get_in(result, [:query, :bool, :must_not])
      assert %{exists: %{field: "age"}} = exists_clause
    end

    test "_is_null false operator" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IntegerExlasticsearch.apply_operator(query, :age, :_is_null, false, [])

      [exists_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{exists: %{field: "age"}} = exists_clause
    end

    test "with binding option" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IntegerExlasticsearch.apply_operator(query, :age, :_eq, 25, binding: :user)

      [term_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{term: %{"user.age" => 25}} = term_clause
    end

    test "unknown operator returns query unchanged" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IntegerExlasticsearch.apply_operator(query, :age, :_unknown, 25, [])
      assert result == query
    end
  end
end
