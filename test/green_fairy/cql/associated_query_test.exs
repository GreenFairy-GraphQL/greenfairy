defmodule GreenFairy.CQL.AssociatedQueryTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.{AssociatedQuery, QueryDefinition}

  describe "new/1" do
    test "creates struct with required fields" do
      qd = %QueryDefinition{where: nil, order_by: []}

      query =
        AssociatedQuery.new(
          parent_field: :organization,
          query_definition: qd
        )

      assert %AssociatedQuery{} = query
      assert query.parent_field == :organization
      assert query.query_definition == qd
    end

    test "creates struct with all fields" do
      qd = %QueryDefinition{where: {:eq, :name, "test"}, order_by: []}
      inject_fn = fn q, _alias -> q end

      query =
        AssociatedQuery.new(
          association: %{cardinality: :one, queryable: SomeSchema},
          parent_field: :organization,
          query_definition: qd,
          list_module: SomeModule,
          inject: inject_fn
        )

      assert query.association == %{cardinality: :one, queryable: SomeSchema}
      assert query.list_module == SomeModule
      assert query.inject == inject_fn
    end
  end

  describe "related_queryable/1" do
    test "returns queryable from association" do
      query = %AssociatedQuery{
        association: %{queryable: MyApp.Organization},
        parent_field: :org,
        query_definition: nil
      }

      assert AssociatedQuery.related_queryable(query) == MyApp.Organization
    end

    test "returns nil when no association" do
      query = %AssociatedQuery{
        association: nil,
        parent_field: :org,
        query_definition: nil
      }

      assert AssociatedQuery.related_queryable(query) == nil
    end
  end

  describe "cardinality/1" do
    test "returns cardinality from association" do
      query = %AssociatedQuery{
        association: %{cardinality: :one},
        parent_field: :org,
        query_definition: nil
      }

      assert AssociatedQuery.cardinality(query) == :one
    end

    test "returns cardinality :many from association" do
      query = %AssociatedQuery{
        association: %{cardinality: :many},
        parent_field: :posts,
        query_definition: nil
      }

      assert AssociatedQuery.cardinality(query) == :many
    end

    test "returns nil when no association" do
      query = %AssociatedQuery{
        association: nil,
        parent_field: :org,
        query_definition: nil
      }

      assert AssociatedQuery.cardinality(query) == nil
    end
  end
end
