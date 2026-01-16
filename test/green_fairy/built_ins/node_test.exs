defmodule GreenFairy.BuiltIns.NodeTest do
  use ExUnit.Case, async: true

  alias GreenFairy.BuiltIns.Node

  describe "Node interface" do
    test "defines __green_fairy_definition__" do
      definition = Node.__green_fairy_definition__()

      assert definition.kind == :interface
      assert definition.name == "Node"
      assert definition.identifier == :node
    end

    test "defines __green_fairy_identifier__" do
      assert Node.__green_fairy_identifier__() == :node
    end

    test "defines __green_fairy_kind__" do
      assert Node.__green_fairy_kind__() == :interface
    end
  end

  describe "find_type_for_struct/2" do
    defmodule TestStruct do
      defstruct [:id]
    end

    # Register TestStruct with the registry for testing
    GreenFairy.Registry.register(TestStruct, :test_type, Node)

    test "returns identifier when registry has the struct" do
      result = Node.find_type_for_struct(TestStruct, nil)
      assert result == :test_type
    end
  end
end
