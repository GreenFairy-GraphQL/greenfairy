defmodule Absinthe.Object.AuthorizeTest do
  use ExUnit.Case, async: true

  alias Absinthe.Object.AuthorizationInfo

  defmodule TestUser do
    defstruct [:id, :name, :email, :ssn, :password_hash]
  end

  defmodule TestPost do
    defstruct [:id, :title, :content, :author_id, :secret_notes]
  end

  # ============================================================================
  # Basic Authorization Tests
  # ============================================================================

  describe "type with authorize callback" do
    defmodule AuthorizedUserType do
      use Absinthe.Object.Type

      type "AuthorizedUser", struct: TestUser do
        authorize(fn user, ctx ->
          current_user = ctx[:current_user]

          cond do
            is_map(current_user) and current_user[:admin] -> :all
            is_map(current_user) and current_user[:id] == user.id -> [:id, :name, :email]
            true -> [:id, :name]
          end
        end)

        field :id, non_null(:id)
        field :name, :string
        field :email, :string
        field :ssn, :string
        field :password_hash, :string
      end
    end

    test "type has authorization" do
      assert AuthorizedUserType.__has_authorization__() == true
    end

    test "admin sees all fields" do
      user = %TestUser{id: "user-1"}
      ctx = %{current_user: %{id: "admin-1", admin: true}}
      info = %AuthorizationInfo{}

      assert AuthorizedUserType.__authorize__(user, ctx, info) == :all
    end

    test "user sees own fields" do
      user = %TestUser{id: "user-1"}
      ctx = %{current_user: %{id: "user-1"}}
      info = %AuthorizationInfo{}

      result = AuthorizedUserType.__authorize__(user, ctx, info)
      assert :id in result
      assert :name in result
      assert :email in result
      refute :ssn in result
    end

    test "other users see public fields only" do
      user = %TestUser{id: "user-1"}
      ctx = %{current_user: %{id: "user-2"}}
      info = %AuthorizationInfo{}

      result = AuthorizedUserType.__authorize__(user, ctx, info)
      assert result == [:id, :name]
    end

    test "anonymous sees public fields only" do
      user = %TestUser{id: "user-1"}
      ctx = %{}
      info = %AuthorizationInfo{}

      result = AuthorizedUserType.__authorize__(user, ctx, info)
      assert result == [:id, :name]
    end
  end

  # ============================================================================
  # Authorization with Path Info Tests
  # ============================================================================

  describe "type with authorize callback using info" do
    defmodule PostWithPathType do
      use Absinthe.Object.Type

      type "PostWithPath", struct: TestPost do
        authorize(fn post, ctx, info ->
          # Check if we're accessing through the author's own profile
          parent_is_author =
            case info.parent do
              %{id: id} -> id == post.author_id
              _ -> false
            end

          current_user = ctx[:current_user]

          cond do
            is_map(current_user) and current_user[:admin] -> :all
            parent_is_author -> :all
            is_map(current_user) and current_user[:id] == post.author_id -> [:id, :title, :content]
            true -> [:id, :title]
          end
        end)

        field :id, non_null(:id)
        field :title, :string
        field :content, :string
        field :secret_notes, :string
      end
    end

    test "authorize callback receives info with path" do
      post = %TestPost{id: "post-1", author_id: "user-1"}
      ctx = %{}
      info = %AuthorizationInfo{path: [:query, :user, :posts], field: :posts}

      # Just verify it doesn't crash with path info
      result = PostWithPathType.__authorize__(post, ctx, info)
      assert result == [:id, :title]
    end

    test "authorize callback receives info with parent" do
      post = %TestPost{id: "post-1", author_id: "user-1"}
      ctx = %{}
      info = %AuthorizationInfo{parent: %{id: "user-1"}}

      # When parent matches author, should see all fields
      result = PostWithPathType.__authorize__(post, ctx, info)
      assert result == :all
    end
  end

  # ============================================================================
  # Type without Authorization Tests
  # ============================================================================

  describe "type without authorize callback" do
    defmodule PublicUserType do
      use Absinthe.Object.Type

      type "PublicUser", struct: TestUser do
        field :id, non_null(:id)
        field :name, :string
      end
    end

    test "type has no authorization" do
      assert PublicUserType.__has_authorization__() == false
    end

    test "returns :all for any context" do
      user = %TestUser{id: "user-1"}
      ctx = %{}
      info = %AuthorizationInfo{}

      assert PublicUserType.__authorize__(user, ctx, info) == :all
    end
  end

  # ============================================================================
  # Legacy Policy Authorization Tests
  # ============================================================================

  describe "type with legacy policy" do
    defmodule TestPolicy do
      def can?(nil, _action, _resource), do: false
      def can?(%{admin: true}, :view, _resource), do: true
      def can?(%{id: user_id}, :view, %{id: user_id}), do: true
      def can?(_, _, _), do: false
    end

    defmodule LegacyPolicyType do
      use Absinthe.Object.Type

      type "LegacyPolicyUser", struct: TestUser do
        authorize(with: TestPolicy)

        field :id, non_null(:id)
        field :name, :string
      end
    end

    test "type has authorization via policy" do
      assert LegacyPolicyType.__has_authorization__() == true
    end

    test "policy allows admin" do
      user = %TestUser{id: "user-1"}
      ctx = %{current_user: %{admin: true}}
      info = %AuthorizationInfo{}

      assert LegacyPolicyType.__authorize__(user, ctx, info) == :all
    end

    test "policy allows owner" do
      user = %TestUser{id: "user-1"}
      ctx = %{current_user: %{id: "user-1"}}
      info = %AuthorizationInfo{}

      assert LegacyPolicyType.__authorize__(user, ctx, info) == :all
    end

    test "policy denies others" do
      user = %TestUser{id: "user-1"}
      ctx = %{current_user: %{id: "user-2"}}
      info = %AuthorizationInfo{}

      assert LegacyPolicyType.__authorize__(user, ctx, info) == :none
    end

    test "policy denies anonymous" do
      user = %TestUser{id: "user-1"}
      ctx = %{}
      info = %AuthorizationInfo{}

      assert LegacyPolicyType.__authorize__(user, ctx, info) == :none
    end
  end

  # ============================================================================
  # AuthorizationInfo Tests
  # ============================================================================

  describe "AuthorizationInfo" do
    test "root creates info for root query" do
      info = AuthorizationInfo.root(:users)

      assert info.path == [:users]
      assert info.field == :users
      assert info.parent == nil
      assert info.parents == []
    end

    test "push_parent adds parent to chain" do
      info = AuthorizationInfo.root(:users)
      parent = %TestUser{id: "user-1"}

      updated = AuthorizationInfo.push_parent(info, parent, :posts)

      assert updated.path == [:users, :posts]
      assert updated.field == :posts
      assert updated.parent == parent
      assert updated.parents == [parent]
    end

    test "push_parent accumulates parents" do
      info = AuthorizationInfo.root(:users)
      user = %TestUser{id: "user-1"}
      post = %TestPost{id: "post-1"}

      info = AuthorizationInfo.push_parent(info, user, :posts)
      info = AuthorizationInfo.push_parent(info, post, :comments)

      assert info.path == [:users, :posts, :comments]
      assert info.parent == post
      assert info.parents == [user, post]
    end
  end
end
