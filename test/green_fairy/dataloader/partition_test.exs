defmodule GreenFairy.Dataloader.PartitionTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Dataloader.Partition

  # Test schemas with associations
  defmodule Organization do
    use Ecto.Schema

    schema "organizations" do
      field :name, :string
      has_many(:users, GreenFairy.Dataloader.PartitionTest.User)
    end
  end

  defmodule User do
    use Ecto.Schema

    schema "users" do
      field :name, :string
      belongs_to(:organization, Organization)
      has_many(:posts, GreenFairy.Dataloader.PartitionTest.Post)
    end
  end

  defmodule Post do
    use Ecto.Schema

    schema "posts" do
      field :title, :string
      belongs_to(:user, User)
    end
  end

  describe "new/1" do
    test "creates partition struct with required fields" do
      import Ecto.Query

      query = from(o in Organization)

      partition =
        Partition.new(
          query: query,
          owner: User,
          queryable: Organization,
          field: :organization
        )

      assert %Partition{} = partition
      assert partition.owner == User
      assert partition.queryable == Organization
      assert partition.field == :organization
      assert partition.sort == []
      assert partition.connection_args == %{}
      assert partition.windowed == false
    end

    test "creates partition struct with optional fields" do
      import Ecto.Query

      query = from(o in Organization)
      custom_inject = fn q, _alias, _key -> q end
      post_process = fn results -> results end

      partition =
        Partition.new(
          query: query,
          owner: User,
          queryable: Organization,
          field: :organization,
          repo: TestRepo,
          sort: [{:asc, dynamic([o], o.name)}],
          connection_args: %{limit: 10, offset: 0},
          windowed: true,
          custom_inject: custom_inject,
          post_process: post_process
        )

      assert partition.repo == TestRepo
      assert partition.windowed == true
      assert partition.connection_args == %{limit: 10, offset: 0}
      assert is_function(partition.custom_inject, 3)
      assert is_function(partition.post_process, 1)
    end

    test "raises on missing required fields" do
      assert_raise ArgumentError, fn ->
        Partition.new(query: nil, owner: User)
      end
    end
  end

  describe "owner_key/1" do
    test "returns owner key for belongs_to association" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :organization
        )

      assert Partition.owner_key(partition) == :organization_id
    end

    test "returns owner key for has_many association" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(u in User),
          owner: Organization,
          queryable: User,
          field: :users
        )

      assert Partition.owner_key(partition) == :id
    end

    test "raises for non-existent association" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :nonexistent
        )

      assert_raise RuntimeError, ~r/Association nonexistent not found/, fn ->
        Partition.owner_key(partition)
      end
    end
  end

  describe "related_key/1" do
    test "returns related key for belongs_to association" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :organization
        )

      assert Partition.related_key(partition) == :id
    end

    test "returns related key for has_many association" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(u in User),
          owner: Organization,
          queryable: User,
          field: :users
        )

      assert Partition.related_key(partition) == :organization_id
    end

    test "raises for non-existent association" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :nonexistent
        )

      assert_raise RuntimeError, ~r/Association nonexistent not found/, fn ->
        Partition.related_key(partition)
      end
    end
  end

  describe "cardinality/1" do
    test "returns :one for belongs_to" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :organization
        )

      assert Partition.cardinality(partition) == :one
    end

    test "returns :many for has_many" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(u in User),
          owner: Organization,
          queryable: User,
          field: :users
        )

      assert Partition.cardinality(partition) == :many
    end

    test "returns :one as default for non-existent association" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :nonexistent
        )

      # When association doesn't have cardinality, returns :one as default
      assert Partition.cardinality(partition) == :one
    end
  end

  describe "partition_sort_direction" do
    test "defaults to :asc" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :organization
        )

      assert partition.partition_sort_direction == :asc
    end

    test "can be set to :desc" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :organization,
          partition_sort_direction: :desc
        )

      assert partition.partition_sort_direction == :desc
    end
  end
end
