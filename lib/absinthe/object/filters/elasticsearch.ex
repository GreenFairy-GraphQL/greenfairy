defmodule Absinthe.Object.Filters.Elasticsearch do
  @moduledoc """
  Elasticsearch-specific semantic filter structs.

  These filters provide operations unique to Elasticsearch that don't
  have equivalents in traditional SQL databases:

  - `Fuzzy` - Fuzzy text matching with edit distance
  - `Boost` - Field boosting for relevance scoring
  - `FunctionScore` - Complex scoring with functions
  - `MoreLikeThis` - Find similar documents
  - `Nested` - Query nested objects
  - `Script` - Custom scoring with Painless scripts

  ## Example

      filter :search, fn query, opts ->
        %Absinthe.Object.Filters.Elasticsearch.Fuzzy{
          value: query,
          fuzziness: :auto,
          prefix_length: 2
        }
      end

  """

  defmodule Fuzzy do
    @moduledoc """
    Fuzzy text matching with configurable edit distance.

    Useful for handling typos and misspellings in search queries.

    ## Fields

    - `:value` - The text to search for
    - `:fuzziness` - Edit distance (`:auto`, 0, 1, or 2)
    - `:prefix_length` - Number of initial characters that must match exactly
    - `:max_expansions` - Maximum number of terms to expand to

    ## Example

        %Fuzzy{value: "elasticsearch", fuzziness: :auto, prefix_length: 2}

    """
    @enforce_keys [:value]
    defstruct [:value, fuzziness: :auto, prefix_length: 0, max_expansions: 50]

    @type t :: %__MODULE__{
            value: String.t(),
            fuzziness: :auto | 0..2,
            prefix_length: non_neg_integer(),
            max_expansions: pos_integer()
          }
  end

  defmodule Boost do
    @moduledoc """
    Boost a query clause for relevance scoring.

    Wraps an inner filter/query and applies a boost factor to increase
    or decrease its contribution to the relevance score.

    ## Fields

    - `:factor` - The boost factor (default: 1.0, higher = more important)

    ## Example

        # Double the importance of title matches
        %Boost{factor: 2.0}

    This is typically used in conjunction with other filters via the
    CQL extension, where boosting is applied per-field.
    """
    @enforce_keys [:factor]
    defstruct [:factor]

    @type t :: %__MODULE__{
            factor: float()
          }
  end

  defmodule ScoreBoost do
    @moduledoc """
    Apply a boost factor directly to a field match.

    This is the most common boosting pattern - boost matches on a
    specific field to increase their relevance.

    ## Fields

    - `:value` - The value to match
    - `:boost` - The boost factor to apply (default: 1.0)

    ## Example

        %ScoreBoost{value: "urgent", boost: 5.0}

    """
    @enforce_keys [:value]
    defstruct [:value, boost: 1.0]

    @type t :: %__MODULE__{
            value: term(),
            boost: float()
          }
  end

  defmodule FunctionScore do
    @moduledoc """
    Complex relevance scoring using Elasticsearch function_score.

    Allows sophisticated scoring functions like decay functions,
    field value factors, and random scoring.

    ## Fields

    - `:functions` - List of scoring functions to apply
    - `:score_mode` - How to combine function scores (`:multiply`, `:sum`, `:avg`, `:first`, `:max`, `:min`)
    - `:boost_mode` - How to combine with query score (`:multiply`, `:replace`, `:sum`, `:avg`, `:max`, `:min`)
    - `:max_boost` - Maximum boost value (caps the score)
    - `:min_score` - Minimum score threshold

    ## Function Types

    Each function in `:functions` can be:

    - `{:weight, weight}` - Simple constant weight
    - `{:field_value_factor, field, factor, modifier, missing}` - Score based on field value
    - `{:decay, type, field, origin, scale, offset, decay}` - Distance-based decay
    - `{:random_score, seed, field}` - Reproducible random scoring
    - `{:script_score, script}` - Custom Painless script

    ## Example

        %FunctionScore{
          functions: [
            {:field_value_factor, :popularity, 1.2, :log1p, 1},
            {:decay, :exp, :created_at, "now", "10d", "1d", 0.5}
          ],
          score_mode: :sum,
          boost_mode: :multiply
        }

    """
    defstruct [
      :functions,
      score_mode: :multiply,
      boost_mode: :multiply,
      max_boost: nil,
      min_score: nil
    ]

    @type score_function ::
            {:weight, number()}
            | {:field_value_factor, atom(), number(), atom(), number()}
            | {:decay, :exp | :linear | :gauss, atom(), String.t(), String.t(), String.t(), float()}
            | {:random_score, integer() | String.t(), atom()}
            | {:script_score, String.t()}

    @type score_mode :: :multiply | :sum | :avg | :first | :max | :min
    @type boost_mode :: :multiply | :replace | :sum | :avg | :max | :min

    @type t :: %__MODULE__{
            functions: [score_function()],
            score_mode: score_mode(),
            boost_mode: boost_mode(),
            max_boost: number() | nil,
            min_score: number() | nil
          }
  end

  defmodule MoreLikeThis do
    @moduledoc """
    Find documents similar to provided text or documents.

    Uses Elasticsearch's more_like_this query for content-based
    similarity matching.

    ## Fields

    - `:like` - Text or document IDs to find similar content to
    - `:fields` - Fields to analyze for similarity
    - `:min_term_freq` - Minimum term frequency in source doc
    - `:max_query_terms` - Maximum terms in generated query
    - `:min_doc_freq` - Minimum document frequency for terms
    - `:max_doc_freq` - Maximum document frequency for terms
    - `:min_word_length` - Minimum word length to consider
    - `:max_word_length` - Maximum word length to consider
    - `:boost_terms` - Boost factor for significant terms
    - `:include` - Include input document in results

    ## Example

        %MoreLikeThis{
          like: "Elasticsearch is a distributed search engine",
          fields: [:title, :content],
          min_term_freq: 1,
          max_query_terms: 25
        }

    """
    @enforce_keys [:like]
    defstruct [
      :like,
      :fields,
      min_term_freq: 2,
      max_query_terms: 25,
      min_doc_freq: 5,
      max_doc_freq: nil,
      min_word_length: 0,
      max_word_length: nil,
      boost_terms: 1,
      include: false
    ]

    @type like_doc :: %{_index: String.t(), _id: String.t()} | String.t()

    @type t :: %__MODULE__{
            like: like_doc() | [like_doc()],
            fields: [atom()] | nil,
            min_term_freq: pos_integer(),
            max_query_terms: pos_integer(),
            min_doc_freq: pos_integer(),
            max_doc_freq: pos_integer() | nil,
            min_word_length: non_neg_integer(),
            max_word_length: pos_integer() | nil,
            boost_terms: number(),
            include: boolean()
          }
  end

  defmodule Nested do
    @moduledoc """
    Query nested objects within a document.

    Elasticsearch nested objects require special query handling
    to maintain document relationships.

    ## Fields

    - `:path` - The nested field path
    - `:query` - The inner query/filter to apply
    - `:score_mode` - How to combine nested hit scores (`:avg`, `:sum`, `:min`, `:max`, `:none`)

    ## Example

        %Nested{
          path: :comments,
          query: %Basic.Equals{value: "user123"},
          score_mode: :avg
        }

    """
    @enforce_keys [:path, :query]
    defstruct [:path, :query, score_mode: :avg]

    @type t :: %__MODULE__{
            path: atom() | String.t(),
            query: struct(),
            score_mode: :avg | :sum | :min | :max | :none
          }
  end

  defmodule ScriptScore do
    @moduledoc """
    Custom scoring using Painless scripts.

    Allows arbitrary scoring logic using Elasticsearch's
    Painless scripting language.

    ## Fields

    - `:script` - The Painless script source
    - `:params` - Parameters to pass to the script

    ## Example

        %ScriptScore{
          script: "doc['popularity'].value * params.factor",
          params: %{factor: 1.5}
        }

    """
    @enforce_keys [:script]
    defstruct [:script, params: %{}]

    @type t :: %__MODULE__{
            script: String.t(),
            params: map()
          }
  end

  defmodule Decay do
    @moduledoc """
    Distance-based decay scoring.

    Scores documents based on how far a field value is from
    an origin point. Common for date-based relevance and
    geo-distance scoring.

    ## Fields

    - `:type` - Decay function (`:exp`, `:linear`, `:gauss`)
    - `:origin` - The optimal value (e.g., "now" for dates, coordinates for geo)
    - `:scale` - The distance at which score is halved
    - `:offset` - No decay within this distance from origin
    - `:decay` - Score at `scale` distance (default: 0.5)

    ## Example

        # Prefer recent documents, halving score for docs 30 days old
        %Decay{
          type: :exp,
          origin: "now",
          scale: "30d",
          offset: "1d",
          decay: 0.5
        }

    """
    @enforce_keys [:type, :origin, :scale]
    defstruct [:type, :origin, :scale, offset: "0", decay: 0.5]

    @type t :: %__MODULE__{
            type: :exp | :linear | :gauss,
            origin: String.t() | map(),
            scale: String.t(),
            offset: String.t(),
            decay: float()
          }
  end
end
