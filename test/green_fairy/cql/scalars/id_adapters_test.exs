defmodule GreenFairy.CQL.Scalars.IDAdaptersTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.Scalars.ID.Ecto, as: IDEcto
  alias GreenFairy.CQL.Scalars.ID.Exlasticsearch, as: IDExlasticsearch

  defmodule TestSchema do
    use Ecto.Schema

    schema "test_records" do
      field :user_id, :binary_id
    end
  end

  describe "ID.Ecto" do
    import Ecto.Query

    test "_eq operator" do
      query = from(t in TestSchema)
      result = IDEcto.apply_operator(query, :user_id, :_eq, "abc-123", [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_eq operator with binding" do
      query = from(t in TestSchema, as: :test)
      result = IDEcto.apply_operator(query, :user_id, :_eq, "abc-123", binding: :test)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_ne operator" do
      query = from(t in TestSchema)
      result = IDEcto.apply_operator(query, :user_id, :_ne, "abc-123", [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_ne operator with binding" do
      query = from(t in TestSchema, as: :test)
      result = IDEcto.apply_operator(query, :user_id, :_ne, "abc-123", binding: :test)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_neq operator" do
      query = from(t in TestSchema)
      result = IDEcto.apply_operator(query, :user_id, :_neq, "abc-123", [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_neq operator with binding" do
      query = from(t in TestSchema, as: :test)
      result = IDEcto.apply_operator(query, :user_id, :_neq, "abc-123", binding: :test)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_in operator" do
      query = from(t in TestSchema)
      result = IDEcto.apply_operator(query, :user_id, :_in, ["abc-123", "def-456"], [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_in operator with binding" do
      query = from(t in TestSchema, as: :test)
      result = IDEcto.apply_operator(query, :user_id, :_in, ["abc-123", "def-456"], binding: :test)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_nin operator" do
      query = from(t in TestSchema)
      result = IDEcto.apply_operator(query, :user_id, :_nin, ["abc-123", "def-456"], [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_nin operator with binding" do
      query = from(t in TestSchema, as: :test)
      result = IDEcto.apply_operator(query, :user_id, :_nin, ["abc-123", "def-456"], binding: :test)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null true operator" do
      query = from(t in TestSchema)
      result = IDEcto.apply_operator(query, :user_id, :_is_null, true, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null true operator with binding" do
      query = from(t in TestSchema, as: :test)
      result = IDEcto.apply_operator(query, :user_id, :_is_null, true, binding: :test)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null false operator" do
      query = from(t in TestSchema)
      result = IDEcto.apply_operator(query, :user_id, :_is_null, false, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null false operator with binding" do
      query = from(t in TestSchema, as: :test)
      result = IDEcto.apply_operator(query, :user_id, :_is_null, false, binding: :test)
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "unknown operator returns query unchanged" do
      query = from(t in TestSchema)
      result = IDEcto.apply_operator(query, :user_id, :_unknown, "value", [])
      assert result == query
    end
  end

  describe "ID.Exlasticsearch" do
    test "_eq operator" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IDExlasticsearch.apply_operator(query, :user_id, :_eq, "abc-123", [])

      [term_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{term: %{"user_id" => "abc-123"}} = term_clause
    end

    test "_eq operator with binding" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IDExlasticsearch.apply_operator(query, :user_id, :_eq, "abc-123", binding: :parent)

      [term_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{term: %{"parent.user_id" => "abc-123"}} = term_clause
    end

    test "_ne operator" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IDExlasticsearch.apply_operator(query, :user_id, :_ne, "abc-123", [])

      [term_clause | _] = get_in(result, [:query, :bool, :must_not])
      assert %{term: %{"user_id" => "abc-123"}} = term_clause
    end

    test "_ne operator with binding" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IDExlasticsearch.apply_operator(query, :user_id, :_ne, "abc-123", binding: :parent)

      [term_clause | _] = get_in(result, [:query, :bool, :must_not])
      assert %{term: %{"parent.user_id" => "abc-123"}} = term_clause
    end

    test "_neq operator" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IDExlasticsearch.apply_operator(query, :user_id, :_neq, "abc-123", [])

      [term_clause | _] = get_in(result, [:query, :bool, :must_not])
      assert %{term: %{"user_id" => "abc-123"}} = term_clause
    end

    test "_in operator" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IDExlasticsearch.apply_operator(query, :user_id, :_in, ["abc-123", "def-456"], [])

      [terms_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{terms: %{"user_id" => ["abc-123", "def-456"]}} = terms_clause
    end

    test "_in operator with binding" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IDExlasticsearch.apply_operator(query, :user_id, :_in, ["abc-123", "def-456"], binding: :parent)

      [terms_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{terms: %{"parent.user_id" => ["abc-123", "def-456"]}} = terms_clause
    end

    test "_nin operator" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IDExlasticsearch.apply_operator(query, :user_id, :_nin, ["abc-123", "def-456"], [])

      [terms_clause | _] = get_in(result, [:query, :bool, :must_not])
      assert %{terms: %{"user_id" => ["abc-123", "def-456"]}} = terms_clause
    end

    test "_nin operator with binding" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IDExlasticsearch.apply_operator(query, :user_id, :_nin, ["abc-123", "def-456"], binding: :parent)

      [terms_clause | _] = get_in(result, [:query, :bool, :must_not])
      assert %{terms: %{"parent.user_id" => ["abc-123", "def-456"]}} = terms_clause
    end

    test "_is_null true operator" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IDExlasticsearch.apply_operator(query, :user_id, :_is_null, true, [])

      [exists_clause | _] = get_in(result, [:query, :bool, :must_not])
      assert %{exists: %{field: "user_id"}} = exists_clause
    end

    test "_is_null false operator" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IDExlasticsearch.apply_operator(query, :user_id, :_is_null, false, [])

      [exists_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{exists: %{field: "user_id"}} = exists_clause
    end

    test "unknown operator returns query unchanged" do
      query = %{query: %{bool: %{must: [], must_not: []}}}
      result = IDExlasticsearch.apply_operator(query, :user_id, :_unknown, "value", [])
      assert result == query
    end
  end
end
