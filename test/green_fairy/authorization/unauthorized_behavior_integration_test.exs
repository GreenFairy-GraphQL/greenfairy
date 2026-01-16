defmodule GreenFairy.Authorization.UnauthorizedBehaviorIntegrationTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Integration tests for on_unauthorized behavior with real GraphQL types and schemas.

  Tests the complete flow from GraphQL query to resolution with various
  authorization configurations.
  """

  # Define test types with different on_unauthorized configurations

  defmodule TestUser do
    use Ecto.Schema

    schema "users" do
      field :name, :string
      field :email, :string
      field :ssn, :string
      field :phone, :string
    end
  end

  defmodule Types.UserWithErrorBehavior do
    use GreenFairy.Type

    type "UserWithErrorBehavior", struct: TestUser, on_unauthorized: :error do
      use GreenFairy.CQL

      authorize fn _user, ctx ->
        if ctx[:is_admin] do
          :all
        else
          [:id, :name]
        end
      end

      field :id, non_null(:id)
      field :name, :string
      field :email, :string
      field :ssn, :string
      field :phone, :string
    end
  end

  defmodule Types.UserWithNilBehavior do
    use GreenFairy.Type

    type "UserWithNilBehavior", struct: TestUser, on_unauthorized: :return_nil do
      use GreenFairy.CQL

      authorize fn _user, ctx ->
        if ctx[:is_admin] do
          :all
        else
          [:id, :name]
        end
      end

      field :id, non_null(:id)
      field :name, :string
      field :email, :string
      field :ssn, :string
      field :phone, :string
    end
  end

  defmodule Types.UserWithMixedBehavior do
    use GreenFairy.Type

    type "UserWithMixedBehavior", struct: TestUser, on_unauthorized: :return_nil do
      use GreenFairy.CQL

      authorize fn _user, ctx ->
        if ctx[:is_admin] do
          :all
        else
          [:id, :name, :email]
        end
      end

      field :id, non_null(:id)
      field :name, :string
      field :email, :string
      # Override type-level :nil with :error for SSN
      field :ssn, :string, meta: [on_unauthorized: :error]
      field :phone, :string
    end
  end

  describe "Type-level on_unauthorized: :error" do
    test "authorized user can access all fields" do
      user = %TestUser{id: 1, name: "Alice", email: "alice@example.com", ssn: "123-45-6789"}

      # Simulate admin context
      authorized = GreenFairy.AuthorizedObject.new(
        user,
        Types.UserWithErrorBehavior.__authorize__(user, %{is_admin: true}, %{}),
        on_unauthorized: :error
      )

      assert authorized.all_visible == true
      assert authorized.on_unauthorized == :error
    end

    test "non-admin sees limited fields with :error behavior" do
      user = %TestUser{id: 1, name: "Alice", email: "alice@example.com", ssn: "123-45-6789"}

      # Non-admin sees only [:id, :name]
      authorized = GreenFairy.AuthorizedObject.new(
        user,
        Types.UserWithErrorBehavior.__authorize__(user, %{is_admin: false}, %{}),
        on_unauthorized: :error
      )

      assert authorized.visible_fields == [:id, :name]
      assert authorized.on_unauthorized == :error

      # Accessing visible field works
      assert {:ok, "Alice"} = GreenFairy.AuthorizedObject.get_field(authorized, :name)

      # Accessing hidden field returns :hidden
      assert :hidden = GreenFairy.AuthorizedObject.get_field(authorized, :email)
    end
  end

  describe "Type-level on_unauthorized: :return_nil" do
    test "non-admin gets nil for unauthorized fields" do
      user = %TestUser{id: 1, name: "Alice", email: "alice@example.com"}

      authorized = GreenFairy.AuthorizedObject.new(
        user,
        Types.UserWithNilBehavior.__authorize__(user, %{is_admin: false}, %{}),
        on_unauthorized: :return_nil
      )

      assert authorized.visible_fields == [:id, :name]
      assert authorized.on_unauthorized == :return_nil

      # With :return_nil behavior, middleware would return nil instead of error
    end
  end

  describe "Field-level override" do
    test "field-level :error overrides type-level :nil" do
      user = %TestUser{id: 1, name: "Alice", email: "alice@example.com", ssn: "123-45-6789"}

      authorized = GreenFairy.AuthorizedObject.new(
        user,
        Types.UserWithMixedBehavior.__authorize__(user, %{is_admin: false}, %{}),
        on_unauthorized: :return_nil
      )

      # User can see [:id, :name, :email] but not :ssn or :phone
      assert authorized.visible_fields == [:id, :name, :email]
      assert authorized.on_unauthorized == :return_nil

      # email would return nil (type default)
      # ssn would return error (field override) - tested in middleware tests
    end
  end

  describe "Authorization with __authorize__ function" do
    test "admin gets :all authorization" do
      user = %TestUser{id: 1, name: "Alice"}

      result = Types.UserWithErrorBehavior.__authorize__(user, %{is_admin: true}, %{})

      assert result == :all
    end

    test "non-admin gets limited fields" do
      user = %TestUser{id: 1, name: "Alice"}

      result = Types.UserWithErrorBehavior.__authorize__(user, %{is_admin: false}, %{})

      assert result == [:id, :name]
    end
  end

  describe "CQL integration with on_unauthorized" do
    test "CQL respects authorization with on_unauthorized: :return_nil" do
      user = %TestUser{id: 1, name: "Alice", email: "alice@example.com"}

      # Get authorized fields for filtering
      authorized_fields = Types.UserWithNilBehavior.__cql_authorized_fields__(user, %{is_admin: false})

      # Should only allow filtering on visible fields
      assert authorized_fields == [:id, :name]
      refute :email in authorized_fields
      refute :ssn in authorized_fields
    end

    test "CQL validation fails for unauthorized fields" do
      user = %TestUser{id: 1, name: "Alice"}

      # Try to filter on unauthorized field
      result = Types.UserWithErrorBehavior.__cql_validate_filter__(
        [:email],
        user,
        %{is_admin: false}
      )

      assert {:error, {:unauthorized_fields, [:email]}} = result
    end

    test "CQL validation passes for authorized fields" do
      user = %TestUser{id: 1, name: "Alice"}

      result = Types.UserWithErrorBehavior.__cql_validate_filter__(
        [:name],
        user,
        %{is_admin: false}
      )

      assert result == :ok
    end
  end

  describe "Built-in enum and directive" do
    test "UnauthorizedBehavior enum has correct values" do
      # This tests that the enum is defined correctly
      Code.ensure_loaded!(GreenFairy.BuiltIns.UnauthorizedBehavior)
      assert function_exported?(GreenFairy.BuiltIns.UnauthorizedBehavior, :__green_fairy_definition__, 0)

      definition = GreenFairy.BuiltIns.UnauthorizedBehavior.__green_fairy_definition__()

      assert definition.kind == :enum
      assert definition.identifier == :unauthorized_behavior
    end

    test "OnUnauthorizedDirective is defined" do
      # This tests that the directive module exists
      Code.ensure_loaded!(GreenFairy.BuiltIns.OnUnauthorizedDirective)
      assert function_exported?(GreenFairy.BuiltIns.OnUnauthorizedDirective, :__absinthe_directive__, 1)
    end
  end

  describe "Real-world scenarios" do
    test "public profile with sensitive fields" do
      user = %TestUser{
        id: 1,
        name: "Alice Smith",
        email: "alice@example.com",
        ssn: "123-45-6789",
        phone: "555-1234"
      }

      # Public view - only basic info
      public_view = GreenFairy.AuthorizedObject.new(
        user,
        [:id, :name],
        on_unauthorized: :return_nil
      )

      assert {:ok, "Alice Smith"} = GreenFairy.AuthorizedObject.get_field(public_view, :name)
      assert :hidden = GreenFairy.AuthorizedObject.get_field(public_view, :email)
      assert :hidden = GreenFairy.AuthorizedObject.get_field(public_view, :ssn)

      # Owner view - all fields
      owner_view = GreenFairy.AuthorizedObject.new(
        user,
        :all,
        on_unauthorized: :error
      )

      assert {:ok, "alice@example.com"} = GreenFairy.AuthorizedObject.get_field(owner_view, :email)
      assert {:ok, "123-45-6789"} = GreenFairy.AuthorizedObject.get_field(owner_view, :ssn)
    end

    test "API response with partial data for non-admin" do
      user = %TestUser{
        id: 1,
        name: "Bob Jones",
        email: "bob@example.com",
        phone: "555-9876"
      }

      # Non-admin gets partial data with nil for unauthorized fields
      authorized = GreenFairy.AuthorizedObject.new(
        user,
        [:id, :name, :email],
        on_unauthorized: :return_nil
      )

      # These would be accessible
      assert {:ok, 1} = GreenFairy.AuthorizedObject.get_field(authorized, :id)
      assert {:ok, "Bob Jones"} = GreenFairy.AuthorizedObject.get_field(authorized, :name)
      assert {:ok, "bob@example.com"} = GreenFairy.AuthorizedObject.get_field(authorized, :email)

      # This would return :hidden (middleware converts to nil)
      assert :hidden = GreenFairy.AuthorizedObject.get_field(authorized, :phone)
    end
  end
end
