defmodule GreenFairy.CQL.QueryAssocTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.QueryAssoc

  # Test schemas with associations
  defmodule Organization do
    use Ecto.Schema

    schema "organizations" do
      field :name, :string
      has_many(:users, GreenFairy.CQL.QueryAssocTest.User)
    end
  end

  defmodule User do
    use Ecto.Schema

    schema "users" do
      field :name, :string
      belongs_to(:organization, Organization)
      has_many(:posts, GreenFairy.CQL.QueryAssocTest.Post)
    end
  end

  defmodule Post do
    use Ecto.Schema

    schema "posts" do
      field :title, :string
      belongs_to(:user, User)
    end
  end

  defmodule Comment do
    use Ecto.Schema

    schema "comments" do
      field :body, :string
      belongs_to(:post, Post)
    end
  end

  # Schema with has_many :through
  defmodule Author do
    use Ecto.Schema

    schema "authors" do
      field :name, :string
      has_many(:posts, GreenFairy.CQL.QueryAssocTest.AuthorPost)
      has_many(:comments, through: [:posts, :comments])
    end
  end

  defmodule AuthorPost do
    use Ecto.Schema

    schema "author_posts" do
      field :title, :string
      belongs_to(:author, Author)
      has_many(:comments, GreenFairy.CQL.QueryAssocTest.AuthorComment)
    end
  end

  defmodule AuthorComment do
    use Ecto.Schema

    schema "author_comments" do
      field :body, :string
      belongs_to(:post, AuthorPost)
    end
  end

  describe "new/1" do
    test "creates query assoc for belongs_to" do
      assoc = QueryAssoc.new(queryable: User, field: :organization)

      assert %QueryAssoc{} = assoc
      assert assoc.field == :organization
      assert assoc.query_field == :organization
      assert assoc.related_queryable == Organization
      assert %Ecto.Association.BelongsTo{} = assoc.association
    end

    test "creates query assoc for has_many" do
      assoc = QueryAssoc.new(queryable: Organization, field: :users)

      assert assoc.field == :users
      assert assoc.related_queryable == User
      assert %Ecto.Association.Has{} = assoc.association
    end

    test "accepts field alias with :as option" do
      assoc = QueryAssoc.new(queryable: User, field: :organization, as: :org)

      assert assoc.field == :org
      assert assoc.query_field == :organization
    end

    test "accepts description" do
      assoc =
        QueryAssoc.new(
          queryable: User,
          field: :organization,
          description: "The user's organization"
        )

      assert assoc.description == "The user's organization"
    end

    test "accepts allow_in_order_by option" do
      assoc =
        QueryAssoc.new(
          queryable: Organization,
          field: :users,
          allow_in_order_by: true
        )

      assert assoc.allow_in_order_by == true
    end

    test "accepts inject function" do
      inject_fn = fn query, _field -> query end

      assoc =
        QueryAssoc.new(
          queryable: User,
          field: :organization,
          inject: inject_fn
        )

      assert assoc.inject == inject_fn
    end

    test "raises for missing association" do
      assert_raise ArgumentError, ~r/Association `nonexistent` not found/, fn ->
        QueryAssoc.new(queryable: User, field: :nonexistent)
      end
    end

    test "raises for HasThrough without allow_has_through" do
      assert_raise ArgumentError, ~r/HasThrough associations are not supported/, fn ->
        QueryAssoc.new(queryable: Author, field: :comments)
      end
    end

    test "allows HasThrough with allow_has_through: true" do
      assoc =
        QueryAssoc.new(
          queryable: Author,
          field: :comments,
          allow_has_through: true
        )

      assert %QueryAssoc{} = assoc
      assert assoc.field == :comments
      assert assoc.allow_has_through == true
      # The related queryable should be the final target (AuthorComment)
      assert assoc.related_queryable == AuthorComment
    end
  end

  describe "cardinality/1" do
    test "returns :one for belongs_to" do
      assoc = QueryAssoc.new(queryable: User, field: :organization)

      assert QueryAssoc.cardinality(assoc) == :one
    end

    test "returns :many for has_many" do
      assoc = QueryAssoc.new(queryable: Organization, field: :users)

      assert QueryAssoc.cardinality(assoc) == :many
    end
  end

  describe "orderable?/1" do
    test "returns true for :one associations" do
      assoc = QueryAssoc.new(queryable: User, field: :organization)

      assert QueryAssoc.orderable?(assoc) == true
    end

    test "returns false for :many associations by default" do
      assoc = QueryAssoc.new(queryable: Organization, field: :users)

      assert QueryAssoc.orderable?(assoc) == false
    end

    test "returns true for :many with allow_in_order_by" do
      assoc =
        QueryAssoc.new(
          queryable: Organization,
          field: :users,
          allow_in_order_by: true
        )

      assert QueryAssoc.orderable?(assoc) == true
    end
  end

  describe "filterable?/1" do
    test "returns true for all associations" do
      belongs_to = QueryAssoc.new(queryable: User, field: :organization)
      has_many = QueryAssoc.new(queryable: Organization, field: :users)

      assert QueryAssoc.filterable?(belongs_to) == true
      assert QueryAssoc.filterable?(has_many) == true
    end
  end
end
