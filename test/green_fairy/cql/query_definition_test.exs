defmodule GreenFairy.CQL.QueryDefinitionTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.QueryDefinition

  describe "new/1" do
    test "creates empty struct by default" do
      qd = QueryDefinition.new()

      assert %QueryDefinition{} = qd
      assert qd.where == nil
      assert qd.order_by == []
    end

    test "creates struct with where clause" do
      qd = QueryDefinition.new(where: {:eq, :name, "test"})

      assert qd.where == {:eq, :name, "test"}
      assert qd.order_by == []
    end

    test "creates struct with order_by" do
      qd = QueryDefinition.new(order_by: [{:asc, :name}])

      assert qd.where == nil
      assert qd.order_by == [{:asc, :name}]
    end

    test "creates struct with both where and order_by" do
      qd =
        QueryDefinition.new(
          where: {:eq, :status, "active"},
          order_by: [{:asc, :name}, {:desc, :created_at}]
        )

      assert qd.where == {:eq, :status, "active"}
      assert qd.order_by == [{:asc, :name}, {:desc, :created_at}]
    end
  end

  describe "has_where?/1" do
    test "returns false for nil where" do
      qd = %QueryDefinition{where: nil, order_by: []}

      assert QueryDefinition.has_where?(qd) == false
    end

    test "returns true for non-nil where" do
      qd = %QueryDefinition{where: {:eq, :name, "test"}, order_by: []}

      assert QueryDefinition.has_where?(qd) == true
    end
  end

  describe "has_order_by?/1" do
    test "returns false for empty order_by" do
      qd = %QueryDefinition{where: nil, order_by: []}

      assert QueryDefinition.has_order_by?(qd) == false
    end

    test "returns true for non-empty order_by" do
      qd = %QueryDefinition{where: nil, order_by: [{:asc, :name}]}

      assert QueryDefinition.has_order_by?(qd) == true
    end
  end

  describe "empty?/1" do
    test "returns true when no where and no order_by" do
      qd = %QueryDefinition{where: nil, order_by: []}

      assert QueryDefinition.empty?(qd) == true
    end

    test "returns false when has where" do
      qd = %QueryDefinition{where: {:eq, :name, "test"}, order_by: []}

      assert QueryDefinition.empty?(qd) == false
    end

    test "returns false when has order_by" do
      qd = %QueryDefinition{where: nil, order_by: [{:asc, :name}]}

      assert QueryDefinition.empty?(qd) == false
    end

    test "returns false when has both where and order_by" do
      qd = %QueryDefinition{where: {:eq, :status, "active"}, order_by: [{:asc, :name}]}

      assert QueryDefinition.empty?(qd) == false
    end
  end
end
