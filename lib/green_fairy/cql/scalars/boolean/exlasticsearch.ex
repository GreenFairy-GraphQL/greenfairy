defmodule GreenFairy.CQL.Scalars.Boolean.Exlasticsearch do
  @moduledoc "Exlasticsearch Query DSL implementation for boolean operators"

  def apply_operator(query, field, operator, value, opts) do
    binding = Keyword.get(opts, :binding)
    field_path = if binding, do: "#{binding}.#{field}", else: to_string(field)

    case operator do
      :_eq -> add_term(query, field_path, value)
      :_ne -> add_must_not_term(query, field_path, value)
      :_neq -> add_must_not_term(query, field_path, value)
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
