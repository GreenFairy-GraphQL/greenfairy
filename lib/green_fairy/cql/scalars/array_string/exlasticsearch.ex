defmodule GreenFairy.CQL.Scalars.ArrayString.Exlasticsearch do
  @moduledoc "Exlasticsearch native multi-value field support"

  def operator_input do
    {[
       :_includes,
       :_excludes,
       :_includes_all,
       :_excludes_all,
       :_includes_any,
       :_excludes_any,
       :_is_empty,
       :_is_null
     ], :string, "Operators for string array fields (native multi-value support)"}
  end

  def apply_operator(query, field, operator, value, opts) do
    # Check if query is an Ecto.Query struct - if so, error
    if match?(%Ecto.Query{}, query) do
      raise "Exlasticsearch adapter requires Query DSL implementation, not Ecto queries"
    end

    binding = Keyword.get(opts, :binding)
    field_path = if binding, do: "#{binding}.#{field}", else: to_string(field)

    case operator do
      :_includes -> add_term(query, field_path, value)
      :_excludes -> add_must_not_term(query, field_path, value)
      :_includes_all -> add_all_terms(query, field_path, value)
      :_excludes_all -> add_must_not_any_terms(query, field_path, value)
      :_includes_any -> add_terms(query, field_path, value)
      :_excludes_any -> add_must_not_all_terms(query, field_path, value)
      :_is_empty -> add_is_empty_script(query, field_path, value)
      :_is_null ->
        if value do
          add_must_not_exists(query, field_path)
        else
          add_exists(query, field_path)
        end
      _ -> query
    end
  end

  # Single value in array - use term query
  defp add_term(query, field, value) do
    update_in(query, [:query, :bool, :must], fn must ->
      [%{term: %{field => value}} | must]
    end)
  end

  # Single value NOT in array - use must_not term query
  defp add_must_not_term(query, field, value) do
    update_in(query, [:query, :bool, :must_not], fn must_not ->
      [%{term: %{field => value}} | must_not]
    end)
  end

  # All values must be in array - add multiple term queries to must
  defp add_all_terms(query, field, values) when is_list(values) do
    update_in(query, [:query, :bool, :must], fn must ->
      term_queries = Enum.map(values, fn value ->
        %{term: %{field => value}}
      end)
      term_queries ++ must
    end)
  end

  # Any of the values in array - use terms query
  defp add_terms(query, field, values) when is_list(values) do
    update_in(query, [:query, :bool, :must], fn must ->
      [%{terms: %{field => values}} | must]
    end)
  end

  # None of the values should be in array - use must_not with terms
  defp add_must_not_any_terms(query, field, values) when is_list(values) do
    update_in(query, [:query, :bool, :must_not], fn must_not ->
      term_queries = Enum.map(values, fn value ->
        %{term: %{field => value}}
      end)
      term_queries ++ must_not
    end)
  end

  # Array must not contain all values - use must_not with separate terms
  defp add_must_not_all_terms(query, field, values) when is_list(values) do
    update_in(query, [:query, :bool, :must_not], fn must_not ->
      # For excludes_any, we want to exclude documents where ALL values are present
      # This is tricky - we use should with minimum_should_match
      [%{
        bool: %{
          must: Enum.map(values, fn value ->
            %{term: %{field => value}}
          end)
        }
      } | must_not]
    end)
  end

  # Check if array is empty using script query
  defp add_is_empty_script(query, field, true) do
    update_in(query, [:query, :bool, :must], fn must ->
      [%{
        script: %{
          script: %{
            source: "doc['#{field}'].size() == 0",
            lang: "painless"
          }
        }
      } | must]
    end)
  end

  defp add_is_empty_script(query, field, false) do
    update_in(query, [:query, :bool, :must], fn must ->
      [%{
        script: %{
          script: %{
            source: "doc['#{field}'].size() > 0",
            lang: "painless"
          }
        }
      } | must]
    end)
  end

  # Field exists
  defp add_exists(query, field) do
    update_in(query, [:query, :bool, :must], fn must ->
      [%{exists: %{field: field}} | must]
    end)
  end

  # Field does not exist
  defp add_must_not_exists(query, field) do
    update_in(query, [:query, :bool, :must_not], fn must_not ->
      [%{exists: %{field: field}} | must_not]
    end)
  end
end
