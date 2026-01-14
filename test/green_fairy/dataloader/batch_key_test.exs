defmodule GreenFairy.Dataloader.BatchKeyTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Dataloader.BatchKey

  # Test schemas with associations
  defmodule Organization do
    use Ecto.Schema

    schema "organizations" do
      field :name, :string
      has_many(:users, GreenFairy.Dataloader.BatchKeyTest.User)
    end
  end

  defmodule User do
    use Ecto.Schema

    schema "users" do
      field :name, :string
      belongs_to(:organization, Organization)
      has_many(:posts, GreenFairy.Dataloader.BatchKeyTest.Post)
    end
  end

  defmodule Post do
    use Ecto.Schema

    schema "posts" do
      field :title, :string
      belongs_to(:user, User)
    end
  end

  defmodule TestRepo do
    def all(_query), do: []
  end

  describe "new/4" do
    test "creates batch key for belongs_to association" do
      user = %User{id: 1, name: "Alice", organization_id: 10}

      batch_key = BatchKey.new(user, :organization, %{}, repo: TestRepo)

      assert %BatchKey{} = batch_key
      assert batch_key.field == :organization
      assert batch_key.args == %{}
      assert batch_key.queryable == User
      assert batch_key.partition_key == :organization_id
      assert batch_key.cardinality == :one
      assert batch_key.type == :partitioned
      assert batch_key.repo == TestRepo
    end

    test "creates batch key for has_many association" do
      org = %Organization{id: 1, name: "Acme"}

      batch_key = BatchKey.new(org, :users, %{}, repo: TestRepo)

      assert batch_key.field == :users
      assert batch_key.partition_key == :id
      assert batch_key.cardinality == :many
    end

    test "accepts type option" do
      user = %User{id: 1, organization_id: 10}

      batch_key = BatchKey.new(user, :organization, %{}, repo: TestRepo, type: :count)

      assert batch_key.type == :count
    end

    test "accepts force_custom_batch option" do
      user = %User{id: 1, organization_id: 10}

      batch_key =
        BatchKey.new(user, :organization, %{},
          repo: TestRepo,
          force_custom_batch: true
        )

      assert batch_key.force_custom_batch == true
    end

    test "includes args in batch key" do
      user = %User{id: 1, organization_id: 10}
      args = %{status: "active", limit: 10}

      batch_key = BatchKey.new(user, :organization, args, repo: TestRepo)

      assert batch_key.args == args
    end

    test "raises for missing association" do
      user = %User{id: 1}

      assert_raise ArgumentError, ~r/Association nonexistent not found/, fn ->
        BatchKey.new(user, :nonexistent, %{}, repo: TestRepo)
      end
    end
  end

  describe "partition_value/2" do
    test "extracts partition value from parent" do
      user = %User{id: 1, name: "Alice", organization_id: 10}
      batch_key = BatchKey.new(user, :organization, %{}, repo: TestRepo)

      assert BatchKey.partition_value(batch_key, user) == 10
    end

    test "returns nil when partition key is nil" do
      user = %User{id: 1, name: "Alice", organization_id: nil}
      batch_key = BatchKey.new(user, :organization, %{}, repo: TestRepo)

      assert BatchKey.partition_value(batch_key, user) == nil
    end
  end

  describe "extract_association_info/2" do
    test "extracts info for belongs_to" do
      {owner_key, cardinality} = BatchKey.extract_association_info(User, :organization)

      assert owner_key == :organization_id
      assert cardinality == :one
    end

    test "extracts info for has_many" do
      {owner_key, cardinality} = BatchKey.extract_association_info(Organization, :users)

      assert owner_key == :id
      assert cardinality == :many
    end

    test "raises for missing association" do
      assert_raise ArgumentError, ~r/Association missing not found/, fn ->
        BatchKey.extract_association_info(User, :missing)
      end
    end
  end
end
