defmodule GreenFairy.Extensions.AuthTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Extensions.Auth

  defmodule TestUser do
    defstruct [:id, :name, :capabilities]
  end

  describe "CapabilityMiddleware" do
    alias Auth.CapabilityMiddleware

    setup do
      config = %{user_key: :current_user, capability_key: :capabilities}
      {:ok, config: config}
    end

    test "allows access when user has required capability", %{config: config} do
      user = %TestUser{id: 1, capabilities: [:admin, :user]}

      resolution = %Absinthe.Resolution{
        state: :unresolved,
        context: %{current_user: user}
      }

      result = CapabilityMiddleware.call(resolution, {[:admin], "No access", config})
      assert result.state == :unresolved
    end

    test "allows access when user has one of multiple capabilities", %{config: config} do
      user = %TestUser{id: 1, capabilities: [:auditor]}

      resolution = %Absinthe.Resolution{
        state: :unresolved,
        context: %{current_user: user}
      }

      result = CapabilityMiddleware.call(resolution, {[:admin, :auditor], "No access", config})
      assert result.state == :unresolved
    end

    test "denies access when user lacks capability", %{config: config} do
      user = %TestUser{id: 1, capabilities: [:user]}

      resolution = %Absinthe.Resolution{
        state: :unresolved,
        context: %{current_user: user}
      }

      result = CapabilityMiddleware.call(resolution, {[:admin], "No access", config})
      assert result.state == :resolved
      assert result.errors == ["No access"]
    end

    test "denies access when user is nil", %{config: config} do
      resolution = %Absinthe.Resolution{
        state: :unresolved,
        context: %{current_user: nil}
      }

      result = CapabilityMiddleware.call(resolution, {[:admin], "No access", config})
      assert result.state == :resolved
      assert result.errors == ["No access"]
    end

    test "handles capabilities as function", %{config: config} do
      user = %{id: 1, capabilities: fn -> [:admin] end}

      resolution = %Absinthe.Resolution{
        state: :unresolved,
        context: %{current_user: user}
      }

      result = CapabilityMiddleware.call(resolution, {[:admin], "No access", config})
      assert result.state == :unresolved
    end

    test "uses custom capability key", %{config: _config} do
      custom_config = %{user_key: :current_user, capability_key: :roles}
      user = %{id: 1, roles: [:admin]}

      resolution = %Absinthe.Resolution{
        state: :unresolved,
        context: %{current_user: user}
      }

      result = CapabilityMiddleware.call(resolution, {[:admin], "No access", custom_config})
      assert result.state == :unresolved
    end

    test "passes through already resolved", %{config: config} do
      resolution = %Absinthe.Resolution{
        state: :resolved,
        value: "already done"
      }

      result = CapabilityMiddleware.call(resolution, {[:admin], "No access", config})
      assert result.state == :resolved
      assert result.value == "already done"
    end

    test "handles single atom capability", %{config: _config} do
      # When user.capabilities is a single atom (not a list)
      custom_config = %{user_key: :current_user, capability_key: :role}
      user = %{id: 1, role: :admin}

      resolution = %Absinthe.Resolution{
        state: :unresolved,
        context: %{current_user: user}
      }

      result = CapabilityMiddleware.call(resolution, {[:admin], "No access", custom_config})
      assert result.state == :unresolved
    end

    test "handles missing capability key as empty list", %{config: _config} do
      # When the capability key doesn't exist on the user
      custom_config = %{user_key: :current_user, capability_key: :missing_key}
      user = %{id: 1}

      resolution = %Absinthe.Resolution{
        state: :unresolved,
        context: %{current_user: user}
      }

      result = CapabilityMiddleware.call(resolution, {[:admin], "No access", custom_config})
      assert result.state == :resolved
      assert result.errors == ["No access"]
    end
  end

  describe "AuthenticatedMiddleware" do
    alias Auth.AuthenticatedMiddleware

    setup do
      config = %{user_key: :current_user, capability_key: :capabilities}
      {:ok, config: config}
    end

    test "allows access when user is present", %{config: config} do
      user = %TestUser{id: 1}

      resolution = %Absinthe.Resolution{
        state: :unresolved,
        context: %{current_user: user}
      }

      result = AuthenticatedMiddleware.call(resolution, {"Auth required", config})
      assert result.state == :unresolved
    end

    test "denies access when user is nil", %{config: config} do
      resolution = %Absinthe.Resolution{
        state: :unresolved,
        context: %{current_user: nil}
      }

      result = AuthenticatedMiddleware.call(resolution, {"Auth required", config})
      assert result.state == :resolved
      assert result.errors == ["Auth required"]
    end

    test "denies access when user key is missing", %{config: config} do
      resolution = %Absinthe.Resolution{
        state: :unresolved,
        context: %{}
      }

      result = AuthenticatedMiddleware.call(resolution, {"Auth required", config})
      assert result.state == :resolved
      assert result.errors == ["Auth required"]
    end

    test "uses custom user key" do
      custom_config = %{user_key: :viewer, capability_key: :capabilities}
      user = %TestUser{id: 1}

      resolution = %Absinthe.Resolution{
        state: :unresolved,
        context: %{viewer: user}
      }

      result = AuthenticatedMiddleware.call(resolution, {"Auth required", custom_config})
      assert result.state == :unresolved
    end

    test "passes through already resolved", %{config: config} do
      resolution = %Absinthe.Resolution{
        state: :resolved,
        value: "already done"
      }

      result = AuthenticatedMiddleware.call(resolution, {"Auth required", config})
      assert result.state == :resolved
      assert result.value == "already done"
    end
  end

  describe "Extension integration" do
    defmodule SecureUserType do
      use GreenFairy.Type

      type "SecureUser", struct: TestUser do
        use Auth

        field :id, non_null(:id)
        field :name, :string
      end
    end

    test "extension is registered" do
      extensions = SecureUserType.__green_fairy_extensions__()
      assert Auth in extensions
    end

    test "type definition includes extension" do
      definition = SecureUserType.__green_fairy_definition__()
      assert Auth in definition.extensions
    end
  end

  describe "Extension with custom options" do
    defmodule CustomAuthType do
      use GreenFairy.Type

      type "CustomAuthUser" do
        use Auth, capability_key: :roles, user_key: :viewer

        field :id, :id
      end
    end

    test "custom options are applied" do
      # The type compiles without error, meaning the options were accepted
      definition = CustomAuthType.__green_fairy_definition__()
      assert definition.name == "CustomAuthUser"
    end
  end
end
