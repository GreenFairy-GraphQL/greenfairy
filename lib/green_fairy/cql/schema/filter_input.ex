defmodule GreenFairy.CQL.Schema.FilterInput do
  @moduledoc """
  Generates CQL filter input types for GraphQL types.

  Creates `CqlFilter{Type}Input` types with:
  - `_and: [CqlFilter{Type}Input]` - Logical AND combinator
  - `_or: [CqlFilter{Type}Input]` - Logical OR combinator
  - `_not: CqlFilter{Type}Input` - Logical NOT combinator
  - Field-specific operator inputs (e.g., `name: CqlOpStringInput`)

  ## Example

  For a User type with name (string) and age (integer) fields:

      input CqlFilterUserInput {
        _and: [CqlFilterUserInput]
        _or: [CqlFilterUserInput]
        _not: CqlFilterUserInput
        name: CqlOpStringInput
        age: CqlOpIntegerInput
      }

  ## Automatic Enum Support

  When a field uses a GreenFairy enum type, the filter automatically uses
  a type-specific enum operator input instead of the generic string input:

      # Given: field :status, :order_status (where :order_status is a GreenFairy enum)
      # Generates: status: CqlEnumOrderStatusInput

  This provides type safety - only valid enum values are accepted in filters.
  """

  alias GreenFairy.CQL.Schema.EnumOperatorInput
  alias GreenFairy.TypeRegistry

  @doc """
  Generates the filter input type identifier for a type name.
  """
  def filter_type_identifier(type_name) when is_binary(type_name) do
    String.to_atom("cql_filter_#{Macro.underscore(type_name)}_input")
  end

  def filter_type_identifier(type_name) when is_atom(type_name) do
    filter_type_identifier(Atom.to_string(type_name))
  end

  @doc """
  Generates AST for a CqlFilter{Type}Input type.

  ## Parameters

  - `type_name` - The GraphQL type name (e.g., "User")
  - `fields` - List of `{field_name, field_type}` tuples
  - `custom_filters` - Map of custom filter definitions

  ## Example

      fields = [
        {:id, :id},
        {:name, :string},
        {:age, :integer}
      ]

      FilterInput.generate("User", fields)
  """
  def generate(type_name, fields, custom_filters \\ %{}) do
    identifier = filter_type_identifier(type_name)
    description = "Filter input for #{type_name} type"

    # Build field definitions
    field_defs = build_field_definitions(fields, custom_filters)

    # Build combinator fields (_and, _or, _not)
    combinator_fields = build_combinator_fields(identifier)

    all_fields = combinator_fields ++ field_defs

    quote do
      @desc unquote(description)
      input_object unquote(identifier) do
        (unquote_splicing(all_fields))
      end
    end
  end

  defp build_combinator_fields(self_identifier) do
    and_field = quote do: field(:_and, list_of(unquote(self_identifier)))
    or_field = quote do: field(:_or, list_of(unquote(self_identifier)))
    not_field = quote do: field(:_not, unquote(self_identifier))

    [and_field, or_field, not_field]
  end

  defp build_field_definitions(fields, custom_filters) do
    fields
    |> Enum.map(fn {field_name, field_type} ->
      op_type = get_operator_type(field_name, field_type, custom_filters)

      if op_type do
        quote do
          field(unquote(field_name), unquote(op_type))
        end
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp get_operator_type(field_name, field_type, custom_filters) do
    cond do
      # Check for custom filter override
      Map.has_key?(custom_filters, field_name) ->
        custom = Map.get(custom_filters, field_name)
        # Custom filters use a generated type or inline operators
        custom_filter_type(field_name, custom)

      # Check if field type is a GreenFairy enum (automatic type-specific input)
      is_atom(field_type) and TypeRegistry.is_enum?(field_type) ->
        EnumOperatorInput.operator_type_identifier(field_type)

      # Check if it's an array of enums
      is_enum_array?(field_type) ->
        enum_id = get_enum_from_array(field_type)
        EnumOperatorInput.array_operator_type_identifier(enum_id)

      # Use standard operator type mapping
      true ->
        GreenFairy.CQL.ScalarMapper.operator_type_identifier(field_type)
    end
  end

  # Check if the type is an array of enums
  defp is_enum_array?({:array, inner_type}) when is_atom(inner_type) do
    TypeRegistry.is_enum?(inner_type)
  end
  defp is_enum_array?(_), do: false

  # Extract enum identifier from array type
  defp get_enum_from_array({:array, inner_type}), do: inner_type
  defp get_enum_from_array(_), do: nil

  defp custom_filter_type(_field_name, %{operators: operators}) do
    # For custom filters with specific operators, we map to the closest
    # standard type based on the operators defined
    cond do
      :contains in operators or :starts_with in operators ->
        :cql_op_string_input

      :gt in operators or :lt in operators ->
        :cql_op_integer_input

      true ->
        :cql_op_generic_input
    end
  end

  defp custom_filter_type(_field_name, _custom), do: :cql_op_generic_input

  @doc """
  Returns a list of all fields with their operator types for documentation.
  """
  def field_info(fields, custom_filters \\ %{}) do
    Enum.map(fields, fn {field_name, field_type} ->
      op_type = get_operator_type(field_name, field_type, custom_filters)
      {field_name, field_type, op_type}
    end)
  end

  @doc """
  Extracts all enum type identifiers used in filter fields.

  This is used by the schema to know which enum-specific operator inputs
  need to be generated.

  ## Example

      fields = [{:id, :id}, {:status, :order_status}, {:tags, {:array, :tag_type}}]
      extract_enum_types(fields)
      # => [:order_status, :tag_type]  (if both are GreenFairy enums)

  """
  def extract_enum_types(fields, custom_filters \\ %{}) do
    fields
    |> Enum.flat_map(fn {field_name, field_type} ->
      # Skip custom filters - they don't use enum operator inputs
      if Map.has_key?(custom_filters, field_name) do
        []
      else
        extract_enum_from_type(field_type)
      end
    end)
    |> Enum.uniq()
  end

  defp extract_enum_from_type(field_type) when is_atom(field_type) do
    if TypeRegistry.is_enum?(field_type), do: [field_type], else: []
  end

  defp extract_enum_from_type({:array, inner_type}) when is_atom(inner_type) do
    if TypeRegistry.is_enum?(inner_type), do: [inner_type], else: []
  end

  defp extract_enum_from_type(_), do: []

  # ============================================================================
  # Backwards Compatibility
  # ============================================================================

  @doc """
  Generates a simple filter input name (deprecated, use filter_type_identifier/1).

  This function is kept for backwards compatibility with the old API.
  """
  def input_name(type_name) when is_binary(type_name), do: :"#{type_name}Filter"

  def input_name(type_identifier) when is_atom(type_identifier) do
    name = type_identifier |> to_string() |> Macro.camelize()
    :"#{name}Filter"
  end
end
