defmodule GreenFairy.TypeTest do
  use ExUnit.Case, async: true

  defmodule TestUser do
    defstruct [:id, :email, :first_name, :last_name]
  end

  defmodule NodeInterface do
    use GreenFairy.Interface

    interface "Node" do
      field :id, non_null(:id)

      resolve_type fn
        %TestUser{}, _ -> :user
        _, _ -> nil
      end
    end
  end

  defmodule UserType do
    use GreenFairy.Type

    type "User", struct: TestUser do
      implements(NodeInterface)

      field :id, non_null(:id)
      field :email, non_null(:string)
      field :first_name, :string
      field :last_name, :string

      field :full_name, :string do
        resolve fn user, _, _ ->
          {:ok, "#{user.first_name} #{user.last_name}"}
        end
      end
    end
  end

  defmodule TestSchema do
    use Absinthe.Schema

    import_types NodeInterface
    import_types UserType

    query do
      field :user, :user do
        arg :id, non_null(:id)

        resolve fn _, %{id: id}, _ ->
          {:ok, %TestUser{id: id, email: "test@example.com", first_name: "John", last_name: "Doe"}}
        end
      end

      field :node, :node do
        arg :id, non_null(:id)

        resolve fn _, %{id: id}, _ ->
          {:ok, %TestUser{id: id, email: "test@example.com", first_name: "Jane", last_name: "Smith"}}
        end
      end
    end
  end

  describe "type/2 macro" do
    test "defines __green_fairy_definition__/0" do
      definition = UserType.__green_fairy_definition__()

      assert definition.kind == :object
      assert definition.name == "User"
      assert definition.identifier == :user
      assert definition.struct == TestUser
    end

    test "defines __green_fairy_identifier__/0" do
      assert UserType.__green_fairy_identifier__() == :user
    end

    test "defines __green_fairy_struct__/0" do
      assert UserType.__green_fairy_struct__() == TestUser
    end

    test "defines __green_fairy_kind__/0" do
      assert UserType.__green_fairy_kind__() == :object
    end

    test "records implemented interfaces" do
      definition = UserType.__green_fairy_definition__()
      assert NodeInterface in definition.interfaces
    end

    test "records field definitions" do
      definition = UserType.__green_fairy_definition__()
      field_names = Enum.map(definition.fields, & &1.name)

      assert :id in field_names
      assert :email in field_names
      assert :first_name in field_names
      assert :last_name in field_names
      assert :full_name in field_names
    end
  end

  describe "field/2-3 macro" do
    test "stores field type and options" do
      definition = UserType.__green_fairy_definition__()
      email_field = Enum.find(definition.fields, &(&1.name == :email))

      assert email_field.type == :string
      assert email_field.opts[:null] == false
    end

    test "supports fields with resolver blocks" do
      definition = UserType.__green_fairy_definition__()
      full_name_field = Enum.find(definition.fields, &(&1.name == :full_name))

      assert full_name_field.type == :string
      assert full_name_field.resolver == true
    end
  end

  describe "Absinthe integration" do
    test "generates valid Absinthe type" do
      type = Absinthe.Schema.lookup_type(TestSchema, :user)

      assert type != nil
      assert type.name == "User"
      assert type.identifier == :user
    end

    test "type has correct fields" do
      type = Absinthe.Schema.lookup_type(TestSchema, :user)
      field_names = Map.keys(type.fields)

      assert :id in field_names
      assert :email in field_names
      assert :first_name in field_names
      assert :full_name in field_names
    end

    test "type implements interface" do
      type = Absinthe.Schema.lookup_type(TestSchema, :user)
      assert :node in type.interfaces
    end

    test "executes basic query" do
      query = """
      {
        user(id: "123") {
          id
          email
          firstName
          lastName
        }
      }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, TestSchema)
      assert data["user"]["id"] == "123"
      assert data["user"]["email"] == "test@example.com"
      assert data["user"]["firstName"] == "John"
      assert data["user"]["lastName"] == "Doe"
    end

    test "executes query with computed field" do
      query = """
      {
        user(id: "123") {
          fullName
        }
      }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, TestSchema)
      assert data["user"]["fullName"] == "John Doe"
    end

    test "executes interface query" do
      query = """
      {
        node(id: "456") {
          id
          ... on User {
            email
            fullName
          }
        }
      }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, TestSchema)
      assert data["node"]["id"] == "456"
      assert data["node"]["email"] == "test@example.com"
      assert data["node"]["fullName"] == "Jane Smith"
    end
  end

  # Modules for relationship macro tests - Order matters! Referenced modules must be defined first.
  defmodule PostType do
    use GreenFairy.Type

    type "Post" do
      field :id, non_null(:id)
      field :title, :string
    end
  end

  defmodule CommentType do
    use GreenFairy.Type

    type "Comment" do
      field :id, non_null(:id)
      field :body, :string
    end
  end

  defmodule ProfileType do
    use GreenFairy.Type

    type "Profile" do
      field :id, non_null(:id)
      field :bio, :string
    end
  end

  defmodule OrganizationType do
    use GreenFairy.Type

    type "Organization" do
      field :id, non_null(:id)
      field :name, :string
    end
  end

  defmodule AuthorType do
    use GreenFairy.Type

    type "Author" do
      field :id, non_null(:id)
      field :name, :string

      # Association fields - adapter provides default DataLoader resolution
      field :posts, list_of(:post)
      field :profile, :profile
      field :organization, :organization
    end
  end

  defmodule RelationshipSchema do
    use Absinthe.Schema

    import_types PostType
    import_types CommentType
    import_types ProfileType
    import_types AuthorType
    import_types OrganizationType

    query do
      field :author, :author do
        resolve fn _, _, _ -> {:ok, %{id: "1", name: "Test Author"}} end
      end
    end
  end

  describe "association fields" do
    test "list_of field for has-many relationships" do
      type = Absinthe.Schema.lookup_type(RelationshipSchema, :author)
      assert Map.has_key?(type.fields, :posts)
      posts_field = type.fields[:posts]
      assert posts_field != nil
    end

    test "singular field for has-one relationships" do
      type = Absinthe.Schema.lookup_type(RelationshipSchema, :author)
      assert Map.has_key?(type.fields, :profile)
      profile_field = type.fields[:profile]
      assert profile_field != nil
    end

    test "singular field for belongs-to relationships" do
      type = Absinthe.Schema.lookup_type(RelationshipSchema, :author)
      assert Map.has_key?(type.fields, :organization)
      org_field = type.fields[:organization]
      assert org_field != nil
    end

    test "schema can be queried for author fields" do
      query = """
      {
        author {
          id
          name
        }
      }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, RelationshipSchema)
      assert data["author"]["id"] == "1"
      assert data["author"]["name"] == "Test Author"
    end
  end

  # Test type without struct
  defmodule SimpleType do
    use GreenFairy.Type

    type "Simple" do
      field :id, :id
      field :value, :string
    end
  end

  describe "type without struct" do
    test "defines __green_fairy_struct__ as nil" do
      assert SimpleType.__green_fairy_struct__() == nil
    end

    test "definition has nil struct" do
      definition = SimpleType.__green_fairy_definition__()
      assert definition.struct == nil
    end

    test "definition has empty interfaces" do
      definition = SimpleType.__green_fairy_definition__()
      assert definition.interfaces == []
    end
  end

  # Test single statement block
  defmodule SingleFieldType do
    use GreenFairy.Type

    type "SingleField" do
      field :only_field, :string
    end
  end

  describe "type with single statement block" do
    test "correctly transforms single statement" do
      type = SimpleType.__green_fairy_definition__()
      assert type.kind == :object
    end
  end

  # Test authorization with function
  defmodule TypeWithAuthFn do
    use GreenFairy.Type

    type "TypeWithAuth", struct: TestUser do
      authorize fn object, ctx ->
        if ctx[:admin] do
          :all
        else
          [:id, :email]
        end
      end

      field :id, non_null(:id)
      field :email, :string
      field :ssn, :string
    end
  end

  describe "function-based authorization" do
    test "__has_authorization__ returns true for types with authorize fn" do
      assert TypeWithAuthFn.__has_authorization__ == true
    end

    test "__authorize__ returns :all for admin context" do
      result = TypeWithAuthFn.__authorize__(%TestUser{id: "1"}, %{admin: true}, %{})
      assert result == :all
    end

    test "__authorize__ returns limited fields for non-admin" do
      result = TypeWithAuthFn.__authorize__(%TestUser{id: "1"}, %{}, %{})
      assert result == [:id, :email]
    end
  end

  # Test authorization with 3-arity function
  defmodule TypeWithAuth3Arity do
    use GreenFairy.Type

    type "TypeWith3ArityAuth" do
      authorize fn object, ctx, info ->
        if info[:path] == [:query, :user] do
          :all
        else
          [:id]
        end
      end

      field :id, non_null(:id)
      field :secret, :string
    end
  end

  describe "3-arity authorization function" do
    test "__authorize__ receives info argument" do
      result = TypeWithAuth3Arity.__authorize__(%{}, %{}, %{path: [:query, :user]})
      assert result == :all
    end

    test "__authorize__ returns limited fields when path doesn't match" do
      result = TypeWithAuth3Arity.__authorize__(%{}, %{}, %{path: [:other]})
      assert result == [:id]
    end
  end

  # Type without authorization
  defmodule TypeWithoutAuth do
    use GreenFairy.Type

    type "TypeWithoutAuth" do
      field :id, :id
    end
  end

  describe "type without authorization" do
    test "__has_authorization__ returns false" do
      assert TypeWithoutAuth.__has_authorization__ == false
    end

    test "__authorize__ returns :all" do
      result = TypeWithoutAuth.__authorize__(%{}, %{}, %{})
      assert result == :all
    end
  end

  # Type with legacy policy authorization
  defmodule TestPolicy do
    def can?(%{admin: true}, :view, _object), do: true
    def can?(nil, :view, _object), do: false
    def can?(_user, :view, _object), do: true
  end

  defmodule TypeWithPolicy do
    use GreenFairy.Type

    type "TypeWithPolicy" do
      authorize with: GreenFairy.TypeTest.TestPolicy

      field :id, :id
      field :name, :string
    end
  end

  describe "policy-based authorization" do
    test "__has_authorization__ returns true" do
      assert TypeWithPolicy.__has_authorization__ == true
    end

    test "__authorize__ returns :all when policy allows" do
      result = TypeWithPolicy.__authorize__(%{}, %{current_user: %{admin: true}}, %{})
      assert result == :all
    end

    test "__authorize__ returns :none when policy denies" do
      result = TypeWithPolicy.__authorize__(%{}, %{current_user: nil}, %{})
      assert result == :none
    end

    test "__green_fairy_policy__ returns the policy module" do
      assert TypeWithPolicy.__green_fairy_policy__() == GreenFairy.TypeTest.TestPolicy
    end
  end

  describe "extension support" do
    test "__green_fairy_extensions__ returns empty list for type without extensions" do
      assert SimpleType.__green_fairy_extensions__() == []
    end
  end

  describe "referenced types" do
    test "__green_fairy_referenced_types__ returns referenced types" do
      refs = UserType.__green_fairy_referenced_types__()
      assert is_list(refs)
      # UserType implements NodeInterface, so it should be referenced
      assert NodeInterface in refs
    end

    test "__green_fairy_referenced_types__ returns empty for type without refs" do
      refs = SimpleType.__green_fairy_referenced_types__()
      assert is_list(refs)
    end
  end

  # Type with description option
  defmodule TypeWithDescription do
    use GreenFairy.Type

    type "DescribedType", description: "A type with a description" do
      field :id, :id
    end
  end

  describe "type with description" do
    test "identifier is correct for type with description" do
      assert TypeWithDescription.__green_fairy_identifier__() == :described_type
    end
  end

  # Test field parsing with different argument formats
  defmodule TypeWithVariousFields do
    use GreenFairy.Type

    type "VariousFields" do
      # Field with non_null type
      field :required_field, non_null(:string)

      # Field with list type
      field :list_field, list_of(:string)

      # Field with nested wrapped types
      field :nested_list, non_null(list_of(:string))

      # Field with options
      field :described_field, :string, description: "Has a description"

      # Field with custom resolver
      field :computed_field, :string do
        resolve fn _, _, _ -> {:ok, "computed"} end
      end
    end
  end

  describe "field parsing variations" do
    test "handles non_null wrapped type" do
      definition = TypeWithVariousFields.__green_fairy_definition__()
      req_field = Enum.find(definition.fields, &(&1.name == :required_field))
      assert req_field != nil
      assert req_field.type == :string
      assert req_field.opts[:null] == false
    end

    test "handles list_of wrapped type" do
      definition = TypeWithVariousFields.__green_fairy_definition__()
      list_field = Enum.find(definition.fields, &(&1.name == :list_field))
      assert list_field != nil
      assert list_field.type == :string
      assert list_field.opts[:list] == true
    end

    test "handles nested wrapped types" do
      definition = TypeWithVariousFields.__green_fairy_definition__()
      nested_field = Enum.find(definition.fields, &(&1.name == :nested_list))
      assert nested_field != nil
      assert nested_field.type == :string
    end

    test "handles field with options" do
      definition = TypeWithVariousFields.__green_fairy_definition__()
      desc_field = Enum.find(definition.fields, &(&1.name == :described_field))
      assert desc_field != nil
      assert desc_field.opts[:description] == "Has a description"
    end

    test "handles field with resolver block" do
      definition = TypeWithVariousFields.__green_fairy_definition__()
      computed_field = Enum.find(definition.fields, &(&1.name == :computed_field))
      assert computed_field != nil
      assert computed_field.resolver == true
    end
  end
end
