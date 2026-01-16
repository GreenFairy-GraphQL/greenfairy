defmodule GreenFairy.CQL.Scalars.Integer.Exlasticsearch do
  @moduledoc "Exlasticsearch Query DSL implementation for integer operators"

  def apply_operator(query, field, operator, value, opts) do
    binding = Keyword.get(opts, :binding)
    field_path = if binding, do: "#{binding}.#{field}", else: to_string(field)

    case operator do
      :_eq -> add_term(query, field_path, value)
      :_ne -> add_must_not_term(query, field_path, value)
      :_neq -> add_must_not_term(query, field_path, value)
      :_gt -> add_range(query, field_path, :gt, value)
      :_gte -> add_range(query, field_path, :gte, value)
      :_lt -> add_range(query, field_path, :lt, value)
      :_lte -> add_range(query, field_path, :lte, value)
      :_in -> add_terms(query, field_path, value)
      :_nin -> add_must_not_terms(query, field_path, value)
      :_is_null ->
        if value do
          add_must_not_exists(query, field_path)
        else
          add_exists(query, field_path)
        end
      _ -> query
    end
  end

  defp add_term(query, field, value) do
    update_in(query, [:query, :bool, :must], fn must ->
      [%{term: %{field => value}} | must]
    end)
  end

  defp add_must_not_term(query, field, value) do
    update_in(query, [:query, :bool, :must_not], fn must_not ->
      [%{term: %{field => value}} | must_not]
    end)
  end

  defp add_range(query, field, operator, value) do
    update_in(query, [:query, :bool, :must], fn must ->
      [%{range: %{field => %{operator => value}}} | must]
    end)
  end

  defp add_terms(query, field, values) when is_list(values) do
    update_in(query, [:query, :bool, :must], fn must ->
      [%{terms: %{field => values}} | must]
    end)
  end

  defp add_must_not_terms(query, field, values) when is_list(values) do
    update_in(query, [:query, :bool, :must_not], fn must_not ->
      [%{terms: %{field => values}} | must_not]
    end)
  end

  defp add_exists(query, field) do
    update_in(query, [:query, :bool, :must], fn must ->
      [%{exists: %{field: field}} | must]
    end)
  end

  defp add_must_not_exists(query, field) do
    update_in(query, [:query, :bool, :must_not], fn must_not ->
      [%{exists: %{field: field}} | must_not]
    end)
  end
end
