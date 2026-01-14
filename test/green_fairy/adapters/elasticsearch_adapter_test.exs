defmodule GreenFairy.Adapters.Elasticsearch.AdapterTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Adapters.Elasticsearch.Adapter

  describe "handles?/1" do
    defmodule ElasticsearchModel do
      def __elasticsearch_index__, do: "test_index"
      def __elasticsearch_mappings__, do: %{name: %{type: :text}, age: %{type: :integer}}
    end

    defmodule EsModel do
      def __es_index__, do: "test_index"
      def __es_mappings__, do: %{title: :text}
    end

    defmodule NotElasticsearch do
      def other_function, do: :ok
    end

    test "returns true for modules with __elasticsearch_index__" do
      assert Adapter.handles?(ElasticsearchModel)
    end

    test "returns true for modules with __es_index__" do
      assert Adapter.handles?(EsModel)
    end

    test "returns false for modules without ES functions" do
      refute Adapter.handles?(NotElasticsearch)
    end

    test "returns false for non-atoms" do
      refute Adapter.handles?("not_a_module")
    end
  end

  describe "capabilities/0" do
    test "returns Elasticsearch capabilities" do
      capabilities = Adapter.capabilities()

      assert :cql in capabilities
      assert :dataloader in capabilities
      assert :full_text_search in capabilities
      assert :aggregations in capabilities
      assert :scoring in capabilities
    end
  end

  describe "custom_operators/0" do
    test "returns Elasticsearch-specific operators" do
      operators = Adapter.custom_operators()

      assert Keyword.has_key?(operators, :fuzzy)
      assert Keyword.has_key?(operators, :score_boost)
      assert Keyword.has_key?(operators, :decay)
      assert Keyword.has_key?(operators, :more_like_this)
      assert Keyword.has_key?(operators, :script_score)
      assert Keyword.has_key?(operators, :function_score)
    end

    test "fuzzy operator supports text types" do
      operators = Adapter.custom_operators()
      fuzzy = Keyword.get(operators, :fuzzy)

      assert :string in fuzzy.types
      assert :text in fuzzy.types
    end

    test "score_boost operator supports all types" do
      operators = Adapter.custom_operators()
      score_boost = Keyword.get(operators, :score_boost)

      assert score_boost.types == :all
    end

    test "decay operator supports date and geo types" do
      operators = Adapter.custom_operators()
      decay = Keyword.get(operators, :decay)

      assert :date in decay.types
      assert :geo_point in decay.types
    end
  end

  describe "operators_for_type/1" do
    test "returns text operators" do
      ops = Adapter.operators_for_type(:text)

      assert :eq in ops
      assert :match in ops
      assert :phrase in ops
      assert :fulltext in ops
    end

    test "returns date operators" do
      ops = Adapter.operators_for_type(:date)

      assert :eq in ops
      assert :gt in ops
      assert :lt in ops
      assert :gte in ops
      assert :lte in ops
    end

    test "returns geo_point operators" do
      ops = Adapter.operators_for_type(:geo_point)

      assert :near in ops
      assert :within_distance in ops
      assert :within_bounds in ops
    end

    test "returns default operators for unknown type" do
      ops = Adapter.operators_for_type(:unknown_type)

      assert :eq in ops
      assert :in in ops
    end
  end

  describe "queryable_fields/1" do
    defmodule MappedModel do
      def __elasticsearch_mappings__ do
        %{
          title: %{type: :text},
          status: %{type: :keyword},
          count: %{type: :integer}
        }
      end
    end

    test "returns fields from mappings" do
      fields = Adapter.queryable_fields(MappedModel)

      assert :title in fields
      assert :status in fields
      assert :count in fields
    end

    test "returns empty list for modules without mappings" do
      defmodule NoMappings do
        def some_function, do: :ok
      end

      assert Adapter.queryable_fields(NoMappings) == []
    end
  end

  describe "field_type/2" do
    defmodule TypedModel do
      def __elasticsearch_mappings__ do
        %{
          name: %{type: :text},
          age: :integer,
          location: %{type: :geo_point}
        }
      end
    end

    test "returns type from mapping with type key" do
      assert Adapter.field_type(TypedModel, :name) == :text
    end

    test "returns type from simple mapping" do
      assert Adapter.field_type(TypedModel, :age) == :integer
    end

    test "returns nil for unknown field" do
      assert Adapter.field_type(TypedModel, :unknown) == nil
    end
  end

  describe "supports_custom_operator?/2" do
    test "returns true for supported type/operator combo" do
      assert Adapter.supports_custom_operator?(:string, :fuzzy)
      assert Adapter.supports_custom_operator?(:text, :fuzzy)
    end

    test "returns false for unsupported type/operator combo" do
      refute Adapter.supports_custom_operator?(:integer, :fuzzy)
    end

    test "returns true for :all types operators" do
      assert Adapter.supports_custom_operator?(:integer, :score_boost)
      assert Adapter.supports_custom_operator?(:string, :score_boost)
      assert Adapter.supports_custom_operator?(:geo_point, :score_boost)
    end

    test "returns false for unknown operator" do
      refute Adapter.supports_custom_operator?(:string, :unknown_op)
    end
  end
end
