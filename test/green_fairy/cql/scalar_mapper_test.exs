defmodule GreenFairy.CQL.ScalarMapperTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.ScalarMapper
  alias GreenFairy.CQL.Scalars

  describe "scalar_for/1" do
    test "returns String scalar for :string" do
      assert ScalarMapper.scalar_for(:string) == Scalars.String
    end

    test "returns Integer scalar for :integer" do
      assert ScalarMapper.scalar_for(:integer) == Scalars.Integer
    end

    test "returns Float scalar for :float" do
      assert ScalarMapper.scalar_for(:float) == Scalars.Float
    end

    test "returns Decimal scalar for :decimal" do
      assert ScalarMapper.scalar_for(:decimal) == Scalars.Decimal
    end

    test "returns Boolean scalar for :boolean" do
      assert ScalarMapper.scalar_for(:boolean) == Scalars.Boolean
    end

    test "returns ID scalar for :id" do
      assert ScalarMapper.scalar_for(:id) == Scalars.ID
    end

    test "returns ID scalar for :binary_id" do
      assert ScalarMapper.scalar_for(:binary_id) == Scalars.ID
    end

    test "returns DateTime scalar for :utc_datetime" do
      assert ScalarMapper.scalar_for(:utc_datetime) == Scalars.DateTime
    end

    test "returns DateTime scalar for :utc_datetime_usec" do
      assert ScalarMapper.scalar_for(:utc_datetime_usec) == Scalars.DateTime
    end

    test "returns DateTime scalar for :datetime" do
      assert ScalarMapper.scalar_for(:datetime) == Scalars.DateTime
    end

    test "returns NaiveDateTime scalar for :naive_datetime" do
      assert ScalarMapper.scalar_for(:naive_datetime) == Scalars.NaiveDateTime
    end

    test "returns NaiveDateTime scalar for :naive_datetime_usec" do
      assert ScalarMapper.scalar_for(:naive_datetime_usec) == Scalars.NaiveDateTime
    end

    test "returns Date scalar for :date" do
      assert ScalarMapper.scalar_for(:date) == Scalars.Date
    end

    test "returns Time scalar for :time" do
      assert ScalarMapper.scalar_for(:time) == Scalars.Time
    end

    test "returns Time scalar for :time_usec" do
      assert ScalarMapper.scalar_for(:time_usec) == Scalars.Time
    end

    test "returns JSON scalar for :map" do
      assert ScalarMapper.scalar_for(:map) == GreenFairy.BuiltIns.Scalars.JSON
    end

    test "returns JSON scalar for {:map, _}" do
      assert ScalarMapper.scalar_for({:map, :string}) == GreenFairy.BuiltIns.Scalars.JSON
    end

    test "returns nil for :array without inner type" do
      assert ScalarMapper.scalar_for(:array) == nil
    end

    test "returns ArrayString scalar for {:array, :string}" do
      assert ScalarMapper.scalar_for({:array, :string}) == Scalars.ArrayString
    end

    test "returns ArrayInteger scalar for {:array, :integer}" do
      assert ScalarMapper.scalar_for({:array, :integer}) == Scalars.ArrayInteger
    end

    test "returns ArrayID scalar for {:array, :id}" do
      assert ScalarMapper.scalar_for({:array, :id}) == Scalars.ArrayID
    end

    test "returns ArrayID scalar for {:array, :binary_id}" do
      assert ScalarMapper.scalar_for({:array, :binary_id}) == Scalars.ArrayID
    end

    test "returns nil for {:array, _} with unknown type" do
      assert ScalarMapper.scalar_for({:array, :unknown}) == nil
    end

    test "returns Enum scalar for parameterized Ecto.Enum" do
      assert ScalarMapper.scalar_for({:parameterized, Ecto.Enum, %{values: [:a, :b]}}) ==
               Scalars.Enum
    end

    test "returns ArrayEnum scalar for {:array, parameterized Ecto.Enum}" do
      assert ScalarMapper.scalar_for({:array, {:parameterized, Ecto.Enum, %{values: [:a, :b]}}}) ==
               Scalars.ArrayEnum
    end

    test "returns nil for parameterized Ecto.Embedded" do
      assert ScalarMapper.scalar_for({:parameterized, Ecto.Embedded, %{}}) == nil
    end

    test "returns Coordinates scalar for :geometry" do
      assert ScalarMapper.scalar_for(:geometry) == Scalars.Coordinates
    end

    test "returns Coordinates scalar for :geography" do
      assert ScalarMapper.scalar_for(:geography) == Scalars.Coordinates
    end

    test "returns Coordinates scalar for :coordinates" do
      assert ScalarMapper.scalar_for(:coordinates) == Scalars.Coordinates
    end

    test "returns Coordinates scalar for :geo_point" do
      assert ScalarMapper.scalar_for(:geo_point) == Scalars.Coordinates
    end

    test "returns Coordinates scalar for :location" do
      assert ScalarMapper.scalar_for(:location) == Scalars.Coordinates
    end

    test "returns nil for unknown atom types" do
      assert ScalarMapper.scalar_for(:unknown_type) == nil
    end

    test "returns nil for unknown tuple types" do
      assert ScalarMapper.scalar_for({:unknown, :type}) == nil
    end
  end

  describe "scalar_for/1 with EctoEnum module" do
    defmodule FakeEctoEnum do
      def __enum_map__, do: [active: "active", inactive: "inactive"]
    end

    defmodule NotAnEnum do
      # No __enum_map__/0 function
    end

    test "returns Enum scalar for EctoEnum module" do
      assert ScalarMapper.scalar_for(FakeEctoEnum) == Scalars.Enum
    end

    test "returns nil for module without __enum_map__" do
      assert ScalarMapper.scalar_for(NotAnEnum) == nil
    end
  end
end
