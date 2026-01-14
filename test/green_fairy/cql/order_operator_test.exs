defmodule GreenFairy.CQL.OrderOperatorTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.OrderOperator

  describe "struct" do
    test "has default values" do
      op = %OrderOperator{field: :name}

      assert op.field == :name
      assert op.direction == :asc
      assert op.priority == []
      assert op.geo_distance == nil
    end
  end

  describe "from_input/2" do
    test "creates basic order operator" do
      op = OrderOperator.from_input(:name, %{direction: :desc})

      assert op.field == :name
      assert op.direction == :desc
      assert op.priority == []
      assert op.geo_distance == nil
    end

    test "uses default direction when not specified" do
      op = OrderOperator.from_input(:name, %{})

      assert op.direction == :asc
    end

    test "creates priority order operator" do
      op =
        OrderOperator.from_input(:status, %{
          direction: :asc,
          priority: [:active, :pending, :closed]
        })

      assert op.field == :status
      assert op.direction == :asc
      assert op.priority == [:active, :pending, :closed]
    end

    test "creates geo distance order operator" do
      op =
        OrderOperator.from_input(:location, %{
          direction: :asc,
          center: %{latitude: 40.7128, longitude: -74.0060}
        })

      assert op.field == :location
      assert op.direction == :asc
      assert op.geo_distance == {40.7128, -74.0060}
    end
  end

  describe "to_ecto_direction/1" do
    test "converts asc" do
      assert OrderOperator.to_ecto_direction(:asc) == :asc
    end

    test "converts desc" do
      assert OrderOperator.to_ecto_direction(:desc) == :desc
    end

    test "converts nulls_first variants" do
      assert OrderOperator.to_ecto_direction(:asc_nulls_first) == :asc_nulls_first
      assert OrderOperator.to_ecto_direction(:desc_nulls_first) == :desc_nulls_first
    end

    test "converts nulls_last variants" do
      assert OrderOperator.to_ecto_direction(:asc_nulls_last) == :asc_nulls_last
      assert OrderOperator.to_ecto_direction(:desc_nulls_last) == :desc_nulls_last
    end
  end

  describe "geo_order?/1" do
    test "returns false when no geo_distance" do
      op = %OrderOperator{field: :name}
      refute OrderOperator.geo_order?(op)
    end

    test "returns true when geo_distance present" do
      op = %OrderOperator{field: :location, geo_distance: {40.7128, -74.0060}}
      assert OrderOperator.geo_order?(op)
    end
  end

  describe "priority_order?/1" do
    test "returns false when priority empty" do
      op = %OrderOperator{field: :name}
      refute OrderOperator.priority_order?(op)
    end

    test "returns true when priority present" do
      op = %OrderOperator{field: :status, priority: [:active, :pending]}
      assert OrderOperator.priority_order?(op)
    end
  end
end
