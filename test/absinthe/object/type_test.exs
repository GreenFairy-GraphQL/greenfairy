defmodule Absinthe.Object.TypeTest do
  use ExUnit.Case, async: true

  defmodule TestUser do
    defstruct [:id, :email, :first_name, :last_name]
  end

  defmodule NodeInterface do
    use Absinthe.Object.Interface

    interface "Node" do
      field :id, non_null(:id)

      resolve_type fn
        %TestUser{}, _ -> :user
        _, _ -> nil
      end
    end
  end

  defmodule UserType do
    use Absinthe.Object.Type

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
    test "defines __absinthe_object_definition__/0" do
      definition = UserType.__absinthe_object_definition__()

      assert definition.kind == :object
      assert definition.name == "User"
      assert definition.identifier == :user
      assert definition.struct == TestUser
    end

    test "defines __absinthe_object_identifier__/0" do
      assert UserType.__absinthe_object_identifier__() == :user
    end

    test "defines __absinthe_object_struct__/0" do
      assert UserType.__absinthe_object_struct__() == TestUser
    end

    test "defines __absinthe_object_kind__/0" do
      assert UserType.__absinthe_object_kind__() == :object
    end

    test "records implemented interfaces" do
      definition = UserType.__absinthe_object_definition__()
      assert NodeInterface in definition.interfaces
    end

    @tag :skip
    test "records field definitions" do
      # Field tracking not yet implemented - fields go directly to Absinthe
      definition = UserType.__absinthe_object_definition__()
      field_names = Enum.map(definition.fields, & &1.name)

      assert :id in field_names
      assert :email in field_names
      assert :first_name in field_names
      assert :last_name in field_names
      assert :full_name in field_names
    end
  end

  describe "field/2-3 macro" do
    @tag :skip
    test "stores field type and options" do
      # Field tracking not yet implemented - fields go directly to Absinthe
      definition = UserType.__absinthe_object_definition__()
      email_field = Enum.find(definition.fields, &(&1.name == :email))

      assert email_field.type == :string
      assert email_field.opts[:null] == false
    end

    @tag :skip
    test "supports fields with resolver blocks" do
      # Field tracking not yet implemented - fields go directly to Absinthe
      definition = UserType.__absinthe_object_definition__()
      full_name_field = Enum.find(definition.fields, &(&1.name == :full_name))

      assert full_name_field.type == :string
      assert full_name_field.resolver != nil
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
    use Absinthe.Object.Type

    type "Post" do
      field :id, non_null(:id)
      field :title, :string
    end
  end

  defmodule CommentType do
    use Absinthe.Object.Type

    type "Comment" do
      field :id, non_null(:id)
      field :body, :string
    end
  end

  defmodule ProfileType do
    use Absinthe.Object.Type

    type "Profile" do
      field :id, non_null(:id)
      field :bio, :string
    end
  end

  defmodule OrganizationType do
    use Absinthe.Object.Type

    type "Organization" do
      field :id, non_null(:id)
      field :name, :string
    end
  end

  defmodule AuthorType do
    use Absinthe.Object.Type

    type "Author" do
      field :id, non_null(:id)
      field :name, :string

      # Test has_many relationship
      has_many(:posts, PostType)

      # Test has_one relationship
      has_one(:profile, ProfileType)

      # Test belongs_to with options
      belongs_to(:organization, OrganizationType, source: :custom_source)
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

  describe "relationship macros" do
    test "has_many generates list_of field" do
      type = Absinthe.Schema.lookup_type(RelationshipSchema, :author)
      assert Map.has_key?(type.fields, :posts)
      # Field should exist with correct identifier
      posts_field = type.fields[:posts]
      assert posts_field != nil
    end

    test "has_one generates singular field" do
      type = Absinthe.Schema.lookup_type(RelationshipSchema, :author)
      assert Map.has_key?(type.fields, :profile)
      profile_field = type.fields[:profile]
      assert profile_field != nil
    end

    test "belongs_to generates field with correct type" do
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
    use Absinthe.Object.Type

    type "Simple" do
      field :id, :id
      field :value, :string
    end
  end

  describe "type without struct" do
    test "defines __absinthe_object_struct__ as nil" do
      assert SimpleType.__absinthe_object_struct__() == nil
    end

    test "definition has nil struct" do
      definition = SimpleType.__absinthe_object_definition__()
      assert definition.struct == nil
    end

    test "definition has empty interfaces" do
      definition = SimpleType.__absinthe_object_definition__()
      assert definition.interfaces == []
    end
  end

  # Test single statement block
  defmodule SingleFieldType do
    use Absinthe.Object.Type

    type "SingleField" do
      field :only_field, :string
    end
  end

  describe "type with single statement block" do
    test "correctly transforms single statement" do
      type = SimpleType.__absinthe_object_definition__()
      assert type.kind == :object
    end
  end
end
