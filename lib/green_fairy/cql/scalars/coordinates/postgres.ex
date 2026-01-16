defmodule GreenFairy.CQL.Scalars.Coordinates.Postgres do
  @moduledoc "PostgreSQL with PostGIS spatial operators"

  import Ecto.Query, only: [where: 3]

  def operator_input do
    {[
       :_eq,
       :_ne,
       :_neq,
       :_is_null,
       :_st_dwithin,
       :_st_within_bounding_box
     ], :coordinates, "PostGIS spatial operators with distance and bounding box"}
  end

  def apply_operator(query, field, :_eq, value, opts) do
    binding = Keyword.get(opts, :binding)
    {lat, lng} = normalize_coordinates(value)

    if binding do
      where(query, [{^binding, q}],
        fragment("ST_Equals(?, ST_SetSRID(ST_MakePoint(?, ?), 4326))",
          field(q, ^field), ^lng, ^lat)
      )
    else
      where(query, [q],
        fragment("ST_Equals(?, ST_SetSRID(ST_MakePoint(?, ?), 4326))",
          field(q, ^field), ^lng, ^lat)
      )
    end
  end

  # Alias for _neq
  def apply_operator(query, field, :_ne, value, opts) do
    apply_operator(query, field, :_neq, value, opts)
  end

  def apply_operator(query, field, :_neq, value, opts) do
    binding = Keyword.get(opts, :binding)
    {lat, lng} = normalize_coordinates(value)

    if binding do
      where(query, [{^binding, q}],
        fragment("NOT ST_Equals(?, ST_SetSRID(ST_MakePoint(?, ?), 4326))",
          field(q, ^field), ^lng, ^lat)
      )
    else
      where(query, [q],
        fragment("NOT ST_Equals(?, ST_SetSRID(ST_MakePoint(?, ?), 4326))",
          field(q, ^field), ^lng, ^lat)
      )
    end
  end

  def apply_operator(query, field, :_is_null, true, opts) do
    binding = Keyword.get(opts, :binding)

    if binding do
      where(query, [{^binding, q}], is_nil(field(q, ^field)))
    else
      where(query, [q], is_nil(field(q, ^field)))
    end
  end

  def apply_operator(query, field, :_is_null, false, opts) do
    binding = Keyword.get(opts, :binding)

    if binding do
      where(query, [{^binding, q}], not is_nil(field(q, ^field)))
    else
      where(query, [q], not is_nil(field(q, ^field)))
    end
  end

  def apply_operator(query, field, :_st_dwithin, %{point: point, distance: distance}, opts) do
    binding = Keyword.get(opts, :binding)
    {lat, lng} = normalize_coordinates(point)

    # ST_DWithin uses meters for geography type, distance should be in meters
    if binding do
      where(query, [{^binding, q}],
        fragment("ST_DWithin(?, ST_SetSRID(ST_MakePoint(?, ?), 4326), ?)",
          field(q, ^field), ^lng, ^lat, ^distance)
      )
    else
      where(query, [q],
        fragment("ST_DWithin(?, ST_SetSRID(ST_MakePoint(?, ?), 4326), ?)",
          field(q, ^field), ^lng, ^lat, ^distance)
      )
    end
  end

  def apply_operator(query, field, :_st_within_bounding_box, %{sw: sw, ne: ne}, opts) do
    binding = Keyword.get(opts, :binding)
    {sw_lat, sw_lng} = normalize_coordinates(sw)
    {ne_lat, ne_lng} = normalize_coordinates(ne)

    # Check if point is within the bounding box using && operator (overlaps)
    if binding do
      where(query, [{^binding, q}],
        fragment("? && ST_MakeEnvelope(?, ?, ?, ?, 4326)",
          field(q, ^field), ^sw_lng, ^sw_lat, ^ne_lng, ^ne_lat)
      )
    else
      where(query, [q],
        fragment("? && ST_MakeEnvelope(?, ?, ?, ?, 4326)",
          field(q, ^field), ^sw_lng, ^sw_lat, ^ne_lng, ^ne_lat)
      )
    end
  end

  def apply_operator(query, _field, _operator, _value, _opts), do: query

  # Normalize coordinates from various formats
  defp normalize_coordinates({lat, lng}), do: {lat, lng}
  defp normalize_coordinates(%{lat: lat, lng: lng}), do: {lat, lng}
  defp normalize_coordinates(%{"lat" => lat, "lng" => lng}), do: {lat, lng}
  defp normalize_coordinates(%{latitude: lat, longitude: lng}), do: {lat, lng}
  defp normalize_coordinates(%{"latitude" => lat, "longitude" => lng}), do: {lat, lng}
end
