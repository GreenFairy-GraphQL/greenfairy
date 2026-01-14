defmodule Absinthe.Object.Relay.NodeTest do
  use ExUnit.Case, async: true

  alias Absinthe.Object.Relay.{GlobalId, Node}

  describe "resolve_node/3" do
    test "returns error for invalid global ID" do
      resolution = %{schema: TestSchema, context: %{}}

      assert {:error, "Invalid global ID format"} =
               Node.resolve_node("not-a-valid-id", resolution, [])
    end

    test "returns error for malformed base64" do
      resolution = %{schema: TestSchema, context: %{}}

      assert {:error, "Invalid global ID format"} =
               Node.resolve_node("!!!invalid!!!", resolution, [])
    end

    test "returns error for unknown type" do
      # Create a valid global ID for an unknown type
      global_id = GlobalId.encode("UnknownType", "123")
      resolution = %{schema: __MODULE__.NodeTestSchema, context: %{}}

      assert {:error, "Unknown type in global ID"} =
               Node.resolve_node(global_id, resolution, [])
    end

    test "returns type not found for type without module" do
      # The schema has a :string type, but it has no __absinthe_object_module__
      global_id = GlobalId.encode("String", "123")
      resolution = %{schema: __MODULE__.NodeTestSchema, context: %{}}

      # String type exists but doesn't have our module attached
      assert {:error, "Unknown type in global ID"} =
               Node.resolve_node(global_id, resolution, [])
    end

    test "empty global ID returns error" do
      resolution = %{schema: __MODULE__.NodeTestSchema, context: %{}}

      assert {:error, "Invalid global ID format"} =
               Node.resolve_node("", resolution, [])
    end
  end

  # Define test schema module
  defmodule NodeTestSchema do
    use Absinthe.Schema

    query do
      field :placeholder, :string do
        resolve fn _, _, _ -> {:ok, "ok"} end
      end
    end
  end
end
