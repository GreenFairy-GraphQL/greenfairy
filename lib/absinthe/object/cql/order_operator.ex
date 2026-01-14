defmodule Absinthe.Object.CQL.OrderOperator do
  @moduledoc """
  Represents an order/sort operation in a CQL query.

  ## Fields

  - `:field` - The field to order by
  - `:direction` - Sort direction (:asc, :desc, etc.)
  - `:priority` - Priority list for enum ordering
  - `:geo_distance` - Coordinates for geo-distance ordering

  ## Examples

      # Simple ascending order
      %OrderOperator{field: :name, direction: :asc}

      # Descending with nulls last
      %OrderOperator{field: :created_at, direction: :desc_nulls_last}

      # Priority-based enum ordering
      %OrderOperator{field: :status, direction: :asc, priority: [:active, :pending, :closed]}

      # Geo-distance ordering
      %OrderOperator{field: :location, direction: :asc, geo_distance: {lat, lng}}
  """

  defstruct [
    :field,
    direction: :asc,
    priority: [],
    geo_distance: nil
  ]

  @type direction() ::
          :asc
          | :desc
          | :asc_nulls_first
          | :asc_nulls_last
          | :desc_nulls_first
          | :desc_nulls_last

  @type t :: %__MODULE__{
          field: atom(),
          direction: direction(),
          priority: [term()],
          geo_distance: {number(), number()} | nil
        }

  @doc """
  Creates a new OrderOperator from input map.

  ## Examples

      OrderOperator.from_input(:name, %{direction: :asc})
      #=> %OrderOperator{field: :name, direction: :asc}

      OrderOperator.from_input(:status, %{direction: :desc, priority: [:active, :pending]})
      #=> %OrderOperator{field: :status, direction: :desc, priority: [:active, :pending]}
  """
  def from_input(field, %{direction: direction} = args) do
    %__MODULE__{
      field: field,
      direction: direction,
      priority: Map.get(args, :priority, []),
      geo_distance: extract_geo_distance(args)
    }
  end

  def from_input(field, args) when is_map(args) do
    direction = Map.get(args, :direction, :asc)
    from_input(field, Map.put(args, :direction, direction))
  end

  defp extract_geo_distance(%{center: %{latitude: lat, longitude: lng}}), do: {lat, lng}
  defp extract_geo_distance(_), do: nil

  @doc """
  Returns the Ecto order direction atom.

  Converts CQL sort directions to Ecto's order_by format.
  """
  def to_ecto_direction(:asc), do: :asc
  def to_ecto_direction(:desc), do: :desc
  def to_ecto_direction(:asc_nulls_first), do: :asc_nulls_first
  def to_ecto_direction(:asc_nulls_last), do: :asc_nulls_last
  def to_ecto_direction(:desc_nulls_first), do: :desc_nulls_first
  def to_ecto_direction(:desc_nulls_last), do: :desc_nulls_last

  @doc """
  Checks if this is a geo-distance order.
  """
  def geo_order?(%__MODULE__{geo_distance: nil}), do: false
  def geo_order?(%__MODULE__{geo_distance: _}), do: true

  @doc """
  Checks if this is a priority-based order.
  """
  def priority_order?(%__MODULE__{priority: []}), do: false
  def priority_order?(%__MODULE__{priority: _}), do: true
end
