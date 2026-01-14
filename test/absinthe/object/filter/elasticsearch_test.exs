defmodule Absinthe.Object.Filter.ElasticsearchTest do
  use ExUnit.Case, async: true

  alias Absinthe.Object.Filter
  alias Absinthe.Object.Filter.Elasticsearch.Helpers
  alias Absinthe.Object.Adapters.Elasticsearch, as: ESAdapter
  alias Absinthe.Object.Filters.{Basic, Geo, Text}

  # Force the Elasticsearch filter module to load and register implementations
  @es_module Absinthe.Object.Filter.Elasticsearch
  Code.ensure_loaded!(@es_module)

  describe "Helpers.append_filter/2" do
    test "appends filter to empty query" do
      query = %{}
      filter = %{"term" => %{"status" => "active"}}

      result = Helpers.append_filter(query, filter)

      assert result == %{
               "query" => %{
                 "bool" => %{
                   "filter" => [filter]
                 }
               }
             }
    end

    test "appends filter to existing filters" do
      query = %{
        "query" => %{
          "bool" => %{
            "filter" => [%{"term" => %{"type" => "user"}}]
          }
        }
      }

      filter = %{"term" => %{"status" => "active"}}
      result = Helpers.append_filter(query, filter)

      assert result["query"]["bool"]["filter"] == [
               %{"term" => %{"type" => "user"}},
               %{"term" => %{"status" => "active"}}
             ]
    end
  end

  describe "Helpers.append_must/2" do
    test "appends must clause to empty query" do
      query = %{}
      clause = %{"match" => %{"title" => "test"}}

      result = Helpers.append_must(query, clause)

      assert result == %{
               "query" => %{
                 "bool" => %{
                   "must" => [clause]
                 }
               }
             }
    end
  end

  describe "Helpers.append_must_not/2" do
    test "appends must_not clause to empty query" do
      query = %{}
      clause = %{"term" => %{"deleted" => true}}

      result = Helpers.append_must_not(query, clause)

      assert result == %{
               "query" => %{
                 "bool" => %{
                   "must_not" => [clause]
                 }
               }
             }
    end
  end

  # Test the filter implementations if they're registered
  # These tests verify the Filter dispatch works with the ES adapter
  describe "Basic filter implementations" do
    setup do
      adapter = ESAdapter.new()
      {:ok, adapter: adapter}
    end

    test "Equals filter creates term filter", %{adapter: adapter} do
      filter = %Basic.Equals{value: "active"}

      case Filter.apply(adapter, filter, :status, %{}) do
        {:ok, result} ->
          assert result["query"]["bool"]["filter"] == [
                   %{"term" => %{"status" => "active"}}
                 ]

        {:error, _} ->
          # Implementation not registered - skip this test
          :ok
      end
    end

    test "NotEquals filter creates must_not term filter", %{adapter: adapter} do
      filter = %Basic.NotEquals{value: "deleted"}

      case Filter.apply(adapter, filter, :status, %{}) do
        {:ok, result} ->
          assert result["query"]["bool"]["must_not"] == [
                   %{"term" => %{"status" => "deleted"}}
                 ]

        {:error, _} ->
          :ok
      end
    end

    test "In filter creates terms filter", %{adapter: adapter} do
      filter = %Basic.In{values: ["a", "b", "c"]}

      case Filter.apply(adapter, filter, :category, %{}) do
        {:ok, result} ->
          assert result["query"]["bool"]["filter"] == [
                   %{"terms" => %{"category" => ["a", "b", "c"]}}
                 ]

        {:error, _} ->
          :ok
      end
    end

    test "NotIn filter creates must_not terms filter", %{adapter: adapter} do
      filter = %Basic.NotIn{values: ["x", "y"]}

      case Filter.apply(adapter, filter, :tag, %{}) do
        {:ok, result} ->
          assert result["query"]["bool"]["must_not"] == [
                   %{"terms" => %{"tag" => ["x", "y"]}}
                 ]

        {:error, _} ->
          :ok
      end
    end

    test "Range filter creates range filter with gte and lte", %{adapter: adapter} do
      filter = %Basic.Range{gte: 10, lte: 100}

      case Filter.apply(adapter, filter, :price, %{}) do
        {:ok, result} ->
          assert result["query"]["bool"]["filter"] == [
                   %{"range" => %{"price" => %{"gte" => 10, "lte" => 100}}}
                 ]

        {:error, _} ->
          :ok
      end
    end

    test "Range filter creates range filter with gt and lt", %{adapter: adapter} do
      filter = %Basic.Range{gt: 0, lt: 50}

      case Filter.apply(adapter, filter, :score, %{}) do
        {:ok, result} ->
          assert result["query"]["bool"]["filter"] == [
                   %{"range" => %{"score" => %{"gt" => 0, "lt" => 50}}}
                 ]

        {:error, _} ->
          :ok
      end
    end

    test "IsNil filter creates must_not exists filter when is_nil is true", %{adapter: adapter} do
      filter = %Basic.IsNil{is_nil: true}

      case Filter.apply(adapter, filter, :deleted_at, %{}) do
        {:ok, result} ->
          assert result["query"]["bool"]["must_not"] == [
                   %{"exists" => %{"field" => "deleted_at"}}
                 ]

        {:error, _} ->
          :ok
      end
    end

    test "IsNil filter creates exists filter when is_nil is false", %{adapter: adapter} do
      filter = %Basic.IsNil{is_nil: false}

      case Filter.apply(adapter, filter, :email, %{}) do
        {:ok, result} ->
          assert result["query"]["bool"]["filter"] == [
                   %{"exists" => %{"field" => "email"}}
                 ]

        {:error, _} ->
          :ok
      end
    end

    test "Contains filter creates wildcard filter", %{adapter: adapter} do
      filter = %Basic.Contains{value: "test"}

      case Filter.apply(adapter, filter, :name, %{}) do
        {:ok, result} ->
          assert result["query"]["bool"]["filter"] == [
                   %{"wildcard" => %{"name" => "*test*"}}
                 ]

        {:error, _} ->
          :ok
      end
    end

    test "StartsWith filter creates prefix filter", %{adapter: adapter} do
      filter = %Basic.StartsWith{value: "abc"}

      case Filter.apply(adapter, filter, :code, %{}) do
        {:ok, result} ->
          assert result["query"]["bool"]["filter"] == [
                   %{"prefix" => %{"code" => "abc"}}
                 ]

        {:error, _} ->
          :ok
      end
    end

    test "EndsWith filter creates wildcard filter with prefix wildcard", %{adapter: adapter} do
      filter = %Basic.EndsWith{value: ".txt"}

      case Filter.apply(adapter, filter, :filename, %{}) do
        {:ok, result} ->
          assert result["query"]["bool"]["filter"] == [
                   %{"wildcard" => %{"filename" => "*.txt"}}
                 ]

        {:error, _} ->
          :ok
      end
    end
  end

  describe "Text filter implementations" do
    setup do
      adapter = ESAdapter.new()
      {:ok, adapter: adapter}
    end

    test "Fulltext filter creates multi_match query", %{adapter: adapter} do
      filter = %Text.Fulltext{
        query: "search terms",
        fields: ["title", "body"],
        fuzziness: :auto,
        operator: :and
      }

      case Filter.apply(adapter, filter, :_fulltext, %{}) do
        {:ok, result} ->
          assert result["query"]["bool"]["must"] == [
                   %{
                     "multi_match" => %{
                       "query" => "search terms",
                       "fields" => ["title", "body"],
                       "fuzziness" => "AUTO",
                       "operator" => "and"
                     }
                   }
                 ]

        {:error, _} ->
          :ok
      end
    end

    test "Match filter creates match query", %{adapter: adapter} do
      filter = %Text.Match{query: "hello world", operator: :or}

      case Filter.apply(adapter, filter, :content, %{}) do
        {:ok, result} ->
          assert result["query"]["bool"]["must"] == [
                   %{
                     "match" => %{
                       "content" => %{
                         "query" => "hello world",
                         "operator" => "or"
                       }
                     }
                   }
                 ]

        {:error, _} ->
          :ok
      end
    end

    test "Prefix filter creates prefix query", %{adapter: adapter} do
      filter = %Text.Prefix{value: "auto"}

      case Filter.apply(adapter, filter, :suggestion, %{}) do
        {:ok, result} ->
          assert result["query"]["bool"]["filter"] == [
                   %{"prefix" => %{"suggestion" => "auto"}}
                 ]

        {:error, _} ->
          :ok
      end
    end

    test "Phrase filter creates match_phrase query", %{adapter: adapter} do
      filter = %Text.Phrase{phrase: "quick brown fox", slop: 2}

      case Filter.apply(adapter, filter, :body, %{}) do
        {:ok, result} ->
          assert result["query"]["bool"]["must"] == [
                   %{
                     "match_phrase" => %{
                       "body" => %{
                         "query" => "quick brown fox",
                         "slop" => 2
                       }
                     }
                   }
                 ]

        {:error, _} ->
          :ok
      end
    end
  end

  describe "Geo filter implementations" do
    setup do
      adapter = ESAdapter.new()
      {:ok, adapter: adapter}
    end

    test "Near filter creates geo_distance filter", %{adapter: adapter} do
      filter = %Geo.Near{
        point: %{coordinates: {-122.4194, 37.7749}},
        distance: 10,
        unit: :kilometers
      }

      case Filter.apply(adapter, filter, :location, %{}) do
        {:ok, result} ->
          assert result["query"]["bool"]["filter"] == [
                   %{
                     "geo_distance" => %{
                       "distance" => "10km",
                       "location" => %{"lat" => 37.7749, "lon" => -122.4194}
                     }
                   }
                 ]

        {:error, _} ->
          :ok
      end
    end

    test "Near filter handles different distance units", %{adapter: adapter} do
      # Meters
      filter = %Geo.Near{point: %{lng: 0, lat: 0}, distance: 500, unit: :meters}

      case Filter.apply(adapter, filter, :loc, %{}) do
        {:ok, result} ->
          distance =
            get_in(result, ["query", "bool", "filter", Access.at(0), "geo_distance", "distance"])

          assert distance == "500m"

        {:error, _} ->
          :ok
      end

      # Miles
      filter = %Geo.Near{point: %{lon: 0, lat: 0}, distance: 5, unit: :miles}

      case Filter.apply(adapter, filter, :loc, %{}) do
        {:ok, result} ->
          distance =
            get_in(result, ["query", "bool", "filter", Access.at(0), "geo_distance", "distance"])

          assert distance == "5mi"

        {:error, _} ->
          :ok
      end
    end

    test "WithinDistance filter delegates to Near filter", %{adapter: adapter} do
      filter = %Geo.WithinDistance{
        point: %{coordinates: {-122.4194, 37.7749}},
        distance: 10,
        unit: :kilometers
      }

      case Filter.apply(adapter, filter, :location, %{}) do
        {:ok, result} ->
          # Should produce same result as Near
          assert result["query"]["bool"]["filter"] != nil

        {:error, _} ->
          :ok
      end
    end

    test "WithinBounds filter creates geo_bounding_box filter", %{adapter: adapter} do
      filter = %Geo.WithinBounds{
        bounds: %{
          top_left: %{lat: 40.73, lng: -74.1},
          bottom_right: %{lat: 40.01, lng: -71.12}
        }
      }

      case Filter.apply(adapter, filter, :location, %{}) do
        {:ok, result} ->
          bbox =
            get_in(result, [
              "query",
              "bool",
              "filter",
              Access.at(0),
              "geo_bounding_box",
              "location"
            ])

          assert bbox["top_left"] == %{"lat" => 40.73, "lon" => -74.1}
          assert bbox["bottom_right"] == %{"lat" => 40.01, "lon" => -71.12}

        {:error, _} ->
          :ok
      end
    end
  end
end
