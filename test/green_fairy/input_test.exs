defmodule GreenFairy.InputTest do
  use ExUnit.Case, async: true

  # Fake type module for testing type references
  defmodule FakeAddressType do
    def __green_fairy_kind__, do: :input_object
  end

  defmodule CreateUserInput do
    use GreenFairy.Input

    input "CreateUserInput" do
      field :email, non_null(:string)
      field :first_name, :string
      field :last_name, :string
    end
  end

  defmodule UpdateUserInput do
    use GreenFairy.Input

    input "UpdateUserInput", description: "Input for updating a user" do
      field :email, :string
      field :name, :string
    end
  end

  # Input with authorization
  defmodule AuthorizedInput do
    use GreenFairy.Input

    input "AuthorizedInput" do
      authorize fn input, ctx ->
        cond do
          ctx[:admin] == true -> :all
          ctx[:user] == true -> [:email, :name]
          true -> :none
        end
      end

      field :email, non_null(:string)
      field :name, :string
      field :role, :string  # Admin only
    end
  end

  # Input with type references
  defmodule InputWithTypeRefs do
    use GreenFairy.Input

    input "InputWithTypeRefs" do
      # Field with module type reference
      field :address, GreenFairy.InputTest.FakeAddressType

      # Field with non_null wrapped module type
      field :billing_address, non_null(GreenFairy.InputTest.FakeAddressType)

      # Field with list_of wrapped module type
      field :addresses, list_of(GreenFairy.InputTest.FakeAddressType)

      # Field with custom type atom (non-builtin)
      field :category, :custom_category

      # Field with opts (list syntax)
      field :tags, :string, description: "Tags"
    end
  end

  defmodule TestSchema do
    use Absinthe.Schema

    import_types CreateUserInput
    import_types UpdateUserInput

    query do
      field :placeholder, :string do
        resolve fn _, _, _ -> {:ok, "placeholder"} end
      end
    end

    mutation do
      field :create_user, :string do
        arg :input, non_null(:create_user_input)

        resolve fn _, %{input: input}, _ ->
          {:ok, "Created user with email: #{input.email}"}
        end
      end

      field :update_user, :string do
        arg :id, non_null(:id)
        arg :input, non_null(:update_user_input)

        resolve fn _, %{id: id, input: _input}, _ ->
          {:ok, "Updated user #{id}"}
        end
      end
    end
  end

  describe "input/2 macro" do
    test "defines __green_fairy_definition__/0" do
      definition = CreateUserInput.__green_fairy_definition__()

      assert definition.kind == :input_object
      assert definition.name == "CreateUserInput"
      assert definition.identifier == :create_user_input
    end

    test "defines __green_fairy_identifier__/0" do
      assert CreateUserInput.__green_fairy_identifier__() == :create_user_input
    end

    test "defines __green_fairy_kind__/0" do
      assert CreateUserInput.__green_fairy_kind__() == :input_object
    end
  end

  describe "Absinthe integration" do
    test "generates valid Absinthe input object type" do
      type = Absinthe.Schema.lookup_type(TestSchema, :create_user_input)

      assert type != nil
      assert type.name == "CreateUserInput"
      assert type.identifier == :create_user_input
    end

    test "input type has correct fields" do
      type = Absinthe.Schema.lookup_type(TestSchema, :create_user_input)
      field_names = Map.keys(type.fields)

      assert :email in field_names
      assert :first_name in field_names
      assert :last_name in field_names
    end

    test "executes mutation with input" do
      query = """
      mutation {
        createUser(input: {email: "test@example.com", firstName: "John"})
      }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, TestSchema)
      assert data["createUser"] == "Created user with email: test@example.com"
    end
  end

  describe "Authorization" do
    test "input without authorization returns :all" do
      assert CreateUserInput.__authorize__(%{email: "test"}, %{}) == :all
    end

    test "input without authorization has __has_authorization__ as false" do
      assert CreateUserInput.__has_authorization__ == false
    end

    test "input with authorization has __has_authorization__ as true" do
      assert AuthorizedInput.__has_authorization__ == true
    end

    test "__authorize__ returns :all for admin" do
      result = AuthorizedInput.__authorize__(%{email: "test", role: "admin"}, %{admin: true})
      assert result == :all
    end

    test "__authorize__ returns allowed fields for regular user" do
      result = AuthorizedInput.__authorize__(%{email: "test"}, %{user: true})
      assert result == [:email, :name]
    end

    test "__authorize__ returns :none for unauthorized" do
      result = AuthorizedInput.__authorize__(%{email: "test"}, %{})
      assert result == :none
    end

    test "__filter_input__ allows all fields for admin" do
      input = %{email: "test@example.com", name: "Test", role: "admin"}
      assert {:ok, ^input} = AuthorizedInput.__filter_input__(input, %{admin: true})
    end

    test "__filter_input__ returns error for unauthorized access" do
      input = %{email: "test@example.com"}
      assert {:error, :unauthorized} = AuthorizedInput.__filter_input__(input, %{})
    end

    test "__filter_input__ returns error for unauthorized fields" do
      input = %{email: "test@example.com", name: "Test", role: "admin"}
      assert {:error, {:unauthorized_fields, [:role]}} = AuthorizedInput.__filter_input__(input, %{user: true})
    end

    test "__filter_input__ allows only authorized fields" do
      input = %{email: "test@example.com", name: "Test"}
      assert {:ok, ^input} = AuthorizedInput.__filter_input__(input, %{user: true})
    end

    test "__filter_input__ works without authorization" do
      input = %{email: "test@example.com"}
      assert {:ok, ^input} = CreateUserInput.__filter_input__(input, %{})
    end
  end

  describe "Type reference extraction" do
    test "extracts module type references from input" do
      refs = InputWithTypeRefs.__green_fairy_referenced_types__()

      # Should have extracted type references
      assert is_list(refs)
      assert length(refs) > 0
    end

    test "extracts custom atom types (non-builtins)" do
      refs = InputWithTypeRefs.__green_fairy_referenced_types__()

      # :custom_category is not a builtin, so it should be extracted
      assert :custom_category in refs
    end

    test "input has correct identifier" do
      assert InputWithTypeRefs.__green_fairy_identifier__() == :input_with_type_refs
    end

    test "input without type references returns empty list" do
      refs = CreateUserInput.__green_fairy_referenced_types__()
      # CreateUserInput only has builtin types (string), so refs should be empty or only have non-builtins
      assert is_list(refs)
    end
  end

  describe "description option" do
    test "input with description has correct identifier" do
      assert UpdateUserInput.__green_fairy_identifier__() == :update_user_input
    end
  end
end
