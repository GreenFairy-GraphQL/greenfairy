defmodule GreenFairy.Filter.Elasticsearch.HelpersTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Filter.Elasticsearch.Helpers

  describe "append_filter/2" do
    test "appends filter to existing filters list" do
      query = %{
        "query" => %{
          "bool" => %{
            "filter" => [%{"term" => %{"status" => "active"}}]
          }
        }
      }

      result = Helpers.append_filter(query, %{"term" => %{"type" => "user"}})

      assert result["query"]["bool"]["filter"] == [
        %{"term" => %{"status" => "active"}},
        %{"term" => %{"type" => "user"}}
      ]
    end

    test "creates filter list when nil" do
      query = %{
        "query" => %{
          "bool" => %{}
        }
      }

      result = Helpers.append_filter(query, %{"term" => %{"status" => "active"}})

      assert result["query"]["bool"]["filter"] == [%{"term" => %{"status" => "active"}}]
    end

    test "creates full path when query is empty" do
      query = %{}

      result = Helpers.append_filter(query, %{"term" => %{"status" => "active"}})

      assert result["query"]["bool"]["filter"] == [%{"term" => %{"status" => "active"}}]
    end
  end

  describe "append_must/2" do
    test "appends clause to existing must list" do
      query = %{
        "query" => %{
          "bool" => %{
            "must" => [%{"match" => %{"title" => "test"}}]
          }
        }
      }

      result = Helpers.append_must(query, %{"match" => %{"body" => "content"}})

      assert result["query"]["bool"]["must"] == [
        %{"match" => %{"title" => "test"}},
        %{"match" => %{"body" => "content"}}
      ]
    end

    test "creates must list when nil" do
      query = %{
        "query" => %{
          "bool" => %{}
        }
      }

      result = Helpers.append_must(query, %{"match" => %{"title" => "test"}})

      assert result["query"]["bool"]["must"] == [%{"match" => %{"title" => "test"}}]
    end

    test "creates full path when query is empty" do
      query = %{}

      result = Helpers.append_must(query, %{"match" => %{"title" => "test"}})

      assert result["query"]["bool"]["must"] == [%{"match" => %{"title" => "test"}}]
    end
  end

  describe "append_must_not/2" do
    test "appends clause to existing must_not list" do
      query = %{
        "query" => %{
          "bool" => %{
            "must_not" => [%{"term" => %{"status" => "deleted"}}]
          }
        }
      }

      result = Helpers.append_must_not(query, %{"term" => %{"archived" => true}})

      assert result["query"]["bool"]["must_not"] == [
        %{"term" => %{"status" => "deleted"}},
        %{"term" => %{"archived" => true}}
      ]
    end

    test "creates must_not list when nil" do
      query = %{
        "query" => %{
          "bool" => %{}
        }
      }

      result = Helpers.append_must_not(query, %{"term" => %{"status" => "deleted"}})

      assert result["query"]["bool"]["must_not"] == [%{"term" => %{"status" => "deleted"}}]
    end

    test "creates full path when query is empty" do
      query = %{}

      result = Helpers.append_must_not(query, %{"term" => %{"status" => "deleted"}})

      assert result["query"]["bool"]["must_not"] == [%{"term" => %{"status" => "deleted"}}]
    end
  end
end
