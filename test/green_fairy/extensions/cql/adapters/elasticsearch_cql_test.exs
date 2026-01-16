defmodule GreenFairy.CQL.Adapters.ElasticsearchTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.Adapters.Elasticsearch

  # NOTE: Elasticsearch tests use Query DSL (map-based) instead of Ecto queries.
  # The adapter and scalars implement ES-specific query building.

  describe "adapter behavior" do
    test "implements required callbacks" do
      Code.ensure_loaded!(Elasticsearch)
      assert function_exported?(Elasticsearch, :supported_operators, 2)
      assert function_exported?(Elasticsearch, :apply_operator, 5)
      assert function_exported?(Elasticsearch, :capabilities, 0)
    end

    test "capabilities/0 returns expected capabilities" do
      capabilities = Elasticsearch.capabilities()

      assert capabilities.array_operators_require_type_cast == false
      assert capabilities.supports_json_operators == true
      assert capabilities.supports_full_text_search == true
      assert capabilities.max_in_clause_items == 65536
      assert capabilities.native_arrays == true
      assert capabilities.query_dsl_based == true
      assert capabilities.supports_fuzzy_search == true
      assert capabilities.supports_geo_queries == true
      assert capabilities.supports_nested_documents == true
    end
  end

  describe "supported_operators/2" do
    test "returns comprehensive scalar operators" do
      operators = Elasticsearch.supported_operators(:scalar, :string)

      # Standard operators
      assert :_eq in operators
      assert :_neq in operators
      assert :_gt in operators
      assert :_in in operators
      assert :_like in operators
      assert :_ilike in operators
      assert :_contains in operators

      # ES-specific operators
      assert :_fuzzy in operators
      assert :_prefix in operators
      assert :_regexp in operators
    end

    test "returns array operators with native support" do
      operators = Elasticsearch.supported_operators(:array, :string)

      # Elasticsearch has native array support
      assert :_includes in operators
      assert :_excludes in operators
      assert :_includes_all in operators
      assert :_includes_any in operators
      assert :_is_empty in operators
      assert :_is_null in operators
    end

    test "returns json operators" do
      operators = Elasticsearch.supported_operators(:json, :map)

      assert :_contains in operators
      assert :_has_key in operators
      assert :_nested in operators
    end
  end

  describe "init_query/0" do
    test "initializes empty Query DSL structure" do
      query = Elasticsearch.init_query()

      assert is_map(query)
      assert Map.has_key?(query, :query)
      assert Map.has_key?(query[:query], :bool)

      bool_query = query[:query][:bool]
      assert bool_query[:must] == []
      assert bool_query[:must_not] == []
      assert bool_query[:should] == []
      assert bool_query[:filter] == []
    end
  end

  describe "scalar operators - term queries" do
    setup do
      query = Elasticsearch.init_query()
      {:ok, query: query}
    end

    test "_eq creates term query", %{query: query} do
      result = Elasticsearch.apply_operator(query, :name, :_eq, "John", [field_type: :string])

      assert is_map(result)
      [term_clause | _] = result[:query][:bool][:must]
      assert Map.has_key?(term_clause, :term)
    end

    test "_neq creates must_not term query", %{query: query} do
      result = Elasticsearch.apply_operator(query, :name, :_neq, "Spam", [field_type: :string])

      assert is_map(result)
      [term_clause | _] = result[:query][:bool][:must_not]
      assert Map.has_key?(term_clause, :term)
    end
  end

  describe "range queries" do
    setup do
      query = Elasticsearch.init_query()
      {:ok, query: query}
    end

    test "_gt creates range query with gt", %{query: query} do
      result = Elasticsearch.apply_operator(query, :age, :_gt, 18, [field_type: :integer])

      [range_clause | _] = result[:query][:bool][:must]
      assert Map.has_key?(range_clause, :range)
    end

    test "_gte creates range query with gte", %{query: query} do
      result = Elasticsearch.apply_operator(query, :age, :_gte, 18, [field_type: :integer])

      [range_clause | _] = result[:query][:bool][:must]
      assert Map.has_key?(range_clause, :range)
    end

    test "_lt creates range query with lt", %{query: query} do
      result = Elasticsearch.apply_operator(query, :age, :_lt, 65, [field_type: :integer])

      [range_clause | _] = result[:query][:bool][:must]
      assert Map.has_key?(range_clause, :range)
    end

    test "_lte creates range query with lte", %{query: query} do
      result = Elasticsearch.apply_operator(query, :age, :_lte, 65, [field_type: :integer])

      [range_clause | _] = result[:query][:bool][:must]
      assert Map.has_key?(range_clause, :range)
    end
  end

  describe "terms queries" do
    setup do
      query = Elasticsearch.init_query()
      {:ok, query: query}
    end

    test "_in creates terms query", %{query: query} do
      result = Elasticsearch.apply_operator(query, :status, :_in, ["active", "pending"], [field_type: :string])

      [terms_clause | _] = result[:query][:bool][:must]
      assert Map.has_key?(terms_clause, :terms)
    end

    test "_nin creates must_not terms query", %{query: query} do
      result = Elasticsearch.apply_operator(query, :status, :_nin, ["spam", "deleted"], [field_type: :string])

      [terms_clause | _] = result[:query][:bool][:must_not]
      assert Map.has_key?(terms_clause, :terms)
    end
  end

  describe "existence queries" do
    setup do
      query = Elasticsearch.init_query()
      {:ok, query: query}
    end

    test "_is_null with true creates must_not exists", %{query: query} do
      result = Elasticsearch.apply_operator(query, :deleted_at, :_is_null, true, [field_type: :utc_datetime])

      [exists_clause | _] = result[:query][:bool][:must_not]
      assert Map.has_key?(exists_clause, :exists)
    end

    test "_is_null with false creates exists query", %{query: query} do
      result = Elasticsearch.apply_operator(query, :deleted_at, :_is_null, false, [field_type: :utc_datetime])

      [exists_clause | _] = result[:query][:bool][:must]
      assert Map.has_key?(exists_clause, :exists)
    end
  end

  describe "wildcard and pattern matching" do
    setup do
      query = Elasticsearch.init_query()
      {:ok, query: query}
    end

    test "_like creates wildcard query", %{query: query} do
      result = Elasticsearch.apply_operator(query, :name, :_like, "%john%", [field_type: :string])

      [wildcard_clause | _] = result[:query][:bool][:must]
      assert Map.has_key?(wildcard_clause, :wildcard)
    end

    test "_ilike creates case-insensitive wildcard query", %{query: query} do
      result = Elasticsearch.apply_operator(query, :name, :_ilike, "%JOHN%", [field_type: :string])

      [wildcard_clause | _] = result[:query][:bool][:must]
      assert Map.has_key?(wildcard_clause, :wildcard)
    end

    test "_starts_with creates prefix query", %{query: query} do
      result = Elasticsearch.apply_operator(query, :name, :_starts_with, "Jo", [field_type: :string])

      [prefix_clause | _] = result[:query][:bool][:must]
      assert Map.has_key?(prefix_clause, :prefix)
    end

    test "_contains creates match_phrase query", %{query: query} do
      result = Elasticsearch.apply_operator(query, :description, :_contains, "search term", [field_type: :string])

      [match_clause | _] = result[:query][:bool][:must]
      assert Map.has_key?(match_clause, :match_phrase)
    end

    test "_icontains creates match query", %{query: query} do
      result = Elasticsearch.apply_operator(query, :description, :_icontains, "search", [field_type: :string])

      [match_clause | _] = result[:query][:bool][:must]
      assert Map.has_key?(match_clause, :match)
    end
  end

  describe "array operators - native support" do
    setup do
      query = Elasticsearch.init_query()
      {:ok, query: query}
    end

    test "_includes creates term query for array field", %{query: query} do
      result = Elasticsearch.apply_operator(query, :tags, :_includes, "premium", [field_type: {:array, :string}])

      [term_clause | _] = result[:query][:bool][:must]
      assert Map.has_key?(term_clause, :term)
    end

    test "_excludes creates must_not term query", %{query: query} do
      result = Elasticsearch.apply_operator(query, :tags, :_excludes, "spam", [field_type: {:array, :string}])

      [term_clause | _] = result[:query][:bool][:must_not]
      assert Map.has_key?(term_clause, :term)
    end

    test "_includes_all creates multiple term queries", %{query: query} do
      result = Elasticsearch.apply_operator(query, :tags, :_includes_all, ["premium", "verified"], [field_type: {:array, :string}])

      # Should have 2 term clauses in must (one for each value)
      must_clauses = result[:query][:bool][:must]
      assert length(must_clauses) == 2
      assert Enum.all?(must_clauses, &Map.has_key?(&1, :term))
    end

    test "_includes_any creates terms query", %{query: query} do
      result = Elasticsearch.apply_operator(query, :tags, :_includes_any, ["premium", "verified"], [field_type: {:array, :string}])

      [terms_clause | _] = result[:query][:bool][:must]
      assert Map.has_key?(terms_clause, :terms)
    end

    test "_is_empty creates script query", %{query: query} do
      result = Elasticsearch.apply_operator(query, :tags, :_is_empty, true, [field_type: {:array, :string}])

      [script_clause | _] = result[:query][:bool][:must]
      assert Map.has_key?(script_clause, :script)
    end
  end

  describe "Elasticsearch-specific operators" do
    setup do
      query = Elasticsearch.init_query()
      {:ok, query: query}
    end

    test "_fuzzy creates fuzzy query", %{query: query} do
      result = Elasticsearch.apply_operator(query, :name, :_fuzzy, "john", [field_type: :string])

      [fuzzy_clause | _] = result[:query][:bool][:must]
      assert Map.has_key?(fuzzy_clause, :fuzzy)
    end

    test "_prefix creates prefix query", %{query: query} do
      result = Elasticsearch.apply_operator(query, :name, :_prefix, "jo", [field_type: :string])

      [prefix_clause | _] = result[:query][:bool][:must]
      assert Map.has_key?(prefix_clause, :prefix)
    end

    test "_regexp creates regexp query", %{query: query} do
      result = Elasticsearch.apply_operator(query, :email, :_regexp, ".*@example\\.com", [field_type: :string])

      [regexp_clause | _] = result[:query][:bool][:must]
      assert Map.has_key?(regexp_clause, :regexp)
    end
  end

  describe "build_query/2" do
    test "builds complete query from filter map" do
      filters = %{
        name: %{_contains: "john"},
        age: %{_gte: 18},
        tags: %{_includes_any: ["premium", "verified"]}
      }

      field_types = %{name: :string, age: :integer, tags: {:array, :string}}
      result = Elasticsearch.build_query(filters, field_types)

      assert is_map(result)
      assert Map.has_key?(result, :query)

      # Should have 3 must clauses
      must_clauses = result[:query][:bool][:must]
      assert length(must_clauses) == 3
    end

    test "handles empty filters" do
      result = Elasticsearch.build_query(%{})

      assert is_map(result)
      # Should still have valid bool structure
      assert result[:query][:bool][:must] == []
    end

    test "handles multiple operators on same field" do
      filters = %{
        age: %{_gte: 18, _lte: 65}
      }

      field_types = %{age: :integer}
      result = Elasticsearch.build_query(filters, field_types)

      must_clauses = result[:query][:bool][:must]
      assert length(must_clauses) == 2

      # Both should be range queries
      assert Enum.all?(must_clauses, &Map.has_key?(&1, :range))
    end

    test "handles mix of must and must_not" do
      filters = %{
        name: %{_contains: "john"},
        status: %{_neq: "spam"}
      }

      field_types = %{name: :string, status: :string}
      result = Elasticsearch.build_query(filters, field_types)

      assert length(result[:query][:bool][:must]) == 1
      assert length(result[:query][:bool][:must_not]) == 1
    end
  end

  describe "with field bindings" do
    setup do
      query = Elasticsearch.init_query()
      {:ok, query: query}
    end

    test "applies binding to field path", %{query: query} do
      result = Elasticsearch.apply_operator(query, :name, :_eq, "John", [field_type: :string, binding: :user])

      # Field path should be "user.name"
      [term_clause | _] = result[:query][:bool][:must]
      assert Map.has_key?(term_clause[:term], "user.name")
    end
  end

  describe "error handling" do
    test "raises error when used with Ecto.Query" do
      ecto_query = %Ecto.Query{}

      assert_raise RuntimeError, ~r/Exlasticsearch adapter requires Query DSL implementation/, fn ->
        Elasticsearch.apply_operator(ecto_query, :name, :_eq, "test", [field_type: :string])
      end
    end
  end

  describe "Query DSL structure validation" do
    test "maintains valid bool query structure through multiple operations" do
      query =
        Elasticsearch.init_query()
        |> Elasticsearch.apply_operator(:name, :_eq, "John", [field_type: :string])
        |> Elasticsearch.apply_operator(:age, :_gte, 18, [field_type: :integer])
        |> Elasticsearch.apply_operator(:status, :_neq, "spam", [field_type: :string])

      # Verify structure integrity
      assert is_map(query)
      assert Map.has_key?(query, :query)
      assert Map.has_key?(query[:query], :bool)

      bool_query = query[:query][:bool]
      assert is_list(bool_query[:must])
      assert is_list(bool_query[:must_not])
      assert is_list(bool_query[:should])
      assert is_list(bool_query[:filter])

      # Verify clauses were added
      assert length(bool_query[:must]) == 2
      assert length(bool_query[:must_not]) == 1
    end

    test "converts SQL LIKE patterns to ES wildcard syntax" do
      query = Elasticsearch.init_query()
      result = Elasticsearch.apply_operator(query, :name, :_like, "%test%", [field_type: :string])

      [wildcard_clause | _] = result[:query][:bool][:must]
      # Should convert % to *
      assert wildcard_clause[:wildcard] |> Map.values() |> hd() == "*test*"
    end
  end

  describe "performance and scalability" do
    test "supports very large _in clauses" do
      capabilities = Elasticsearch.capabilities()
      assert capabilities.max_in_clause_items == 65536
    end

    test "native array support for better performance" do
      capabilities = Elasticsearch.capabilities()
      assert capabilities.native_arrays == true
    end
  end

  describe "advanced Elasticsearch features" do
    test "indicates fuzzy search support" do
      capabilities = Elasticsearch.capabilities()
      assert capabilities.supports_fuzzy_search == true
    end

    test "indicates geo query support" do
      capabilities = Elasticsearch.capabilities()
      assert capabilities.supports_geo_queries == true
    end

    test "indicates nested document support" do
      capabilities = Elasticsearch.capabilities()
      assert capabilities.supports_nested_documents == true
    end
  end
end
