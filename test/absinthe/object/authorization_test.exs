defmodule Absinthe.Object.AuthorizationTest do
  use ExUnit.Case, async: true

  defmodule TestPolicy do
    @moduledoc "Test policy for authorization"

    def can?(nil, _action, _resource), do: false

    def can?(%{id: user_id}, :owner_only, %{user_id: owner_id}) do
      user_id == owner_id
    end

    def can?(%{role: :admin}, :admin_only, _resource), do: true
    def can?(_, :admin_only, _resource), do: false

    def can?(_user, :view, _resource), do: true

    def can?(_, _, _), do: false
  end

  defmodule TestStruct do
    defstruct [:id, :user_id, :email, :name]
  end

  defmodule AuthorizedType do
    use Absinthe.Object.Type

    type "AuthorizedUser", struct: TestStruct do
      authorize(with: TestPolicy)

      field :id, non_null(:id)
      field :name, :string
      field :email, :string
    end
  end

  describe "authorize macro" do
    test "type stores policy in definition" do
      definition = AuthorizedType.__absinthe_object_definition__()
      assert definition.policy == TestPolicy
    end

    test "__absinthe_object_policy__ returns policy module" do
      assert AuthorizedType.__absinthe_object_policy__() == TestPolicy
    end
  end

  describe "Authorization.Middleware" do
    alias Absinthe.Object.Authorization.Middleware

    test "allows access when policy returns true" do
      resolution = %Absinthe.Resolution{
        state: :unresolved,
        source: %TestStruct{id: 1, user_id: 1},
        context: %{current_user: %{id: 1}}
      }

      result = Middleware.call(resolution, {:owner_only, TestPolicy, nil})
      assert result.state == :unresolved
    end

    test "denies access when policy returns false" do
      resolution = %Absinthe.Resolution{
        state: :unresolved,
        source: %TestStruct{id: 1, user_id: 1},
        context: %{current_user: %{id: 999}}
      }

      result = Middleware.call(resolution, {:owner_only, TestPolicy, nil})
      assert result.state == :resolved
      assert result.value == nil
    end

    test "uses default value when unauthorized" do
      resolution = %Absinthe.Resolution{
        state: :unresolved,
        source: %TestStruct{id: 1, user_id: 1},
        context: %{current_user: nil}
      }

      result = Middleware.call(resolution, {:owner_only, TestPolicy, "[REDACTED]"})
      assert result.state == :resolved
      assert result.value == "[REDACTED]"
    end

    test "admin can access admin_only fields" do
      resolution = %Absinthe.Resolution{
        state: :unresolved,
        source: %TestStruct{id: 1, user_id: 1},
        context: %{current_user: %{id: 1, role: :admin}}
      }

      result = Middleware.call(resolution, {:admin_only, TestPolicy, nil})
      assert result.state == :unresolved
    end

    test "non-admin cannot access admin_only fields" do
      resolution = %Absinthe.Resolution{
        state: :unresolved,
        source: %TestStruct{id: 1, user_id: 1},
        context: %{current_user: %{id: 1, role: :user}}
      }

      result = Middleware.call(resolution, {:admin_only, TestPolicy, nil})
      assert result.state == :resolved
      assert result.value == nil
    end
  end

  describe "Authorization module" do
    alias Absinthe.Object.Authorization

    test "middleware/3 creates middleware tuple" do
      result = Authorization.middleware(:view, TestPolicy, default_on_unauthorized: "hidden")
      assert {Absinthe.Object.Authorization.Middleware, {:view, TestPolicy, "hidden"}} = result
    end

    test "authorized?/3 returns true when no action specified" do
      assert Authorization.authorized?(%{}, %{}, %{})
    end

    test "authorized?/3 returns true when no policy specified" do
      assert Authorization.authorized?(%{authorize: :view}, %{}, %{})
    end

    test "authorized?/3 checks policy when both specified" do
      config = %{authorize: :view, authorize_with: TestPolicy}
      resource = %TestStruct{}
      context = %{current_user: %{id: 1}}

      assert Authorization.authorized?(config, resource, context)
    end
  end
end
