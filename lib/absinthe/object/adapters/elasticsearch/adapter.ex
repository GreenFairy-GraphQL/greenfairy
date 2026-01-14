defmodule Absinthe.Object.Adapters.Elasticsearch.Adapter do
  @moduledoc """
  Backing adapter for Elasticsearch data sources.

  This adapter provides CQL and custom operator support for Elasticsearch,
  including scoring, fuzzy matching, and other ES-specific features.

  ## Custom Operators

  Elasticsearch supports several operators that are not available
  in traditional SQL databases:

  - `:fuzzy` - Fuzzy text matching with edit distance tolerance
  - `:score_boost` - Apply boost factor to matches for relevance
  - `:decay` - Distance-based decay scoring (for dates, geo)
  - `:more_like_this` - Find similar documents
  - `:script_score` - Custom scoring with Painless scripts

  ## Usage

  Configure your type to use this adapter:

      type "Product", struct: MyApp.Product do
        use Absinthe.Object.Extensions.CQL,
          adapter: Absinthe.Object.Adapters.Elasticsearch.Adapter

        field :id, non_null(:id)
        field :name, :string
        field :description, :string
      end

  Or configure globally:

      config :absinthe_object, :adapters, [
        Absinthe.Object.Adapters.Elasticsearch.Adapter
      ]

  """

  use Absinthe.Object.Adapter

  # ===========================================================================
  # Type to Operator Mapping
  # ===========================================================================

  @type_operators %{
    string: [:eq, :neq, :contains, :starts_with, :ends_with, :in, :is_nil, :match, :phrase, :prefix],
    text: [:eq, :neq, :contains, :in, :is_nil, :match, :phrase, :fulltext],
    keyword: [:eq, :neq, :in, :is_nil],
    integer: [:eq, :neq, :gt, :lt, :gte, :lte, :in, :is_nil],
    long: [:eq, :neq, :gt, :lt, :gte, :lte, :in, :is_nil],
    float: [:eq, :neq, :gt, :lt, :gte, :lte, :in, :is_nil],
    double: [:eq, :neq, :gt, :lt, :gte, :lte, :in, :is_nil],
    boolean: [:eq, :is_nil],
    date: [:eq, :neq, :gt, :lt, :gte, :lte, :is_nil],
    geo_point: [:near, :within_distance, :within_bounds, :is_nil],
    geo_shape: [:intersects, :within_bounds, :is_nil],
    nested: [:eq, :is_nil]
  }

  # ===========================================================================
  # Custom Elasticsearch Operators
  # ===========================================================================

  @custom_operators [
    fuzzy: %{
      types: [:string, :text, :keyword],
      description: "Fuzzy text matching with configurable edit distance",
      input_type: :fuzzy_input
    },
    score_boost: %{
      types: :all,
      description: "Apply boost factor to matches for relevance scoring",
      input_type: :score_boost_input
    },
    decay: %{
      types: [:date, :geo_point, :integer, :long, :float, :double],
      description: "Distance-based decay scoring",
      input_type: :decay_input
    },
    more_like_this: %{
      types: [:string, :text],
      description: "Find documents similar to provided text or documents",
      input_type: :more_like_this_input
    },
    script_score: %{
      types: :all,
      description: "Custom scoring using Painless scripts",
      input_type: :script_score_input
    },
    function_score: %{
      types: :all,
      description: "Complex relevance scoring with multiple functions",
      input_type: :function_score_input
    }
  ]

  # ===========================================================================
  # Core Callbacks
  # ===========================================================================

  @impl true
  def handles?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and
      (function_exported?(module, :__elasticsearch_index__, 0) or
         function_exported?(module, :__es_index__, 0) or
         function_exported?(module, :__elastic_model__, 0))
  end

  def handles?(_), do: false

  @impl true
  def capabilities, do: [:cql, :dataloader, :full_text_search, :aggregations, :scoring]

  # ===========================================================================
  # CQL Callbacks
  # ===========================================================================

  @impl true
  def queryable_fields(module) do
    cond do
      function_exported?(module, :__elasticsearch_mappings__, 0) ->
        module.__elasticsearch_mappings__() |> Map.keys()

      function_exported?(module, :__es_mappings__, 0) ->
        module.__es_mappings__() |> Map.keys()

      true ->
        []
    end
  end

  @impl true
  def field_type(module, field) do
    mappings =
      cond do
        function_exported?(module, :__elasticsearch_mappings__, 0) ->
          module.__elasticsearch_mappings__()

        function_exported?(module, :__es_mappings__, 0) ->
          module.__es_mappings__()

        true ->
          %{}
      end

    case Map.get(mappings, field) do
      %{type: type} -> type
      type when is_atom(type) -> type
      _ -> nil
    end
  end

  @impl true
  def operators_for_type(type) do
    Map.get(@type_operators, type, [:eq, :in])
  end

  @doc """
  Returns the custom operators supported by Elasticsearch.
  """
  def custom_operators, do: @custom_operators

  # ===========================================================================
  # DataLoader Callbacks
  # ===========================================================================

  @impl true
  def dataloader_source(_module), do: :elasticsearch

  @impl true
  def dataloader_batch_key(module, field, args) do
    {module, field, args}
  end

  # ===========================================================================
  # Helpers
  # ===========================================================================

  @doc """
  Returns the complete type-to-operators mapping.
  """
  def type_operators, do: @type_operators

  @doc """
  Returns information about a custom operator.
  """
  def custom_operator_info(operator) do
    Keyword.get(@custom_operators, operator)
  end

  @doc """
  Checks if a type supports a custom operator.
  """
  def supports_custom_operator?(type, operator) do
    case Keyword.get(@custom_operators, operator) do
      nil -> false
      %{types: :all} -> true
      %{types: types} -> type in List.wrap(types)
    end
  end
end
