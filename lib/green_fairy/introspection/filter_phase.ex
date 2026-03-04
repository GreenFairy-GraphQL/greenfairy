defmodule GreenFairy.Introspection.FilterPhase do
  @moduledoc false

  # Post-result Absinthe phase that filters introspection results based on
  # `visible` callbacks defined on GreenFairy types and fields.
  #
  # Inserted into the pipeline after Absinthe.Phase.Document.Result.

  use Absinthe.Phase

  @impl true
  def run(blueprint, _opts \\ []) do
    result = blueprint.result
    context = get_context(blueprint)
    schema = blueprint.schema

    if context != nil and schema != nil and is_map(result) do
      type_names = extract_type_names(blueprint)
      filtered = filter_result(result, context, schema, type_names)
      {:ok, %{blueprint | result: filtered}}
    else
      {:ok, blueprint}
    end
  end

  defp get_context(%{execution: %{context: context}}), do: context
  defp get_context(_), do: nil

  # Extract the type name argument from __type queries in the blueprint operations.
  # Returns a map of alias/field_name => type_name for each __type field.
  defp extract_type_names(%{operations: operations}) when is_list(operations) do
    operations
    |> Enum.flat_map(fn op -> extract_type_fields(op.selections) end)
    |> Map.new()
  end

  defp extract_type_names(_), do: %{}

  defp extract_type_fields(selections) when is_list(selections) do
    Enum.flat_map(selections, fn
      %{name: "__type", alias: alias_name} = field ->
        key = alias_name || "__type"
        name = get_type_name_arg(field)
        if name, do: [{key, name}], else: []

      _ ->
        []
    end)
  end

  defp extract_type_fields(_), do: []

  defp get_type_name_arg(%{arguments: args}) when is_list(args) do
    Enum.find_value(args, fn
      %{name: "name", input_value: %{normalized: %{value: name}}} when is_binary(name) -> name
      _ -> nil
    end)
  end

  defp get_type_name_arg(_), do: nil

  defp filter_result(%{data: data} = result, context, schema, type_names) when is_map(data) do
    %{result | data: filter_data(data, context, schema, type_names)}
  end

  defp filter_result(result, _context, _schema, _type_names), do: result

  defp filter_data(data, context, schema, type_names) do
    data
    |> filter_schema_types(context, schema)
    |> filter_type_queries(context, schema, type_names)
  end

  # Filter __schema { types { ... } }
  defp filter_schema_types(%{"__schema" => %{"types" => types} = schema_data} = data, context, schema)
       when is_list(types) do
    filtered = Enum.filter(types, &type_visible_by_data?(&1, context, schema))
    %{data | "__schema" => %{schema_data | "types" => filtered}}
  end

  defp filter_schema_types(data, _context, _schema), do: data

  # Filter all __type queries in the result data using extracted type names
  defp filter_type_queries(data, context, schema, type_names) do
    Enum.reduce(type_names, data, fn {key, type_name}, acc ->
      case Map.get(acc, key) do
        type_data when is_map(type_data) ->
          module = get_type_module_by_name(type_name, schema)

          if module && !module.__type_visible__(context) do
            # Type itself is hidden
            Map.put(acc, key, nil)
          else
            # Type is visible (or has no visibility control), filter internals
            filtered = filter_type_internals(type_data, type_name, context, schema)
            Map.put(acc, key, filtered)
          end

        _ ->
          acc
      end
    end)
  end

  # Filter fields/input_fields/possible_types within a __type result
  defp filter_type_internals(type_data, type_name, context, schema) do
    type_data
    |> filter_type_fields(type_name, context, schema)
    |> filter_type_input_fields(type_name, context, schema)
    |> filter_type_possible_types(context, schema)
  end

  # Filter fields within a type
  defp filter_type_fields(%{"fields" => fields} = type_data, type_name, context, schema)
       when is_list(fields) do
    case get_type_module_by_name(type_name, schema) do
      nil ->
        type_data

      type_module ->
        filtered = Enum.filter(fields, &field_visible?(&1, type_module, context))
        %{type_data | "fields" => filtered}
    end
  end

  defp filter_type_fields(type_data, _type_name, _context, _schema), do: type_data

  # Filter input_fields within a type
  defp filter_type_input_fields(%{"inputFields" => fields} = type_data, type_name, context, schema)
       when is_list(fields) do
    case get_type_module_by_name(type_name, schema) do
      nil ->
        type_data

      type_module ->
        filtered = Enum.filter(fields, &field_visible?(&1, type_module, context))
        %{type_data | "inputFields" => filtered}
    end
  end

  defp filter_type_input_fields(type_data, _type_name, _context, _schema), do: type_data

  # Filter possible_types within a type (for unions/interfaces)
  defp filter_type_possible_types(%{"possibleTypes" => types} = type_data, context, schema)
       when is_list(types) do
    filtered = Enum.filter(types, &type_visible_by_data?(&1, context, schema))
    %{type_data | "possibleTypes" => filtered}
  end

  defp filter_type_possible_types(type_data, _context, _schema), do: type_data

  # Check if a field is visible given its name and the type module
  defp field_visible?(%{"name" => field_name}, type_module, context) when is_binary(field_name) do
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    field_id = String.to_existing_atom(Macro.underscore(field_name))
    type_module.__field_visible__(field_id, context)
  rescue
    ArgumentError -> true
  end

  defp field_visible?(_, _type_module, _context), do: true

  # Check if a type is visible based on its name in the result data
  defp type_visible_by_data?(%{"name" => name}, context, schema) when is_binary(name) do
    case get_type_module_by_name(name, schema) do
      nil -> true
      type_module -> type_module.__type_visible__(context)
    end
  end

  defp type_visible_by_data?(_, _context, _schema), do: true

  # Look up the GreenFairy type module from a GraphQL type name
  defp get_type_module_by_name(name, schema) do
    case Absinthe.Schema.lookup_type(schema, name) do
      nil ->
        nil

      type ->
        module = get_meta_module(type)

        if module && function_exported?(module, :__type_visible__, 1) do
          module
        else
          nil
        end
    end
  end

  defp get_meta_module(%{__private__: private}) when is_list(private) do
    case Keyword.get(private, :meta) do
      meta when is_map(meta) -> Map.get(meta, :green_fairy_type_module)
      meta when is_list(meta) -> Keyword.get(meta, :green_fairy_type_module)
      _ -> nil
    end
  end

  defp get_meta_module(_), do: nil
end
