defmodule GreenFairy.CQL.Scalars.BooleanAdaptersTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.Scalars.Boolean.Ecto, as: BooleanEcto
  alias GreenFairy.CQL.Scalars.Boolean.Exlasticsearch, as: BooleanExlasticsearch

  defmodule TestSchema do
    use Ecto.Schema

    schema "test_records" do
      field :active, :boolean
      field :verified, :boolean
    end
  end

  describe "Boolean.Ecto" do
    import Ecto.Query

    test "_eq true operator" do
      query = from(t in TestSchema)
      result = BooleanEcto.apply_operator(query, :active, :_eq, true, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_eq false operator" do
      query = from(t in TestSchema)
      result = BooleanEcto.apply_operator(query, :active, :_eq, false, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_eq operator with binding" do
      query = from(t in TestSchema, as: :test)
      result = BooleanEcto.apply_operator(query, :active, :_eq, true, binding: :test)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_ne operator" do
      query = from(t in TestSchema)
      result = BooleanEcto.apply_operator(query, :active, :_ne, true, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_ne operator with binding" do
      query = from(t in TestSchema, as: :test)
      result = BooleanEcto.apply_operator(query, :active, :_ne, false, binding: :test)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_neq operator" do
      query = from(t in TestSchema)
      result = BooleanEcto.apply_operator(query, :active, :_neq, true, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_neq operator with binding" do
      query = from(t in TestSchema, as: :test)
      result = BooleanEcto.apply_operator(query, :active, :_neq, true, binding: :test)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null true operator" do
      query = from(t in TestSchema)
      result = BooleanEcto.apply_operator(query, :active, :_is_null, true, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null true operator with binding" do
      query = from(t in TestSchema, as: :test)
      result = BooleanEcto.apply_operator(query, :active, :_is_null, true, binding: :test)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null false operator" do
      query = from(t in TestSchema)
      result = BooleanEcto.apply_operator(query, :active, :_is_null, false, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null false operator with binding" do
      query = from(t in TestSchema, as: :test)
      result = BooleanEcto.apply_operator(query, :active, :_is_null, false, binding: :test)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "unknown operator returns query unchanged" do
      query = from(t in TestSchema)
      result = BooleanEcto.apply_operator(query, :active, :_unknown, true, [])
      assert result == query
    end
  end

  describe "Boolean.Exlasticsearch" do
    test "_eq true operator" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = BooleanExlasticsearch.apply_operator(query, :active, :_eq, true, [])

      [term_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{term: %{"active" => true}} = term_clause
    end

    test "_eq false operator" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = BooleanExlasticsearch.apply_operator(query, :active, :_eq, false, [])

      [term_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{term: %{"active" => false}} = term_clause
    end

    test "_eq with binding" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = BooleanExlasticsearch.apply_operator(query, :active, :_eq, true, binding: :user)

      [term_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{term: %{"user.active" => true}} = term_clause
    end

    test "_ne operator" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = BooleanExlasticsearch.apply_operator(query, :active, :_ne, true, [])

      [term_clause | _] = get_in(result, [:query, :bool, :must_not])
      assert %{term: %{"active" => true}} = term_clause
    end

    test "_neq operator" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = BooleanExlasticsearch.apply_operator(query, :active, :_neq, false, [])

      [term_clause | _] = get_in(result, [:query, :bool, :must_not])
      assert %{term: %{"active" => false}} = term_clause
    end

    test "_is_null true operator" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = BooleanExlasticsearch.apply_operator(query, :active, :_is_null, true, [])

      [exists_clause | _] = get_in(result, [:query, :bool, :must_not])
      assert %{exists: %{field: "active"}} = exists_clause
    end

    test "_is_null false operator" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = BooleanExlasticsearch.apply_operator(query, :active, :_is_null, false, [])

      [exists_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{exists: %{field: "active"}} = exists_clause
    end

    test "unknown operator returns query unchanged" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = BooleanExlasticsearch.apply_operator(query, :active, :_unknown, true, [])
      assert result == query
    end
  end
end
