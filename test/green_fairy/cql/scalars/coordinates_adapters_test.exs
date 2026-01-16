defmodule GreenFairy.CQL.Scalars.CoordinatesAdaptersTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.Scalars.Coordinates.Postgres, as: CoordinatesPostgres
  alias GreenFairy.CQL.Scalars.Coordinates.MySQL, as: CoordinatesMySQL

  defmodule TestSchema do
    use Ecto.Schema

    schema "locations" do
      field :coordinates, :map
    end
  end

  describe "Coordinates.Postgres" do
    import Ecto.Query

    test "operator_input returns PostGIS operators" do
      {operators, type, desc} = CoordinatesPostgres.operator_input()

      assert :_eq in operators
      assert :_ne in operators
      assert :_neq in operators
      assert :_is_null in operators
      assert :_st_dwithin in operators
      assert :_st_within_bounding_box in operators
      assert type == :coordinates
      assert is_binary(desc)
    end

    test "_eq operator with map coordinates" do
      query = from(l in TestSchema)
      coords = %{lat: 37.7749, lng: -122.4194}

      result = CoordinatesPostgres.apply_operator(query, :coordinates, :_eq, coords, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_eq operator with tuple coordinates" do
      query = from(l in TestSchema)
      coords = {37.7749, -122.4194}

      result = CoordinatesPostgres.apply_operator(query, :coordinates, :_eq, coords, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_eq operator with binding" do
      query = from(l in TestSchema, as: :location)
      coords = %{lat: 37.7749, lng: -122.4194}

      result = CoordinatesPostgres.apply_operator(query, :coordinates, :_eq, coords, binding: :location)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_ne operator delegates to _neq" do
      query = from(l in TestSchema)
      coords = %{lat: 37.7749, lng: -122.4194}

      result = CoordinatesPostgres.apply_operator(query, :coordinates, :_ne, coords, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_neq operator" do
      query = from(l in TestSchema)
      coords = %{lat: 37.7749, lng: -122.4194}

      result = CoordinatesPostgres.apply_operator(query, :coordinates, :_neq, coords, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_neq operator with binding" do
      query = from(l in TestSchema, as: :location)
      coords = %{lat: 37.7749, lng: -122.4194}

      result = CoordinatesPostgres.apply_operator(query, :coordinates, :_neq, coords, binding: :location)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null true operator" do
      query = from(l in TestSchema)

      result = CoordinatesPostgres.apply_operator(query, :coordinates, :_is_null, true, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null true operator with binding" do
      query = from(l in TestSchema, as: :location)

      result = CoordinatesPostgres.apply_operator(query, :coordinates, :_is_null, true, binding: :location)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null false operator" do
      query = from(l in TestSchema)

      result = CoordinatesPostgres.apply_operator(query, :coordinates, :_is_null, false, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null false operator with binding" do
      query = from(l in TestSchema, as: :location)

      result = CoordinatesPostgres.apply_operator(query, :coordinates, :_is_null, false, binding: :location)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_st_dwithin operator" do
      query = from(l in TestSchema)
      value = %{point: %{lat: 37.7749, lng: -122.4194}, distance: 1000}

      result = CoordinatesPostgres.apply_operator(query, :coordinates, :_st_dwithin, value, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_st_dwithin operator with binding" do
      query = from(l in TestSchema, as: :location)
      value = %{point: %{lat: 37.7749, lng: -122.4194}, distance: 1000}

      result = CoordinatesPostgres.apply_operator(query, :coordinates, :_st_dwithin, value, binding: :location)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_st_within_bounding_box operator" do
      query = from(l in TestSchema)
      value = %{
        sw: %{lat: 37.0, lng: -123.0},
        ne: %{lat: 38.0, lng: -122.0}
      }

      result = CoordinatesPostgres.apply_operator(query, :coordinates, :_st_within_bounding_box, value, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_st_within_bounding_box operator with binding" do
      query = from(l in TestSchema, as: :location)
      value = %{
        sw: %{lat: 37.0, lng: -123.0},
        ne: %{lat: 38.0, lng: -122.0}
      }

      result = CoordinatesPostgres.apply_operator(query, :coordinates, :_st_within_bounding_box, value, binding: :location)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "unknown operator returns query unchanged" do
      query = from(l in TestSchema)

      result = CoordinatesPostgres.apply_operator(query, :coordinates, :_unknown, "value", [])

      assert result == query
    end

    test "supports string key coordinates" do
      query = from(l in TestSchema)
      coords = %{"lat" => 37.7749, "lng" => -122.4194}

      result = CoordinatesPostgres.apply_operator(query, :coordinates, :_eq, coords, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "supports latitude/longitude key format" do
      query = from(l in TestSchema)
      coords = %{latitude: 37.7749, longitude: -122.4194}

      result = CoordinatesPostgres.apply_operator(query, :coordinates, :_eq, coords, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "supports string latitude/longitude keys" do
      query = from(l in TestSchema)
      coords = %{"latitude" => 37.7749, "longitude" => -122.4194}

      result = CoordinatesPostgres.apply_operator(query, :coordinates, :_eq, coords, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end

  describe "Coordinates.MySQL" do
    import Ecto.Query

    test "operator_input returns MySQL operators" do
      {operators, type, desc} = CoordinatesMySQL.operator_input()

      assert :_eq in operators
      assert :_ne in operators
      assert :_neq in operators
      assert :_is_null in operators
      assert :_st_dwithin in operators
      refute :_st_within_bounding_box in operators
      assert type == :coordinates
      assert is_binary(desc)
    end

    test "_eq operator with map coordinates" do
      query = from(l in TestSchema)
      coords = %{lat: 37.7749, lng: -122.4194}

      result = CoordinatesMySQL.apply_operator(query, :coordinates, :_eq, coords, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_eq operator with binding" do
      query = from(l in TestSchema, as: :location)
      coords = %{lat: 37.7749, lng: -122.4194}

      result = CoordinatesMySQL.apply_operator(query, :coordinates, :_eq, coords, binding: :location)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_ne operator delegates to _neq" do
      query = from(l in TestSchema)
      coords = %{lat: 37.7749, lng: -122.4194}

      result = CoordinatesMySQL.apply_operator(query, :coordinates, :_ne, coords, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_neq operator" do
      query = from(l in TestSchema)
      coords = %{lat: 37.7749, lng: -122.4194}

      result = CoordinatesMySQL.apply_operator(query, :coordinates, :_neq, coords, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_neq operator with binding" do
      query = from(l in TestSchema, as: :location)
      coords = %{lat: 37.7749, lng: -122.4194}

      result = CoordinatesMySQL.apply_operator(query, :coordinates, :_neq, coords, binding: :location)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null true operator" do
      query = from(l in TestSchema)

      result = CoordinatesMySQL.apply_operator(query, :coordinates, :_is_null, true, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null true operator with binding" do
      query = from(l in TestSchema, as: :location)

      result = CoordinatesMySQL.apply_operator(query, :coordinates, :_is_null, true, binding: :location)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null false operator" do
      query = from(l in TestSchema)

      result = CoordinatesMySQL.apply_operator(query, :coordinates, :_is_null, false, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_is_null false operator with binding" do
      query = from(l in TestSchema, as: :location)

      result = CoordinatesMySQL.apply_operator(query, :coordinates, :_is_null, false, binding: :location)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_st_dwithin operator" do
      query = from(l in TestSchema)
      value = %{point: %{lat: 37.7749, lng: -122.4194}, distance: 1000}

      result = CoordinatesMySQL.apply_operator(query, :coordinates, :_st_dwithin, value, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "_st_dwithin operator with binding" do
      query = from(l in TestSchema, as: :location)
      value = %{point: %{lat: 37.7749, lng: -122.4194}, distance: 1000}

      result = CoordinatesMySQL.apply_operator(query, :coordinates, :_st_dwithin, value, binding: :location)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "unknown operator returns query unchanged" do
      query = from(l in TestSchema)

      result = CoordinatesMySQL.apply_operator(query, :coordinates, :_unknown, "value", [])

      assert result == query
    end

    test "supports string key coordinates" do
      query = from(l in TestSchema)
      coords = %{"lat" => 37.7749, "lng" => -122.4194}

      result = CoordinatesMySQL.apply_operator(query, :coordinates, :_eq, coords, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "supports tuple coordinates" do
      query = from(l in TestSchema)
      coords = {37.7749, -122.4194}

      result = CoordinatesMySQL.apply_operator(query, :coordinates, :_eq, coords, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "supports latitude/longitude key format" do
      query = from(l in TestSchema)
      coords = %{latitude: 37.7749, longitude: -122.4194}

      result = CoordinatesMySQL.apply_operator(query, :coordinates, :_eq, coords, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "supports string latitude/longitude keys" do
      query = from(l in TestSchema)
      coords = %{"latitude" => 37.7749, "longitude" => -122.4194}

      result = CoordinatesMySQL.apply_operator(query, :coordinates, :_eq, coords, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end
end
