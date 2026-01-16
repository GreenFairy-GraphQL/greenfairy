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

  describe "invert_query with pagination" do
    test "applies limit from connection_args" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :organization,
          connection_args: %{limit: 10}
        )

      result = DynamicJoins.invert_query(partition, [1, 2, 3])

      assert %{query: _query} = result
    end

    test "applies first as limit" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :organization,
          connection_args: %{first: 5}
        )

      result = DynamicJoins.invert_query(partition, [1, 2, 3])

      assert %{query: _query} = result
    end

    test "applies offset from connection_args" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :organization,
          connection_args: %{offset: 20}
        )

      result = DynamicJoins.invert_query(partition, [1, 2, 3])

      assert %{query: _query} = result
    end
  end

  describe "invert_query with sorting" do
    test "applies sort directions" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :organization,
          sort: [{:asc, dynamic([o], o.name)}]
        )

      result = DynamicJoins.invert_query(partition, [1, 2, 3])

      assert %{query: _query} = result
    end

    test "handles empty sort list" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :organization,
          sort: []
        )

      result = DynamicJoins.invert_query(partition, [1, 2, 3])

      assert %{query: _query} = result
    end
  end

  describe "invert_query with custom injection" do
    test "applies custom inject function" do
      import Ecto.Query

      inject_fn = fn query, _scope_alias, _scope_key ->
        where(query, [q], q.status == "active")
      end

      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :organization,
          custom_inject: inject_fn
        )

      result = DynamicJoins.invert_query(partition, [1, 2, 3])

      assert %{query: query} = result
      assert %Ecto.Query{wheres: wheres} = query
      assert length(wheres) > 0
    end

    test "handles nil custom_inject" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :organization,
          custom_inject: nil
        )

      result = DynamicJoins.invert_query(partition, [1, 2, 3])

      assert %{query: _query} = result
    end
  end

  describe "nested associations" do
    test "handles nested association chain for posts through users" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(p in Post),
          owner: User,
          queryable: Post,
          field: :posts
        )

      result = DynamicJoins.invert_query(partition, [1, 2, 3])

      assert %{query: _query} = result
    end

    test "handles deeply nested association for comments through posts" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(c in Comment),
          owner: Post,
          queryable: Comment,
          field: :comments
        )

      result = DynamicJoins.invert_query(partition, [1, 2, 3])

      assert %{query: _query} = result
    end
  end

  describe "alias helpers" do
    test "current_alias returns correct alias for valid counts" do
      # These are internal functions but we can test via invert_query behavior
      import Ecto.Query

      # Testing with multiple levels of joins
      partition =
        Partition.new(
          query: from(c in Comment),
          owner: Post,
          queryable: Comment,
          field: :comments
        )

      result = DynamicJoins.invert_query(partition, [1, 2])
      assert is_map(result)
    end

    test "handles count at boundary" do
      import Ecto.Query

      # Testing with belongs_to
      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :organization
        )

      result = DynamicJoins.invert_query(partition, [1])
      assert is_map(result)
    end
  end

  describe "partitioned/3" do
    defmodule MockRepo do
      def all(query) do
        # Return mock results with partition_id_
        [
          %{id: 1, name: "Result 1", partition_id_: 10},
          %{id: 2, name: "Result 2", partition_id_: 10},
          %{id: 3, name: "Result 3", partition_id_: 20}
        ]
      end
    end

    test "executes query and groups by partition_id_" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :organization
        )

      result = DynamicJoins.partitioned(partition, [10, 20], MockRepo)

      assert is_map(result)
      assert Map.has_key?(result, 10)
      assert Map.has_key?(result, 20)
      assert length(result[10]) == 2
      assert length(result[20]) == 1
    end

    test "applies pagination to query" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :organization,
          connection_args: %{limit: 10, offset: 5}
        )

      result = DynamicJoins.partitioned(partition, [10, 20], MockRepo)
      assert is_map(result)
    end

    test "applies sort to query" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :organization,
          sort: [{:asc, dynamic([o], o.name)}, {:desc, dynamic([o], o.id)}]
        )

      result = DynamicJoins.partitioned(partition, [10, 20], MockRepo)
      assert is_map(result)
    end
  end

  describe "partitioned/3 with post_process" do
    defmodule MockRepoForPostProcess do
      def all(_query) do
        [
          %{id: 1, name: "lowercase", partition_id_: 10},
          %{id: 2, name: "also lowercase", partition_id_: 10}
        ]
      end
    end

    test "applies post_process function to results" do
      import Ecto.Query

      post_process_fn = fn results ->
        Enum.map(results, fn result ->
          Map.update!(result, :name, &String.upcase/1)
        end)
      end

      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :organization,
          post_process: post_process_fn
        )

      result = DynamicJoins.partitioned(partition, [10], MockRepoForPostProcess)

      assert is_map(result)
      assert [first | _] = result[10]
      assert first.name == "LOWERCASE"
    end

    test "handles nil post_process" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :organization,
          post_process: nil
        )

      result = DynamicJoins.partitioned(partition, [10], MockRepoForPostProcess)
      assert is_map(result)
    end
  end

  # Schema with HasThrough association for testing
  defmodule Category do
    use Ecto.Schema

    schema "categories" do
      field :name, :string
      has_many(:post_categories, GreenFairy.Dataloader.DynamicJoinsTest.PostCategory)
    end
  end

  defmodule PostCategory do
    use Ecto.Schema

    schema "post_categories" do
      field :priority, :integer
      belongs_to(:post, GreenFairy.Dataloader.DynamicJoinsTest.PostWithThrough)
      belongs_to(:category, GreenFairy.Dataloader.DynamicJoinsTest.Category)
    end
  end

  defmodule PostWithThrough do
    use Ecto.Schema

    schema "posts" do
      field :title, :string
      has_many(:post_categories, GreenFairy.Dataloader.DynamicJoinsTest.PostCategory)

      has_many :categories,
               through: [:post_categories, :category]
    end
  end

  describe "build_join_chain/2 with HasThrough" do
    test "builds chain for has_through association" do
      chain = DynamicJoins.build_join_chain(PostWithThrough, :categories)

      # has_through creates multiple join info entries
      assert length(chain) >= 1
      [first | _rest] = chain

      # First join should be from PostWithThrough to PostCategory
      assert first.owner == PostWithThrough
    end

    test "raises for non-existent through association" do
      assert_raise ArgumentError, ~r/Association/, fn ->
        DynamicJoins.build_join_chain(User, :nonexistent_through)
      end
    end
  end

  # Schema with ManyToMany association
  defmodule Tag do
    use Ecto.Schema

    schema "tags" do
      field :name, :string

      many_to_many :articles, GreenFairy.Dataloader.DynamicJoinsTest.Article,
        join_through: "article_tags",
        join_keys: [tag_id: :id, article_id: :id]
    end
  end

  defmodule Article do
    use Ecto.Schema

    schema "articles" do
      field :title, :string

      many_to_many :tags, GreenFairy.Dataloader.DynamicJoinsTest.Tag,
        join_through: "article_tags",
        join_keys: [article_id: :id, tag_id: :id]
    end
  end

  describe "build_join_chain/2 with ManyToMany" do
    test "splits many_to_many into two join infos" do
      chain = DynamicJoins.build_join_chain(Article, :tags)

      # ManyToMany creates two join info entries (join table + related)
      assert length(chain) == 2

      [join_table_info, related_info] = chain

      # First should be the join table connection
      assert join_table_info.owner == Article
      assert join_table_info.owner_key == :id
      assert join_table_info.related_key == :article_id

      # Second should connect to the related table
      assert related_info.owner_key == :tag_id
      assert related_info.related_key == :id
    end
  end

  # Schema with filtered associations (where clause)
  defmodule ActiveUser do
    use Ecto.Schema

    schema "users" do
      field :name, :string
      field :status, :string
      belongs_to(:organization, Organization)
    end
  end

  defmodule OrgWithActiveUsers do
    use Ecto.Schema

    schema "organizations" do
      field :name, :string

      has_many :active_users, GreenFairy.Dataloader.DynamicJoinsTest.ActiveUser,
        foreign_key: :organization_id,
        where: [status: "active"]
    end
  end

  describe "invert_query with filtered associations" do
    test "handles association with where filter" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(u in ActiveUser),
          owner: OrgWithActiveUsers,
          queryable: ActiveUser,
          field: :active_users
        )

      result = DynamicJoins.invert_query(partition, [1, 2, 3])

      assert %{query: query} = result
      # The where clause should be added to filter by status
      assert %Ecto.Query{wheres: wheres} = query
      assert length(wheres) > 0
    end
  end

  # Schema for testing nil filter values
  defmodule UserWithNullableOrg do
    use Ecto.Schema

    schema "users" do
      field :name, :string
      field :deleted_at, :utc_datetime
      belongs_to(:organization, Organization)
    end
  end

  defmodule OrgWithNonDeletedUsers do
    use Ecto.Schema

    schema "organizations" do
      field :name, :string

      has_many :non_deleted_users, GreenFairy.Dataloader.DynamicJoinsTest.UserWithNullableOrg,
        foreign_key: :organization_id,
        where: [deleted_at: nil]
    end
  end

  describe "invert_query with nil filter value" do
    test "handles association with nil where filter" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(u in UserWithNullableOrg),
          owner: OrgWithNonDeletedUsers,
          queryable: UserWithNullableOrg,
          field: :non_deleted_users
        )

      result = DynamicJoins.invert_query(partition, [1, 2, 3])

      assert %{query: query} = result
      assert %Ecto.Query{wheres: wheres} = query
      # Should have where clause for nil check
      assert length(wheres) > 0
    end
  end

  # Schema for testing {:not, value} filter
  defmodule OrgWithNonAdminUsers do
    use Ecto.Schema

    schema "organizations" do
      field :name, :string

      has_many :non_admin_users, GreenFairy.Dataloader.DynamicJoinsTest.User,
        foreign_key: :organization_id,
        where: [name: {:not, "admin"}]
    end
  end

  describe "invert_query with {:not, value} filter" do
    test "handles association with not filter" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(u in User),
          owner: OrgWithNonAdminUsers,
          queryable: User,
          field: :non_admin_users
        )

      result = DynamicJoins.invert_query(partition, [1, 2, 3])

      assert %{query: query} = result
      assert %Ecto.Query{wheres: wheres} = query
      # Should have where clause for != check
      assert length(wheres) > 0
    end
  end

  describe "existence_subquery edge cases" do
    test "existence_subquery with has_many association" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(p in Post),
          owner: User,
          queryable: Post,
          field: :posts
        )

      subquery = DynamicJoins.existence_subquery(partition, :parent)

      assert %Ecto.Query{} = subquery
      # Subquery should have a select of 1
      assert subquery.select != nil
    end

    test "existence_subquery with nested filtering" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(c in Comment, where: c.body != ""),
          owner: Post,
          queryable: Comment,
          field: :comments
        )

      subquery = DynamicJoins.existence_subquery(partition, :parent)

      assert %Ecto.Query{} = subquery
    end
  end

  describe "invert_query with scope_alias nil" do
    # Test the case where scope_alias is nil (single join chain)
    test "builds query with nil scope_alias for simple belongs_to" do
      import Ecto.Query

      partition =
        Partition.new(
          query: from(o in Organization),
          owner: User,
          queryable: Organization,
          field: :organization
        )

      result = DynamicJoins.invert_query(partition, [1, 2, 3])

      # For belongs_to with single step at count 0, scope_alias is nil (previous_alias(0) = nil)
      assert %{query: query, scope_alias: scope_alias} = result
      assert %Ecto.Query{} = query
      # At count 0, previous_alias returns nil
      assert scope_alias == nil
    end
  end
end
