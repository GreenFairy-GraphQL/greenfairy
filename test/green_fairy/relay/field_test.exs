defmodule GreenFairy.Relay.FieldTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Relay.Field

  describe "get_type_name/2" do
    defmodule TypeWithTypeName do
      def __green_fairy_type_name__, do: "CustomTypeName"
    end

    defmodule TypeWithoutTypeName do
      # No __green_fairy_type_name__ function
    end

    test "returns type name from module when available" do
      assert "CustomTypeName" = Field.get_type_name(TypeWithTypeName, nil)
    end

    test "falls back to module name when no type name function" do
      result = Field.get_type_name(TypeWithoutTypeName, nil)
      assert result == "TypeWithoutTypeName"
    end

    test "uses resolution definition when available" do
      resolution = %{
        definition: %{
          schema_node: %{
            identifier: :my_type
          }
        }
      }

      result = Field.get_type_name(TypeWithoutTypeName, resolution)
      assert result == "MyType"
    end

    test "falls back to module name when resolution has no definition" do
      # Resolution exists but has no definition
      resolution = %{definition: nil}

      result = Field.get_type_name(TypeWithoutTypeName, resolution)
      assert result == "TypeWithoutTypeName"
    end

    test "falls back to module name when resolution is nil" do
      result = Field.get_type_name(TypeWithoutTypeName, nil)
      assert result == "TypeWithoutTypeName"
    end

    test "extracts last part of deeply nested module name" do
      defmodule My.Deeply.Nested.ModuleName do
        # No __green_fairy_type_name__ function
      end

      result = Field.get_type_name(My.Deeply.Nested.ModuleName, nil)
      assert result == "ModuleName"
    end
  end
end
