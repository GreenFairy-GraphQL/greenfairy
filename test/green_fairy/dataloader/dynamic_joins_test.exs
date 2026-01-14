defmodule GreenFairy.Dataloader.DynamicJoinsTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Dataloader.{DynamicJoins, Partition}

  # Test schemas with various associations
  defmodule Organization do
    use Ecto.Schema

    schema "organizations" do
      field :name, :string
      field :status, :string
      has_many(:users, GreenFairy.Dataloader.DynamicJoinsTest.User)
    end
  end

  defmodule User do
    use Ecto.Schema

    schema "users" do
      field :name, :string
      field :email, :string
      belongs_to(:organization, Organization)
      has_many(:posts, GreenFairy.Dataloader.DynamicJoinsTest.Post)
    end
  end

  defmodule Post do
    use Ecto.Schema

    schema "posts" do
      field :title, :string
      field :body, :string
      belongs_to(:user, User)
      has_many(:comments, GreenFairy.Dataloader.DynamicJoinsTest.Comment)
    end
  end

  defmodule Comment do
    use Ecto.Schema

    schema "comments" do
      field :body, :string
      belongs_to(:post, Post)
    end
  end

  describe "build_join_chain/2" do
    test "builds join chain for belongs_to association" do
      chain = DynamicJoins.build_join_chain(User, :organization)

      assert length(chain) == 1
      [join_info] = chain

      assert join_info.owner == User
      assert join_info.owner_key == :organization_id
      assert join_info.related_key == :id
    end

    test "builds join chain for has_many association" do
      chain = DynamicJoins.build_join_chain(Organization, :users)

      assert length(chain) == 1
      [join_info] = chain

      assert join_info.owner == Organization
      assert join_info.owner_key == :id
      assert join_info.related_key == :organization_id
    end

    test "raises for non-existent association" do
      assert_raise ArgumentError, ~r/Association nonexistent not found/, fn ->
        DynamicJoins.build_join_chain(User, :nonexistent)
      end
    end
  end

  describe "invert_query/2" do
    test "builds inverted query for belongs_to" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :organization
        )

      result = DynamicJoins.invert_query(partition, [1, 2, 3])

      assert %{query: query, partition: ^partition} = result
      assert result.scope_key == :id
    end

    test "builds inverted query for has_many" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(u in User),
          owner: Organization,
          queryable: User,
          field: :users
        )

      result = DynamicJoins.invert_query(partition, [1, 2, 3])

      assert %{query: _query, partition: ^partition} = result
      assert result.scope_key == :organization_id
    end
  end

  describe "existence_subquery/2" do
    test "builds existence subquery for belongs_to" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :organization
        )

      subquery = DynamicJoins.existence_subquery(partition, :parent)

      # The subquery should be an Ecto query
      assert %Ecto.Query{} = subquery
    end

    test "builds existence subquery for has_many" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(u in User),
          owner: Organization,
          queryable: User,
          field: :users
        )

      subquery = DynamicJoins.existence_subquery(partition, :parent)

      assert %Ecto.Query{} = subquery
    end
  end

  describe "existence_subquery/3 with explicit owner key" do
    test "builds existence subquery with custom owner key" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :organization
        )

      subquery = DynamicJoins.existence_subquery(partition, :parent, :organization_id)

      assert %Ecto.Query{} = subquery
    end
  end
end
