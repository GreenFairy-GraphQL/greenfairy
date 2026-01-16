defmodule GreenFairy.TypeExtendedTest do
  use ExUnit.Case, async: true

  describe "Type with various field configurations" do
    defmodule TypeTestStruct do
      defstruct [:id, :name, :email, :age]
    end

    defmodule FullFeaturedType do
      use GreenFairy.Type

      type "FullFeatured", struct: TypeTestStruct, description: "A fully featured type" do
        field :id, non_null(:id)
        field :name, :string
        field :email, non_null(:string)

        field :computed_name, :string do
          resolve fn parent, _, _ -> {:ok, "Computed: #{parent.name}"} end
        end

        field :age, :integer
      end
    end

    test "stores struct in definition" do
      definition = FullFeaturedType.__green_fairy_definition__()
      assert definition.struct == TypeTestStruct
    end

    test "stores identifier" do
      assert FullFeaturedType.__green_fairy_identifier__() == :full_featured
    end

    test "stores kind" do
      assert FullFeaturedType.__green_fairy_kind__() == :object
    end

    test "returns struct from __green_fairy_struct__" do
      assert FullFeaturedType.__green_fairy_struct__() == TypeTestStruct
    end

    test "definition includes name" do
      definition = FullFeaturedType.__green_fairy_definition__()
      assert definition.name == "FullFeatured"
    end

    test "definition includes kind" do
      definition = FullFeaturedType.__green_fairy_definition__()
      assert definition.kind == :object
    end
  end

  describe "Type without struct" do
    defmodule NoStructType do
      use GreenFairy.Type

      type "NoStruct" do
        field :id, :id
        field :data, :string
      end
    end

    test "struct is nil in definition" do
      definition = NoStructType.__green_fairy_definition__()
      assert definition.struct == nil
    end

    test "__green_fairy_struct__ returns nil" do
      assert NoStructType.__green_fairy_struct__() == nil
    end
  end

  describe "Type with interface implementation" do
    defmodule TestInterface do
      use GreenFairy.Interface

      interface "TestInterfaceForType" do
        field :id, non_null(:id)
        resolve_type fn _, _ -> nil end
      end
    end

    defmodule TestInterfaceStruct do
      defstruct [:id, :name]
    end

    defmodule TypeWithInterface do
      use GreenFairy.Type

      type "TypeWithInterface", struct: TestInterfaceStruct do
        implements(TestInterface)
        field :id, non_null(:id)
        field :name, :string
      end
    end

    test "interfaces are tracked in definition" do
      definition = TypeWithInterface.__green_fairy_definition__()
      assert TestInterface in definition.interfaces
    end
  end

  describe "Type in schema context" do
    defmodule TypeTestSchema do
      use Absinthe.Schema

      import_types GreenFairy.TypeExtendedTest.FullFeaturedType

      query do
        field :item, :full_featured do
          resolve fn _, _, _ ->
            {:ok, %{id: "1", name: "Test", email: "test@example.com", age: 25}}
          end
        end
      end
    end

    test "type is available in schema" do
      type = Absinthe.Schema.lookup_type(TypeTestSchema, :full_featured)
      assert type != nil
      assert type.name == "FullFeatured"
    end

    test "can query type fields" do
      query = """
      {
        item {
          id
          name
          email
          age
        }
      }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, TypeTestSchema)
      assert data["item"]["id"] == "1"
      assert data["item"]["name"] == "Test"
      assert data["item"]["email"] == "test@example.com"
      assert data["item"]["age"] == 25
    end

    test "computed fields work" do
      query = "{ item { computedName } }"

      assert {:ok, %{data: data}} = Absinthe.run(query, TypeTestSchema)
      assert data["item"]["computedName"] == "Computed: Test"
    end
  end

  describe "Multiple types with same interface" do
    defmodule CommonInterface do
      use GreenFairy.Interface

      interface "CommonInterface" do
        field :id, non_null(:id)
        resolve_type fn _, _ -> nil end
      end
    end

    defmodule TypeAStruct do
      defstruct [:id]
    end

    defmodule TypeBStruct do
      defstruct [:id]
    end

    defmodule TypeA do
      use GreenFairy.Type

      type "TypeAForMulti", struct: TypeAStruct do
        implements(CommonInterface)
        field :id, non_null(:id)
        field :a_field, :string
      end
    end

    defmodule TypeB do
      use GreenFairy.Type

      type "TypeBForMulti", struct: TypeBStruct do
        implements(CommonInterface)
        field :id, non_null(:id)
        field :b_field, :string
      end
    end

    test "TypeA implements CommonInterface" do
      definition = TypeA.__green_fairy_definition__()
      assert CommonInterface in definition.interfaces
    end

    test "TypeB implements CommonInterface" do
      definition = TypeB.__green_fairy_definition__()
      assert CommonInterface in definition.interfaces
    end
  end

  describe "Type with function-based authorization (2-arity)" do
    defmodule AuthStruct do
      defstruct [:id, :name, :secret]
    end

    defmodule AuthType do
      use GreenFairy.Type

      type "AuthType", struct: AuthStruct do
        authorize fn object, ctx ->
          cond do
            ctx[:admin] == true -> :all
            ctx[:user_id] == object.id -> :all
            true -> [:id, :name]
          end
        end

        field :id, non_null(:id)
        field :name, :string
        field :secret, :string
      end
    end

    test "__has_authorization__ returns true" do
      assert AuthType.__has_authorization__ == true
    end

    test "__authorize__ returns :all for admin" do
      object = %AuthStruct{id: "1", name: "Test", secret: "secret"}
      ctx = %{admin: true}
      result = AuthType.__authorize__(object, ctx, %{})

      assert result == :all
    end

    test "__authorize__ returns :all for owner" do
      object = %AuthStruct{id: "1", name: "Test", secret: "secret"}
      ctx = %{user_id: "1"}
      result = AuthType.__authorize__(object, ctx, %{})

      assert result == :all
    end

    test "__authorize__ returns limited fields for non-owner" do
      object = %AuthStruct{id: "1", name: "Test", secret: "secret"}
      ctx = %{user_id: "2"}
      result = AuthType.__authorize__(object, ctx, %{})

      assert result == [:id, :name]
    end
  end

  describe "Type with function-based authorization (3-arity)" do
    defmodule Auth3Struct do
      defstruct [:id, :data]
    end

    defmodule Auth3Type do
      use GreenFairy.Type

      type "Auth3Type", struct: Auth3Struct do
        authorize fn _object, ctx, info ->
          if ctx[:admin] || info[:path] == [:admin_query] do
            :all
          else
            :none
          end
        end

        field :id, non_null(:id)
        field :data, :string
      end
    end

    test "__has_authorization__ returns true" do
      assert Auth3Type.__has_authorization__ == true
    end

    test "__authorize__ receives info parameter" do
      object = %Auth3Struct{id: "1", data: "sensitive"}
      ctx = %{}
      info = %{path: [:admin_query]}
      result = Auth3Type.__authorize__(object, ctx, info)

      assert result == :all
    end

    test "__authorize__ returns :none for non-admin path" do
      object = %Auth3Struct{id: "1", data: "sensitive"}
      ctx = %{}
      info = %{path: [:user_query]}
      result = Auth3Type.__authorize__(object, ctx, info)

      assert result == :none
    end
  end

  describe "Type without authorization" do
    defmodule NoAuthStruct do
      defstruct [:id]
    end

    defmodule NoAuthType do
      use GreenFairy.Type

      type "NoAuthType", struct: NoAuthStruct do
        field :id, non_null(:id)
      end
    end

    test "__has_authorization__ returns false" do
      assert NoAuthType.__has_authorization__ == false
    end

    test "__authorize__ returns :all" do
      result = NoAuthType.__authorize__(%{}, %{}, %{})
      assert result == :all
    end
  end

  describe "Type with referenced types tracking" do
    defmodule RefTarget do
      use GreenFairy.Type

      type "RefTarget" do
        field :id, non_null(:id)
      end
    end

    defmodule TypeWithRefs do
      use GreenFairy.Type

      type "TypeWithRefs" do
        field :id, non_null(:id)
        # Reference to another type
        field :target, :ref_target
        # Reference via non_null wrapper
        field :non_null_target, non_null(:ref_target)
        # Reference via list_of wrapper
        field :targets, list_of(:ref_target)
      end
    end

    test "tracks referenced types" do
      refs = TypeWithRefs.__green_fairy_referenced_types__()

      assert is_list(refs)
      assert :ref_target in refs
    end
  end

  describe "Type policy" do
    defmodule PolicyStruct do
      defstruct [:id]
    end

    defmodule PolicyType do
      use GreenFairy.Type

      type "PolicyType", struct: PolicyStruct do
        field :id, non_null(:id)
      end
    end

    test "__green_fairy_policy__ returns nil when no policy" do
      assert PolicyType.__green_fairy_policy__() == nil
    end
  end

  describe "Type extensions" do
    defmodule ExtStruct do
      defstruct [:id]
    end

    defmodule ExtType do
      use GreenFairy.Type

      type "ExtType", struct: ExtStruct do
        field :id, non_null(:id)
      end
    end

    test "__green_fairy_extensions__ returns empty list when no extensions" do
      assert ExtType.__green_fairy_extensions__() == []
    end
  end

  describe "Type with field options" do
    defmodule FieldOptsType do
      use GreenFairy.Type

      type "FieldOptsType" do
        field :id, non_null(:id)
        field :name, :string, description: "The name"
        field :list_field, list_of(:string)
        field :nullable_list, list_of(:string)
      end
    end

    test "tracks fields with options" do
      definition = FieldOptsType.__green_fairy_definition__()
      field_names = Enum.map(definition.fields, & &1.name)

      assert :id in field_names
      assert :name in field_names
      assert :list_field in field_names
    end
  end

  describe "Type with fields with resolver and opts" do
    defmodule ResolverOptsType do
      use GreenFairy.Type

      type "ResolverOptsType" do
        field :id, non_null(:id)

        field :computed, :string, description: "A computed field" do
          resolve fn _, _, _ -> {:ok, "computed"} end
        end
      end
    end

    test "tracks field with resolver" do
      definition = ResolverOptsType.__green_fairy_definition__()
      computed_field = Enum.find(definition.fields, &(&1.name == :computed))

      assert computed_field.resolver == true
    end
  end
end
