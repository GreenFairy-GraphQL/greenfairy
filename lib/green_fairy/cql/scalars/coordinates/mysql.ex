defmodule GreenFairy.CQL.Scalars.Coordinates.MySQL do
  @moduledoc "MySQL spatial operators (limited support)"

  import Ecto.Query, only: [where: 3]

  def operator_input do
    {[
       :_eq,
       :_ne,
       :_neq,
       :_is_null,
       :_st_dwithin
     ], :coordinates, "MySQL spatial operators (distance only, no bounding box)"}
  end

  def apply_operator(query, field, :_eq, value, opts) do
    binding = Keyword.get(opts, :binding)
    {lat, lng} = normalize_coordinates(value)

    if binding do
      where(query, [{^binding, q}],
        fragment("ST_Equals(?, ST_GeomFromText(?, 4326))",
          field(q, ^field),
          ^"POINT(#{lng} #{lat})")
      )
    else
      where(query, [q],
        fragment("ST_Equals(?, ST_GeomFromText(?, 4326))",
          field(q, ^field),
          ^"POINT(#{lng} #{lat})")
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
        fragment("NOT ST_Equals(?, ST_GeomFromText(?, 4326))",
          field(q, ^field),
          ^"POINT(#{lng} #{lat})")
      )
    else
      where(query, [q],
        fragment("NOT ST_Equals(?, ST_GeomFromText(?, 4326))",
          field(q, ^field),
          ^"POINT(#{lng} #{lat})")
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

    # MySQL ST_Distance_Sphere returns distance in meters
    if binding do
      where(query, [{^binding, q}],
        fragment("ST_Distance_Sphere(?, ST_GeomFromText(?, 4326)) <= ?",
          field(q, ^field),
          ^"POINT(#{lng} #{lat})",
          ^distance)
      )
    else
      where(query, [q],
        fragment("ST_Distance_Sphere(?, ST_GeomFromText(?, 4326)) <= ?",
          field(q, ^field),
          ^"POINT(#{lng} #{lat})",
          ^distance)
      )
    end
  end

  def apply_operator(query, _field, _operator, _value, _opts), do: query

  defp normalize_coordinates({lat, lng}), do: {lat, lng}
  defp normalize_coordinates(%{lat: lat, lng: lng}), do: {lat, lng}
  defp normalize_coordinates(%{"lat" => lat, "lng" => lng}), do: {lat, lng}
  defp normalize_coordinates(%{latitude: lat, longitude: lng}), do: {lat, lng}
  defp normalize_coordinates(%{"latitude" => lat, "longitude" => lng}), do: {lat, lng}
end
