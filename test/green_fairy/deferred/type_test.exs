defmodule GreenFairy.Deferred.TypeTest do
  use ExUnit.Case, async: true

  describe "object/2 macro" do
    defmodule BasicType do
      use GreenFairy.Deferred.Type

      object "BasicType" do
        field :id, non_null(:id)
        field :name, :string
      end
    end

    test "defines __green_fairy_definition__" do
      definition = BasicType.__green_fairy_definition__()

      assert definition.name == "BasicType"
      assert definition.identifier == :basic_type
      assert length(definition.fields) == 2
    end

    test "defines __green_fairy_kind__" do
      assert BasicType.__green_fairy_kind__() == :object
    end

    test "defines __green_fairy_identifier__" do
      assert BasicType.__green_fairy_identifier__() == :basic_type
    end

    test "defines __green_fairy_struct__ as nil when no struct" do
      assert BasicType.__green_fairy_struct__() == nil
    end
  end

  describe "object/2 with struct option" do
    defmodule TestStruct do
      defstruct [:id, :name, :email]
    end

    defmodule TypeWithStruct do
      use GreenFairy.Deferred.Type

      object "TypeWithStruct", struct: TestStruct do
        field :id, non_null(:id)
        field :name, :string
        field :email, :string
      end
    end

    test "__green_fairy_struct__ returns struct module" do
      assert TypeWithStruct.__green_fairy_struct__() == TestStruct
    end

    test "definition includes struct" do
      definition = TypeWithStruct.__green_fairy_definition__()
      assert definition.struct == TestStruct
    end
  end

  describe "object/2 with description" do
    defmodule TypeWithDesc do
      use GreenFairy.Deferred.Type

      object "TypeWithDesc", description: "A type with description" do
        field :id, non_null(:id)
      end
    end

    test "definition includes description" do
      definition = TypeWithDesc.__green_fairy_definition__()
      assert definition.description == "A type with description"
    end
  end

  describe "field/2 macro" do
    defmodule TypeWithFields do
      use GreenFairy.Deferred.Type

      object "TypeWithFields" do
        field :id, non_null(:id)
        field :name, :string, description: "The name"
        field :email, non_null(:string), null: false
        field :deprecated_field, :string, deprecation_reason: "Use other_field"
      end
    end

    test "tracks all fields" do
      definition = TypeWithFields.__green_fairy_definition__()
      field_names = Enum.map(definition.fields, & &1.name)

      assert :id in field_names
      assert :name in field_names
      assert :email in field_names
      assert :deprecated_field in field_names
    end

    test "captures field description" do
      definition = TypeWithFields.__green_fairy_definition__()
      name_field = Enum.find(definition.fields, &(&1.name == :name))

      assert name_field.description == "The name"
    end

    test "captures deprecation reason" do
      definition = TypeWithFields.__green_fairy_definition__()
      deprecated = Enum.find(definition.fields, &(&1.name == :deprecated_field))

      assert deprecated.deprecation_reason == "Use other_field"
    end
  end

  describe "has_many/2 macro" do
    defmodule PostType do
      use GreenFairy.Deferred.Type

      object "Post" do
        field :id, non_null(:id)
      end
    end

    defmodule UserWithPosts do
      use GreenFairy.Deferred.Type

      object "UserWithPosts" do
        field :id, non_null(:id)
        has_many :posts, GreenFairy.Deferred.TypeTest.PostType
      end
    end

    test "creates list field type" do
      definition = UserWithPosts.__green_fairy_definition__()
      posts_field = Enum.find(definition.fields, &(&1.name == :posts))

      assert {:list, {:module, GreenFairy.Deferred.TypeTest.PostType}} = posts_field.type
    end

    test "sets dataloader resolve" do
      definition = UserWithPosts.__green_fairy_definition__()
      posts_field = Enum.find(definition.fields, &(&1.name == :posts))

      assert {:dataloader, GreenFairy.Deferred.TypeTest.PostType, :posts, _opts} = posts_field.resolve
    end
  end

  describe "has_one/2 macro" do
    defmodule ProfileType do
      use GreenFairy.Deferred.Type

      object "Profile" do
        field :id, non_null(:id)
        field :bio, :string
      end
    end

    defmodule UserWithProfile do
      use GreenFairy.Deferred.Type

      object "UserWithProfile" do
        field :id, non_null(:id)
        has_one :profile, GreenFairy.Deferred.TypeTest.ProfileType
      end
    end

    test "creates module field type" do
      definition = UserWithProfile.__green_fairy_definition__()
      profile_field = Enum.find(definition.fields, &(&1.name == :profile))

      assert {:module, GreenFairy.Deferred.TypeTest.ProfileType} = profile_field.type
    end

    test "sets dataloader resolve" do
      definition = UserWithProfile.__green_fairy_definition__()
      profile_field = Enum.find(definition.fields, &(&1.name == :profile))

      assert {:dataloader, GreenFairy.Deferred.TypeTest.ProfileType, :profile, _opts} = profile_field.resolve
    end
  end

  describe "belongs_to/2 macro" do
    defmodule OrgType do
      use GreenFairy.Deferred.Type

      object "Organization" do
        field :id, non_null(:id)
        field :name, :string
      end
    end

    defmodule UserWithOrg do
      use GreenFairy.Deferred.Type

      object "UserWithOrg" do
        field :id, non_null(:id)
        belongs_to :organization, GreenFairy.Deferred.TypeTest.OrgType
      end
    end

    test "creates module field type" do
      definition = UserWithOrg.__green_fairy_definition__()
      org_field = Enum.find(definition.fields, &(&1.name == :organization))

      assert {:module, GreenFairy.Deferred.TypeTest.OrgType} = org_field.type
    end

    test "sets dataloader resolve" do
      definition = UserWithOrg.__green_fairy_definition__()
      org_field = Enum.find(definition.fields, &(&1.name == :organization))

      assert {:dataloader, GreenFairy.Deferred.TypeTest.OrgType, :organization, _opts} = org_field.resolve
    end
  end

  describe "implements/1 macro" do
    defmodule TestInterface do
      use GreenFairy.Deferred.Interface

      interface "TestInterface" do
        field :id, non_null(:id)
      end
    end

    defmodule TypeWithInterface do
      use GreenFairy.Deferred.Type

      object "TypeWithInterface" do
        implements GreenFairy.Deferred.TypeTest.TestInterface
        field :id, non_null(:id)
        field :name, :string
      end
    end

    test "tracks interface implementation" do
      definition = TypeWithInterface.__green_fairy_definition__()

      assert GreenFairy.Deferred.TypeTest.TestInterface in definition.interfaces
    end
  end

  describe "connection/2 macro" do
    defmodule ItemType do
      use GreenFairy.Deferred.Type

      object "Item" do
        field :id, non_null(:id)
      end
    end

    defmodule TypeWithConnection do
      use GreenFairy.Deferred.Type

      object "TypeWithConnection" do
        field :id, non_null(:id)
        connection :items, GreenFairy.Deferred.TypeTest.ItemType
      end
    end

    test "tracks connection definition" do
      definition = TypeWithConnection.__green_fairy_definition__()

      assert length(definition.connections) == 1
      conn = hd(definition.connections)
      assert conn.field_name == :items
      assert conn.node_type == GreenFairy.Deferred.TypeTest.ItemType
    end
  end

  describe "connection/3 with options" do
    defmodule TypeWithConnectionOpts do
      use GreenFairy.Deferred.Type

      object "TypeWithConnectionOpts" do
        field :id, non_null(:id)

        connection :items, GreenFairy.Deferred.TypeTest.ItemType,
          edge_fields: [extra: :string],
          connection_fields: [total_count: :integer]
      end
    end

    test "captures edge_fields option" do
      definition = TypeWithConnectionOpts.__green_fairy_definition__()
      conn = hd(definition.connections)

      assert conn.edge_fields == [extra: :string]
    end

    test "captures connection_fields option" do
      definition = TypeWithConnectionOpts.__green_fairy_definition__()
      conn = hd(definition.connections)

      assert conn.connection_fields == [total_count: :integer]
    end
  end

  describe "@desc attribute" do
    defmodule TypeWithDescAttr do
      use GreenFairy.Deferred.Type

      @desc "A type defined with @desc attribute"
      object "TypeWithDescAttr" do
        @desc "The unique identifier"
        field :id, non_null(:id)

        @desc "The user's name"
        field :name, :string
      end
    end

    test "captures @desc for object" do
      definition = TypeWithDescAttr.__green_fairy_definition__()
      assert definition.description == "A type defined with @desc attribute"
    end

    test "captures @desc for fields" do
      definition = TypeWithDescAttr.__green_fairy_definition__()
      id_field = Enum.find(definition.fields, &(&1.name == :id))
      name_field = Enum.find(definition.fields, &(&1.name == :name))

      assert id_field.description == "The unique identifier"
      assert name_field.description == "The user's name"
    end
  end
end
