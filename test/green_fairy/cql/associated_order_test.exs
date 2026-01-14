defmodule GreenFairy.CQL.AssociatedOrderTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.{AssociatedOrder, OrderOperator}

  describe "new/1" do
    test "creates struct with required fields" do
      order =
        AssociatedOrder.new(
          parent_field: :organization,
          order_term: %OrderOperator{field: :name, direction: :asc}
        )

      assert %AssociatedOrder{} = order
      assert order.parent_field == :organization
      assert %OrderOperator{field: :name, direction: :asc} = order.order_term
    end

    test "creates struct with all fields" do
      inject_fn = fn q, _alias -> q end

      order =
        AssociatedOrder.new(
          association: %{cardinality: :one},
          parent_field: :organization,
          order_term: %OrderOperator{field: :name, direction: :desc},
          list_module: SomeModule,
          inject: inject_fn
        )

      assert order.association == %{cardinality: :one}
      assert order.list_module == SomeModule
      assert order.inject == inject_fn
    end
  end

  describe "cardinality/1" do
    test "returns cardinality from association" do
      order = %AssociatedOrder{
        association: %{cardinality: :one},
        parent_field: :org,
        order_term: nil
      }

      assert AssociatedOrder.cardinality(order) == :one
    end

    test "returns cardinality :many from association" do
      order = %AssociatedOrder{
        association: %{cardinality: :many},
        parent_field: :posts,
        order_term: nil
      }

      assert AssociatedOrder.cardinality(order) == :many
    end

    test "returns nil when no association" do
      order = %AssociatedOrder{
        association: nil,
        parent_field: :org,
        order_term: nil
      }

      assert AssociatedOrder.cardinality(order) == nil
    end
  end

  describe "orderable?/2" do
    test "returns true for :one cardinality" do
      order = %AssociatedOrder{
        association: %{cardinality: :one},
        parent_field: :org,
        order_term: nil
      }

      assert AssociatedOrder.orderable?(order) == true
    end

    test "returns false for :many cardinality by default" do
      order = %AssociatedOrder{
        association: %{cardinality: :many},
        parent_field: :posts,
        order_term: nil
      }

      assert AssociatedOrder.orderable?(order) == false
    end

    test "returns true for :many cardinality when allow_in_order_by is true" do
      order = %AssociatedOrder{
        association: %{cardinality: :many},
        parent_field: :posts,
        order_term: nil
      }

      assert AssociatedOrder.orderable?(order, allow_in_order_by: true) == true
    end

    test "returns true when cardinality is nil" do
      order = %AssociatedOrder{
        association: nil,
        parent_field: :org,
        order_term: nil
      }

      assert AssociatedOrder.orderable?(order) == true
    end
  end

  describe "nested ordering" do
    test "supports deeply nested orders" do
      nested_order =
        AssociatedOrder.new(
          parent_field: :organization,
          order_term:
            AssociatedOrder.new(
              parent_field: :parent_org,
              order_term: %OrderOperator{field: :name, direction: :asc}
            )
        )

      assert nested_order.parent_field == :organization
      assert nested_order.order_term.parent_field == :parent_org
      assert nested_order.order_term.order_term.field == :name
    end
  end
end
