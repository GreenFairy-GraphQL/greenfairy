defmodule Absinthe.Object.Filter.Elasticsearch.Helpers do
  @moduledoc """
  Helper functions for building Elasticsearch query DSL.
  """

  @doc """
  Appends a filter clause to the bool query's filter section.
  """
  def append_filter(query, filter) do
    update_in(query, [Access.key("query", %{}), Access.key("bool", %{}), Access.key("filter", [])], fn
      filters when is_list(filters) -> filters ++ [filter]
      nil -> [filter]
    end)
  end

  @doc """
  Appends a clause to the bool query's must section.
  """
  def append_must(query, clause) do
    update_in(query, [Access.key("query", %{}), Access.key("bool", %{}), Access.key("must", [])], fn
      clauses when is_list(clauses) -> clauses ++ [clause]
      nil -> [clause]
    end)
  end

  @doc """
  Appends a clause to the bool query's must_not section.
  """
  def append_must_not(query, clause) do
    update_in(query, [Access.key("query", %{}), Access.key("bool", %{}), Access.key("must_not", [])], fn
      clauses when is_list(clauses) -> clauses ++ [clause]
      nil -> [clause]
    end)
  end
end
