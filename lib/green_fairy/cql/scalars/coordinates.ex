defmodule GreenFairy.CQL.Scalars.Coordinates do
  @moduledoc """
  CQL scalar for geographic coordinates (latitude/longitude).

  Provides geo-spatial operators including distance and bounding box queries.

  ## Operators

  - `:_eq` / `:_neq` - Equality/inequality
  - `:_is_null` - Null check
  - `:_st_dwithin` - Distance within radius (PostGIS)
  - `:_st_within_bounding_box` - Within bounding box (PostGIS)

  ## Adapter Variations

  - **PostgreSQL with PostGIS**: Full spatial operator support
  - **MySQL**: Limited spatial support (distance calculations only)
  - **Other adapters**: Basic equality only

  ## Input Format

  Coordinates are represented as `{lat, lng}` tuples or `%{lat: lat, lng: lng}` maps.

  ## Examples

      # Distance within 5000 meters (5km)
      where: {
        location: {
          _st_dwithin: {
            point: {lat: 37.7749, lng: -122.4194},
            distance: 5000
          }
        }
      }

      # Within bounding box
      where: {
        location: {
          _st_within_bounding_box: {
            sw: {lat: 37.7, lng: -122.5},
            ne: {lat: 37.8, lng: -122.3}
          }
        }
      }
  """

  @behaviour GreenFairy.CQL.Scalar

  @impl true
  def operator_input(:postgres), do: __MODULE__.Postgres.operator_input()
  def operator_input(:mysql), do: __MODULE__.MySQL.operator_input()
  def operator_input(_adapter), do: __MODULE__.Generic.operator_input()

  @impl true
  def apply_operator(query, field, operator, value, :postgres, opts) do
    __MODULE__.Postgres.apply_operator(query, field, operator, value, opts)
  end

  def apply_operator(query, field, operator, value, :mysql, opts) do
    __MODULE__.MySQL.apply_operator(query, field, operator, value, opts)
  end

  def apply_operator(query, field, operator, value, _adapter, opts) do
    __MODULE__.Generic.apply_operator(query, field, operator, value, opts)
  end

  @impl true
  def operator_type_identifier(_adapter), do: :cql_op_coordinates_input
end
