defmodule GreenFairy.ScalarTest do
  use ExUnit.Case, async: true

  defmodule DateTimeScalar do
    use GreenFairy.Scalar

    scalar "DateTime" do
      parse fn
        %Absinthe.Blueprint.Input.String{value: value} ->
          case DateTime.from_iso8601(value) do
            {:ok, datetime, _} -> {:ok, datetime}
            _ -> :error
          end

        %Absinthe.Blueprint.Input.Null{} ->
          {:ok, nil}

        _ ->
          :error
      end

      serialize fn datetime ->
        DateTime.to_iso8601(datetime)
      end
    end
  end

  defmodule PointScalar do
    use GreenFairy.Scalar

    scalar "Point" do
      description "A geographic point"

      operators([:eq, :near, :within_distance])

      filter(:near, fn field, value ->
        {:geo_near, field, value}
      end)

      filter(:within_distance, fn field, value, opts ->
        distance = opts[:distance] || 1000
        {:geo_within, field, value, distance}
      end)

      parse fn
        %Absinthe.Blueprint.Input.Object{fields: fields} ->
          lng = Enum.find_value(fields, fn %{name: n, input_value: %{value: v}} -> if n == "lng", do: v end)
          lat = Enum.find_value(fields, fn %{name: n, input_value: %{value: v}} -> if n == "lat", do: v end)
          {:ok, %{lng: lng, lat: lat}}

        _ ->
          :error
      end

      serialize fn point ->
        %{lng: point.lng, lat: point.lat}
      end
    end
  end

  # Scalar with operators via filter with 3-arity opts
  defmodule RangeScalar do
    use GreenFairy.Scalar

    scalar "Range" do
      operators([:eq, :gt, :lt])

      filter(:gt, [strict: true], fn field, value, opts ->
        {:gt, field, value, opts}
      end)

      parse fn
        %Absinthe.Blueprint.Input.Integer{value: value} -> {:ok, value}
        _ -> :error
      end

      serialize fn value -> value end
    end
  end

  # Scalar without operators (for testing default behavior)
  defmodule NoOpScalar do
    use GreenFairy.Scalar

    scalar "NoOp" do
      parse fn _ -> :error end
      serialize fn v -> v end
    end
  end

  defmodule MoneyScalar do
    use GreenFairy.Scalar

    scalar "Money", description: "A monetary value in cents" do
      parse fn
        %Absinthe.Blueprint.Input.Integer{value: value} ->
          {:ok, value}

        %Absinthe.Blueprint.Input.String{value: value} ->
          case Integer.parse(value) do
            {int, ""} -> {:ok, int}
            _ -> :error
          end

        %Absinthe.Blueprint.Input.Null{} ->
          {:ok, nil}

        _ ->
          :error
      end

      serialize fn cents ->
        cents
      end
    end
  end

  defmodule TestSchema do
    use Absinthe.Schema

    import_types DateTimeScalar
    import_types MoneyScalar

    query do
      field :current_time, :date_time do
        resolve fn _, _, _ ->
          {:ok, DateTime.utc_now()}
        end
      end

      field :parse_time, :date_time do
        arg :time, non_null(:date_time)

        resolve fn _, %{time: time}, _ ->
          {:ok, time}
        end
      end

      field :price, :money do
        resolve fn _, _, _ ->
          {:ok, 1999}
        end
      end

      field :parse_price, :money do
        arg :amount, non_null(:money)

        resolve fn _, %{amount: amount}, _ ->
          {:ok, amount}
        end
      end
    end
  end

  describe "scalar/2 macro" do
    test "defines __green_fairy_definition__/0" do
      definition = DateTimeScalar.__green_fairy_definition__()

      assert definition.kind == :scalar
      assert definition.name == "DateTime"
      assert definition.identifier == :date_time
    end

    test "defines __green_fairy_identifier__/0" do
      assert DateTimeScalar.__green_fairy_identifier__() == :date_time
    end

    test "defines __green_fairy_kind__/0" do
      assert DateTimeScalar.__green_fairy_kind__() == :scalar
    end
  end

  describe "Absinthe integration" do
    test "generates valid Absinthe scalar type" do
      type = Absinthe.Schema.lookup_type(TestSchema, :date_time)

      assert type != nil
      assert type.name == "DateTime"
      assert type.identifier == :date_time
    end

    test "serializes output correctly" do
      query = """
      {
        currentTime
      }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, TestSchema)
      # Should be an ISO8601 string
      assert is_binary(data["currentTime"])
      assert String.contains?(data["currentTime"], "T")
    end

    test "parses input correctly" do
      query = """
      {
        parseTime(time: "2024-01-15T12:00:00Z")
      }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, TestSchema)
      assert data["parseTime"] == "2024-01-15T12:00:00Z"
    end

    test "returns error for invalid input" do
      query = """
      {
        parseTime(time: "not a date")
      }
      """

      assert {:ok, %{errors: errors}} = Absinthe.run(query, TestSchema)
      assert errors != []
    end

    test "money scalar works with integers" do
      query = """
      {
        parsePrice(amount: 999)
      }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, TestSchema)
      assert data["parsePrice"] == 999
    end
  end

  describe "CQL operators" do
    test "defines __cql_operators__/0" do
      assert PointScalar.__cql_operators__() == [:eq, :near, :within_distance]
    end

    test "defines __has_cql_operators__/0 as true when operators defined" do
      assert PointScalar.__has_cql_operators__() == true
    end

    test "defines __has_cql_operators__/0 as false when no operators" do
      assert NoOpScalar.__has_cql_operators__() == false
    end

    test "__cql_operators__/0 returns empty list when no operators defined" do
      assert NoOpScalar.__cql_operators__() == []
    end
  end

  describe "filter macro" do
    test "applies 2-arity filter function" do
      result = PointScalar.__apply_filter__(:near, :location, %{lng: 1, lat: 2}, [])

      assert result == {:geo_near, :location, %{lng: 1, lat: 2}}
    end

    test "applies 3-arity filter function with opts" do
      result = PointScalar.__apply_filter__(:within_distance, :location, %{lng: 1, lat: 2}, distance: 500)

      assert result == {:geo_within, :location, %{lng: 1, lat: 2}, 500}
    end

    test "applies filter defined with explicit opts parameter" do
      result = RangeScalar.__apply_filter__(:gt, :amount, 100, strict: true)

      assert result == {:gt, :amount, 100, [strict: true]}
    end

    test "returns nil for unknown operator" do
      result = PointScalar.__apply_filter__(:unknown, :field, :value, [])

      assert result == nil
    end

    test "returns nil when scalar has no filters defined" do
      result = DateTimeScalar.__apply_filter__(:eq, :field, :value, [])

      assert result == nil
    end
  end

  describe "scalar with description option" do
    test "accepts description in opts" do
      type = Absinthe.Schema.lookup_type(TestSchema, :money)

      assert type != nil
      # The description from opts should be set
      assert type.description == "A monetary value in cents"
    end
  end

  describe "CQL input type" do
    defmodule ScalarWithCqlInput do
      use GreenFairy.Scalar

      scalar "CustomScalar" do
        operators([:eq, :neq])

        cql_input "CqlOpCustomScalarInput" do
          field :_eq, :string
          field :_neq, :string
          field :_is_null, :boolean
        end

        parse fn _ -> :error end
        serialize fn v -> v end
      end
    end

    test "defines __has_cql_input__ as true when cql_input defined" do
      assert ScalarWithCqlInput.__has_cql_input__() == true
    end

    test "defines __cql_input_identifier__" do
      assert ScalarWithCqlInput.__cql_input_identifier__() == :cql_op_custom_scalar_input
    end

    test "no cql input returns nil for identifier" do
      assert NoOpScalar.__cql_input_identifier__() == nil
    end

    test "no cql input returns false for has_cql_input" do
      assert NoOpScalar.__has_cql_input__() == false
    end
  end
end
