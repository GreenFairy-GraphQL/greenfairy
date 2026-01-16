defmodule GreenFairy.CQL.Schema.OrderInput do
  @moduledoc """
  Generates CQL order input types for GraphQL types.

  Creates `CqlOrder{Type}Input` types with fields that map to sortable columns,
  each accepting an order direction.

  ## Order Types

  Three order input types are generated:

  - `cql_order_standard_input` - Basic direction-based sorting
  - `cql_order_geo_input` - Geo-distance based sorting with center point
  - `cql_order_priority_{enum}_input` - Priority-based enum sorting

  ## Sort Direction

  The `cql_sort_direction` enum supports:

  - `:asc` - Ascending order
  - `:desc` - Descending order
  - `:asc_nulls_first` - Ascending with nulls first
  - `:asc_nulls_last` - Ascending with nulls last
  - `:desc_nulls_first` - Descending with nulls first
  - `:desc_nulls_last` - Descending with nulls last

  ## Example

  For a User type with name (string) and created_at (datetime) fields:

      input CqlOrderUserInput {
        name: CqlOrderStandardInput
        createdAt: CqlOrderStandardInput
      }

  Which can be used in queries:

      query {
        users(orderBy: [{name: {direction: ASC}}]) {
          edges { node { name } }
        }
      }
  """

  @doc """
  Generates the order input type identifier for a type name.

  Note: This creates atoms at compile time during schema compilation,
  not at runtime, so the credo warning is a false positive.
  """
  def order_type_identifier(type_name) when is_binary(type_name) do
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    String.to_atom("cql_order_#{Macro.underscore(type_name)}_input")
  end

  def order_type_identifier(type_name) when is_atom(type_name) do
    order_type_identifier(Atom.to_string(type_name))
  end

  @doc """
  Returns the order input type for a field type.
  """
  def type_for(:geo_point), do: :cql_order_geo_input
  def type_for(:location), do: :cql_order_geo_input
  def type_for(_), do: :cql_order_standard_input

  @doc """
  Generates AST for a CqlOrder{Type}Input type.

  ## Parameters

  - `type_name` - The GraphQL type name (e.g., "User")
  - `fields` - List of `{field_name, field_type}` tuples for orderable fields

  ## Example

      fields = [
        {:id, :id},
        {:name, :string},
        {:created_at, :datetime}
      ]

      OrderInput.generate("User", fields)
  """
  def generate(type_name, fields) do
    identifier = order_type_identifier(type_name)
    description = "Order input for #{type_name} type"

    field_defs = build_field_definitions(fields)

    quote do
      @desc unquote(description)
      input_object unquote(identifier) do
        (unquote_splicing(field_defs))
      end
    end
  end

  defp build_field_definitions(fields) do
    fields
    |> Enum.map(fn {field_name, field_type} ->
      order_type = type_for(field_type)

      quote do
        field(unquote(field_name), unquote(order_type))
      end
    end)
  end

  @doc """
  Generates AST for the sort direction enum.
  """
  def generate_sort_direction_enum do
    quote do
      @desc "Sort direction for ordering results"
      enum :cql_sort_direction do
        @desc "Ascending order"
        value(:asc)
        @desc "Descending order"
        value(:desc)
        @desc "Ascending order with null values listed first"
        value(:asc_nulls_first)
        @desc "Ascending order with null values listed last"
        value(:asc_nulls_last)
        @desc "Descending order with null values listed first"
        value(:desc_nulls_first)
        @desc "Descending order with null values listed last"
        value(:desc_nulls_last)
      end
    end
  end

  @doc """
  Generates AST for the standard order input type.
  """
  def generate_standard_order_input do
    quote do
      @desc "Standard order input with direction"
      input_object :cql_order_standard_input do
        @desc "The direction of the sort"
        field(:direction, non_null(:cql_sort_direction))
      end
    end
  end

  @doc """
  Generates AST for the geo order input type.
  """
  def generate_geo_order_input do
    quote do
      @desc "Geo-distance based order input"
      input_object :cql_order_geo_input do
        @desc "The direction of the sort"
        field(:direction, non_null(:cql_sort_direction))
        @desc "The center coordinates to calculate distance from"
        field(:center, :coordinates)
      end
    end
  end

  @doc """
  Generates AST for a priority order input type for an enum.

  Priority ordering allows specifying the order of enum values
  for sorting purposes.

  ## Example

      generate_priority_order_input(:status, [:active, :pending, :closed])

  Generates:

      input CqlOrderPriorityStatusInput {
        direction: CqlSortDirection!
        priority: [Status]
      }
  """
  def generate_priority_order_input(enum_name, _values) do
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    identifier = String.to_atom("cql_order_priority_#{enum_name}_input")
    enum_type = enum_name

    quote do
      @desc "Priority-based order input for #{unquote(enum_name)} enum"
      input_object unquote(identifier) do
        @desc "The direction of the sort"
        field(:direction, non_null(:cql_sort_direction))
        @desc "The priority order of enum values"
        field(:priority, list_of(unquote(enum_type)))
      end
    end
  end

  @doc """
  Generates all base order input types (sort direction, standard, geo).

  This should be called once in the schema to define all CQL order types.
  """
  def generate_base_types do
    [
      generate_sort_direction_enum(),
      generate_standard_order_input(),
      generate_geo_order_input()
    ]
  end
end
