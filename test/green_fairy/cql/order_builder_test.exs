defmodule GreenFairy.CQL.OrderBuilderTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.OrderBuilder
  import Ecto.Query

  defmodule TestUser do
    use Ecto.Schema

    schema "users" do
      field :name, :string
      field :age, :integer
      field :email, :string
    end
  end

  describe "apply_order/4" do
    test "returns query unchanged with nil order" do
      query = from(u in TestUser)
      result = OrderBuilder.apply_order(query, nil)

      assert result == query
    end

    test "returns query unchanged with empty order list" do
      query = from(u in TestUser)
      result = OrderBuilder.apply_order(query, [])

      assert result == query
    end

    test "applies single field asc ordering" do
      query = from(u in TestUser)
      order = [%{name: %{direction: :asc}}]

      result = OrderBuilder.apply_order(query, order, TestUser)

      assert %Ecto.Query{order_bys: order_bys} = result
      assert length(order_bys) > 0
    end

    test "applies single field desc ordering" do
      query = from(u in TestUser)
      order = [%{name: %{direction: :desc}}]

      result = OrderBuilder.apply_order(query, order, TestUser)

      assert %Ecto.Query{order_bys: order_bys} = result
      assert length(order_bys) > 0
    end

    test "applies multiple field ordering" do
      query = from(u in TestUser)
      order = [
        %{name: %{direction: :asc}},
        %{age: %{direction: :desc}}
      ]

      result = OrderBuilder.apply_order(query, order, TestUser)

      assert %Ecto.Query{order_bys: order_bys} = result
      assert length(order_bys) > 0
    end

    test "handles direction atom shorthand" do
      query = from(u in TestUser)
      order = [%{name: :asc}]

      result = OrderBuilder.apply_order(query, order, TestUser)

      assert %Ecto.Query{order_bys: order_bys} = result
      assert length(order_bys) > 0
    end

    test "skips logical operators like _and, _or, _not" do
      query = from(u in TestUser)
      order = [
        %{_and: [%{name: %{direction: :asc}}]},
        %{name: %{direction: :asc}}
      ]

      result = OrderBuilder.apply_order(query, order, TestUser)

      assert %Ecto.Query{order_bys: order_bys} = result
      assert length(order_bys) > 0
    end

    test "skips non-atom keys" do
      query = from(u in TestUser)
      order = [%{"string_key" => %{direction: :asc}, name: %{direction: :asc}}]

      result = OrderBuilder.apply_order(query, order, TestUser)

      assert %Ecto.Query{order_bys: order_bys} = result
      assert length(order_bys) > 0
    end

    test "returns query unchanged when all order specs are invalid" do
      query = from(u in TestUser)
      order = [%{_and: [%{name: %{direction: :asc}}]}]

      result = OrderBuilder.apply_order(query, order, TestUser)

      # Should return unchanged query since _and is skipped
      assert %Ecto.Query{order_bys: order_bys} = result
      assert order_bys == []
    end

    test "handles non-map order spec gracefully" do
      query = from(u in TestUser)
      order = ["not_a_map"]

      result = OrderBuilder.apply_order(query, order, TestUser)

      assert %Ecto.Query{order_bys: order_bys} = result
      assert order_bys == []
    end
  end
end
