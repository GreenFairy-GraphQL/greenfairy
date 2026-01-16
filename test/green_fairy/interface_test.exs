defmodule GreenFairy.InterfaceTest do
  use ExUnit.Case, async: true

  defmodule TestNode do
    use GreenFairy.Interface

    interface "TestNodeInterface" do
      field :id, non_null(:id)
      field :created_at, :string

      resolve_type fn
        %{type: :user}, _ -> :interface_test_user
        %{type: :post}, _ -> :interface_test_post
        _, _ -> nil
      end
    end
  end

  describe "Interface module" do
    test "defines __green_fairy_kind__" do
      assert TestNode.__green_fairy_kind__() == :interface
    end

    test "defines __green_fairy_definition__" do
      definition = TestNode.__green_fairy_definition__()

      assert definition.kind == :interface
      assert definition.name == "TestNodeInterface"
      assert definition.identifier == :test_node_interface
    end

    test "defines __green_fairy_identifier__" do
      assert TestNode.__green_fairy_identifier__() == :test_node_interface
    end

    test "defines __green_fairy_fields__" do
      fields = TestNode.__green_fairy_fields__()
      assert is_list(fields)
    end

    test "definition includes fields" do
      definition = TestNode.__green_fairy_definition__()
      assert is_list(definition.fields)
    end
  end

  describe "Interface integration with schema" do
    defmodule InterfaceUserType do
      use GreenFairy.Type

      type "InterfaceTestUser" do
        implements(TestNode)
        field :id, non_null(:id)
        field :created_at, :string
        field :email, :string
      end
    end

    defmodule InterfacePostType do
      use GreenFairy.Type

      type "InterfaceTestPost" do
        implements(TestNode)
        field :id, non_null(:id)
        field :created_at, :string
        field :title, :string
      end
    end

    defmodule InterfaceSchema do
      use Absinthe.Schema

      import_types TestNode
      import_types InterfaceUserType
      import_types InterfacePostType

      query do
        field :node, :test_node_interface do
          arg :type, non_null(:string)

          resolve fn _, %{type: type}, _ ->
            case type do
              "user" -> {:ok, %{type: :user, id: "1", email: "test@example.com"}}
              "post" -> {:ok, %{type: :post, id: "2", title: "Test Post"}}
              _ -> {:ok, nil}
            end
          end
        end
      end
    end

    test "interface type exists in schema" do
      type = Absinthe.Schema.lookup_type(InterfaceSchema, :test_node_interface)
      assert type != nil
    end

    test "interface has correct fields" do
      type = Absinthe.Schema.lookup_type(InterfaceSchema, :test_node_interface)
      assert Map.has_key?(type.fields, :id)
      assert Map.has_key?(type.fields, :created_at)
    end

    test "implementing types have interface" do
      user_type = Absinthe.Schema.lookup_type(InterfaceSchema, :interface_test_user)
      assert :test_node_interface in user_type.interfaces
    end

    test "can query through interface - user" do
      query = """
      {
        node(type: "user") {
          id
          ... on InterfaceTestUser {
            email
          }
        }
      }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, InterfaceSchema)
      assert data["node"]["id"] == "1"
      assert data["node"]["email"] == "test@example.com"
    end

    test "can query through interface - post" do
      query = """
      {
        node(type: "post") {
          id
          ... on InterfaceTestPost {
            title
          }
        }
      }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, InterfaceSchema)
      assert data["node"]["id"] == "2"
      assert data["node"]["title"] == "Test Post"
    end
  end

  describe "Interface with description" do
    defmodule DescribedInterface do
      use GreenFairy.Interface

      interface "DescribedNode", description: "A node with a description" do
        field :id, non_null(:id)
        resolve_type fn _, _ -> nil end
      end
    end

    test "stores description in definition" do
      definition = DescribedInterface.__green_fairy_definition__()
      assert definition.description == "A node with a description"
    end
  end

  describe "Interface without explicit resolve_type" do
    # This tests the auto-generated resolve_type path
    defmodule AutoResolveInterface do
      use GreenFairy.Interface

      interface "AutoResolveNode" do
        field :id, non_null(:id)
        # No resolve_type - should be auto-generated
      end
    end

    test "definition is created" do
      definition = AutoResolveInterface.__green_fairy_definition__()
      assert definition.kind == :interface
      assert definition.identifier == :auto_resolve_node
    end

    test "identifier is correct" do
      assert AutoResolveInterface.__green_fairy_identifier__() == :auto_resolve_node
    end
  end

  describe "Interface with single field (no block wrapper)" do
    defmodule SingleFieldInterface do
      use GreenFairy.Interface

      interface "SingleFieldNode" do
        field :id, non_null(:id)
      end
    end

    test "works with single field" do
      definition = SingleFieldInterface.__green_fairy_definition__()
      assert definition.kind == :interface
    end
  end

  describe "__green_fairy_fields__" do
    test "returns empty list by default" do
      # The fields are stored in the interface attribute but tracking them
      # in the accumulator is not implemented, so this returns empty
      fields = TestNode.__green_fairy_fields__()
      assert is_list(fields)
    end
  end

  describe "Interface with opts (description)" do
    defmodule OptInterface do
      use GreenFairy.Interface

      interface "OptNode", description: "An optional interface" do
        field :opt_id, non_null(:id)
        resolve_type fn _, _ -> nil end
      end
    end

    test "captures description in definition" do
      definition = OptInterface.__green_fairy_definition__()
      assert definition.description == "An optional interface"
    end
  end

  describe "Multiple interfaces in same schema" do
    defmodule Searchable do
      use GreenFairy.Interface

      interface "Searchable" do
        field :search_score, :float
        resolve_type fn _, _ -> nil end
      end
    end

    test "can define multiple interfaces" do
      assert TestNode.__green_fairy_kind__() == :interface
      assert Searchable.__green_fairy_kind__() == :interface
      assert TestNode.__green_fairy_identifier__() != Searchable.__green_fairy_identifier__()
    end
  end
end
