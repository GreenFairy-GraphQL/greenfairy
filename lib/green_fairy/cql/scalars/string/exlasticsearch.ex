defmodule GreenFairy.CQL.Scalars.String.Exlasticsearch do
  @moduledoc "Exlasticsearch string operators with full-text search"

  def operator_input do
    {[
       :_eq,
       :_neq,
       :_in,
       :_nin,
       :_is_null,
       :_like,
       :_nlike,
       :_ilike,
       :_nilike,
       :_starts_with,
       :_istarts_with,
       :_ends_with,
       :_iends_with,
       :_contains,
       :_icontains,
       # Elasticsearch-specific full-text operators
       :_match,
       :_match_phrase,
       :_match_phrase_prefix,
       :_fuzzy,
       :_prefix,
       :_regexp,
       :_wildcard
     ], :string, "Operators for string fields with full-text search"}
  end

  def apply_operator(query, field, operator, value, opts) do
    # Exlasticsearch uses Query DSL (map-based), not Ecto queries
    # Check if query is an Ecto.Query struct - if so, error
    if match?(%Ecto.Query{}, query) do
      raise "Exlasticsearch adapter requires Query DSL implementation, not Ecto queries"
    end

    binding = Keyword.get(opts, :binding)
    field_path = if binding, do: "#{binding}.#{field}", else: to_string(field)

    case operator do
      :_eq -> add_term_query(query, field_path, value)
      :_neq -> add_must_not_term_query(query, field_path, value)
      :_in -> add_terms_query(query, field_path, value)
      :_nin -> add_must_not_terms_query(query, field_path, value)
      :_like -> add_wildcard_query(query, field_path, convert_sql_like_to_wildcard(value))
      :_ilike -> add_wildcard_query(query, String.downcase(field_path), convert_sql_like_to_wildcard(String.downcase(value)))
      :_contains -> add_match_phrase_query(query, field_path, value)
      :_icontains -> add_match_query(query, field_path, value)
      :_starts_with -> add_prefix_query(query, field_path, value)
      :_is_null ->
        if value do
          add_must_not_exists_query(query, field_path)
        else
          add_exists_query(query, field_path)
        end
      # ES-specific operators
      :_fuzzy -> add_fuzzy_query(query, field_path, value)
      :_prefix -> add_prefix_query(query, field_path, value)
      :_regexp -> add_regexp_query(query, field_path, value)
      _ -> query
    end
  end

  # Helper functions for building ES Query DSL
  defp add_term_query(query, field, value) do
    update_in(query, [:query, :bool, :must], fn must ->
      [%{term: %{field => value}} | must]
    end)
  end

  defp add_must_not_term_query(query, field, value) do
    update_in(query, [:query, :bool, :must_not], fn must_not ->
      [%{term: %{field => value}} | must_not]
    end)
  end

  defp add_terms_query(query, field, values) when is_list(values) do
    update_in(query, [:query, :bool, :must], fn must ->
      [%{terms: %{field => values}} | must]
    end)
  end

  defp add_must_not_terms_query(query, field, values) when is_list(values) do
    update_in(query, [:query, :bool, :must_not], fn must_not ->
      [%{terms: %{field => values}} | must_not]
    end)
  end

  defp add_wildcard_query(query, field, pattern) do
    update_in(query, [:query, :bool, :must], fn must ->
      [%{wildcard: %{field => pattern}} | must]
    end)
  end

  defp add_match_phrase_query(query, field, value) do
    update_in(query, [:query, :bool, :must], fn must ->
      [%{match_phrase: %{field => value}} | must]
    end)
  end

  defp add_match_query(query, field, value) do
    update_in(query, [:query, :bool, :must], fn must ->
      [%{match: %{field => value}} | must]
    end)
  end

  defp add_prefix_query(query, field, value) do
    update_in(query, [:query, :bool, :must], fn must ->
      [%{prefix: %{field => value}} | must]
    end)
  end

  defp add_exists_query(query, field) do
    update_in(query, [:query, :bool, :must], fn must ->
      [%{exists: %{field: field}} | must]
    end)
  end

  defp add_must_not_exists_query(query, field) do
    update_in(query, [:query, :bool, :must_not], fn must_not ->
      [%{exists: %{field: field}} | must_not]
    end)
  end

  defp add_fuzzy_query(query, field, value) do
    update_in(query, [:query, :bool, :must], fn must ->
      [%{fuzzy: %{field => %{value: value}}} | must]
    end)
  end

  defp add_regexp_query(query, field, pattern) do
    update_in(query, [:query, :bool, :must], fn must ->
      [%{regexp: %{field => pattern}} | must]
    end)
  end

  defp convert_sql_like_to_wildcard(pattern) when is_binary(pattern) do
    pattern
    |> String.replace("%", "*")
    |> String.replace("_", "?")
  end
  defp convert_sql_like_to_wildcard(pattern), do: pattern
end
