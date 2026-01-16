defmodule GreenFairy.Authorization.UnauthorizedBehaviorTest do
  use ExUnit.Case, async: true

  alias GreenFairy.AuthorizedObject

  @moduledoc """
  Comprehensive tests for the on_unauthorized behavior feature.

  Tests cover:
  - Type-level on_unauthorized configuration
  - Field-level on_unauthorized configuration
  - Client @onUnauthorized directive
  - Priority/precedence of different configurations
  - Integration with AuthorizedObject
  """

  describe "AuthorizedObject with on_unauthorized" do
    test "new/3 with on_unauthorized: :return_nil" do
      user = %{id: 1, name: "Alice", email: "alice@example.com"}
      auth_obj = AuthorizedObject.new(user, [:id, :name], on_unauthorized: :return_nil)

      assert %AuthorizedObject{
               source: ^user,
               visible_fields: [:id, :name],
               all_visible: false,
               on_unauthorized: :return_nil
             } = auth_obj
    end

    test "new/3 with on_unauthorized: :error (default)" do
      user = %{id: 1, name: "Alice"}
      auth_obj = AuthorizedObject.new(user, [:id], on_unauthorized: :error)

      assert %AuthorizedObject{
               on_unauthorized: :error
             } = auth_obj
    end

    test "new/2 defaults to :error when on_unauthorized not specified" do
      user = %{id: 1, name: "Alice"}
      auth_obj = AuthorizedObject.new(user, [:id])

      assert %AuthorizedObject{
               on_unauthorized: :error
             } = auth_obj
    end

    test "new/3 with :all visibility" do
      user = %{id: 1, name: "Alice"}
      auth_obj = AuthorizedObject.new(user, :all, on_unauthorized: :return_nil)

      assert %AuthorizedObject{
               all_visible: true,
               on_unauthorized: :return_nil
             } = auth_obj
    end

    test "new/3 with :none returns nil" do
      user = %{id: 1, name: "Alice"}
      result = AuthorizedObject.new(user, :none, on_unauthorized: :return_nil)

      assert is_nil(result)
    end
  end

  describe "FieldMiddleware behavior resolution" do
    alias GreenFairy.Authorization.FieldMiddleware

    setup do
      # Create test resolution structure
      user = %{id: 1, name: "Alice", email: "alice@example.com", ssn: "123-45-6789"}

      # Authorized object with limited fields
      auth_obj = AuthorizedObject.new(user, [:id, :name], on_unauthorized: :error)

      %{user: user, auth_obj: auth_obj}
    end

    test "accessible field returns value", %{auth_obj: auth_obj} do
      resolution = create_resolution(auth_obj, :name, %{}, %{})

      result = FieldMiddleware.call(resolution, %{})

      assert result.state == :resolved
      assert result.value == "Alice"
      assert result.errors == []
    end

    test "unauthorized field with :error behavior returns error", %{auth_obj: auth_obj} do
      resolution = create_resolution(auth_obj, :email, %{}, %{})

      result = FieldMiddleware.call(resolution, %{})

      assert result.state == :resolved
      assert result.value == nil
      assert length(result.errors) > 0
      assert Enum.any?(result.errors, &String.contains?(&1.message, "Not authorized"))
    end

    test "unauthorized field with :nil behavior returns nil", %{user: user} do
      # Create auth_obj with :nil behavior
      auth_obj = AuthorizedObject.new(user, [:id, :name], on_unauthorized: :return_nil)
      resolution = create_resolution(auth_obj, :email, %{}, %{})

      result = FieldMiddleware.call(resolution, %{})

      assert result.state == :resolved
      assert result.value == nil
      assert result.errors == []
    end

    test "client directive overrides type behavior - directive :nil", %{auth_obj: auth_obj} do
      # auth_obj has :error behavior, but client requests :nil
      field_meta = %{on_unauthorized: :return_nil}
      resolution = create_resolution(auth_obj, :email, field_meta, %{})

      result = FieldMiddleware.call(resolution, %{})

      assert result.state == :resolved
      assert result.value == nil
      assert result.errors == []
    end

    test "client directive overrides type behavior - directive :error", %{user: user} do
      # auth_obj has :nil behavior, but client requests :error
      auth_obj = AuthorizedObject.new(user, [:id], on_unauthorized: :return_nil)
      field_meta = %{on_unauthorized: :error}
      resolution = create_resolution(auth_obj, :email, field_meta, %{})

      result = FieldMiddleware.call(resolution, %{})

      assert result.state == :resolved
      assert length(result.errors) > 0
    end

    test "field-level config overrides type-level config", %{user: user} do
      auth_obj = AuthorizedObject.new(user, [:id], on_unauthorized: :error)
      resolution = create_resolution(auth_obj, :email, %{}, %{})

      # Field config says :nil
      result = FieldMiddleware.call(resolution, %{on_unauthorized: :return_nil})

      assert result.state == :resolved
      assert result.value == nil
      assert result.errors == []
    end

    test "type-level config is used when no field-level config", %{user: user} do
      auth_obj = AuthorizedObject.new(user, [:id], on_unauthorized: :return_nil)
      resolution = create_resolution(auth_obj, :email, %{}, %{})

      result = FieldMiddleware.call(resolution, %{type_on_unauthorized: :return_nil})

      assert result.state == :resolved
      assert result.value == nil
      assert result.errors == []
    end

    test "resolved resolution is passed through unchanged", %{auth_obj: auth_obj} do
      resolution = create_resolution(auth_obj, :name, %{}, %{})
      resolved = %{resolution | state: :resolved, value: "Bob"}

      result = FieldMiddleware.call(resolved, %{})

      assert result == resolved
    end

    test "non-AuthorizedObject source allows all fields", %{user: user} do
      resolution = create_resolution(user, :email, %{}, %{})

      result = FieldMiddleware.call(resolution, %{})

      assert result.state == :resolved
      assert result.value == "alice@example.com"
      assert result.errors == []
    end
  end

  describe "Behavior priority" do
    test "priority: client directive > field config > type config > AuthorizedObject > default" do
      user = %{id: 1, name: "Alice", email: "test@example.com"}

      # Scenario 1: Client directive wins
      auth_obj = AuthorizedObject.new(user, [:id], on_unauthorized: :error)
      field_meta = %{on_unauthorized: :return_nil}
      resolution = create_resolution(auth_obj, :email, field_meta, %{})

      result = GreenFairy.Authorization.FieldMiddleware.call(resolution, %{
        on_unauthorized: :error,
        type_on_unauthorized: :error
      })

      assert result.value == nil
      assert result.errors == []

      # Scenario 2: Field config wins (no directive)
      resolution2 = create_resolution(auth_obj, :email, %{}, %{})

      result2 = GreenFairy.Authorization.FieldMiddleware.call(resolution2, %{
        on_unauthorized: :return_nil,
        type_on_unauthorized: :error
      })

      assert result2.value == nil
      assert result2.errors == []

      # Scenario 3: Type config wins (no directive or field config)
      resolution3 = create_resolution(auth_obj, :email, %{}, %{})

      result3 = GreenFairy.Authorization.FieldMiddleware.call(resolution3, %{
        type_on_unauthorized: :return_nil
      })

      assert result3.value == nil
      assert result3.errors == []
    end
  end

  describe "Edge cases" do
    test "all_visible AuthorizedObject allows all fields" do
      user = %{id: 1, name: "Alice", email: "alice@example.com"}
      auth_obj = AuthorizedObject.new(user, :all, on_unauthorized: :error)

      resolution = create_resolution(auth_obj, :email, %{}, %{})
      result = GreenFairy.Authorization.FieldMiddleware.call(resolution, %{})

      assert result.state == :resolved
      assert result.value == "alice@example.com"
      assert result.errors == []
    end

    test "empty visible_fields list returns nil from new/3" do
      user = %{id: 1}
      result = AuthorizedObject.new(user, [], on_unauthorized: :return_nil)

      assert is_nil(result)
    end

    test "nil source with unauthorized behavior" do
      resolution = create_resolution(nil, :email, %{}, %{})
      result = GreenFairy.Authorization.FieldMiddleware.call(resolution, %{})

      assert result.state == :resolved
      assert length(result.errors) > 0
    end
  end

  # Helper to create a minimal resolution structure
  defp create_resolution(source, field_name, field_meta, context) do
    %{
      state: :unresolved,
      source: source,
      context: context,
      errors: [],
      value: nil,
      definition: %{
        schema_node: %{
          identifier: field_name,
          meta: field_meta
        }
      }
    }
  end
end
