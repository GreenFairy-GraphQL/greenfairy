defmodule Absinthe.Object.Relay.GlobalIdTest do
  use ExUnit.Case, async: true

  alias Absinthe.Object.Relay.GlobalId

  describe "encode/2" do
    test "encodes string type name and integer ID" do
      result = GlobalId.encode("User", 123)
      assert is_binary(result)
      assert {:ok, {"User", "123"}} = GlobalId.decode(result)
    end

    test "encodes string type name and string ID" do
      result = GlobalId.encode("User", "abc-123")
      assert {:ok, {"User", "abc-123"}} = GlobalId.decode(result)
    end

    test "encodes atom type name (converts to PascalCase)" do
      result = GlobalId.encode(:user, 123)
      assert {:ok, {"User", "123"}} = GlobalId.decode(result)
    end

    test "encodes snake_case atom to PascalCase" do
      result = GlobalId.encode(:user_profile, 42)
      assert {:ok, {"UserProfile", "42"}} = GlobalId.decode(result)
    end

    test "handles UUID-style IDs" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      result = GlobalId.encode("Post", uuid)
      assert {:ok, {"Post", ^uuid}} = GlobalId.decode(result)
    end
  end

  describe "decode/1" do
    test "decodes valid global ID" do
      global_id = Base.encode64("User:123")
      assert {:ok, {"User", "123"}} = GlobalId.decode(global_id)
    end

    test "returns error for invalid base64" do
      assert {:error, :invalid_global_id} = GlobalId.decode("not-base64!!!")
    end

    test "returns error for base64 without colon" do
      global_id = Base.encode64("UserWithoutId")
      assert {:error, :invalid_global_id} = GlobalId.decode(global_id)
    end

    test "returns error for non-string input" do
      assert {:error, :invalid_global_id} = GlobalId.decode(123)
      assert {:error, :invalid_global_id} = GlobalId.decode(nil)
    end

    test "handles IDs containing colons" do
      global_id = Base.encode64("Namespace:type:with:colons")
      assert {:ok, {"Namespace", "type:with:colons"}} = GlobalId.decode(global_id)
    end
  end

  describe "decode!/1" do
    test "returns tuple for valid global ID" do
      global_id = Base.encode64("User:123")
      assert {"User", "123"} = GlobalId.decode!(global_id)
    end

    test "raises for invalid global ID" do
      assert_raise ArgumentError, ~r/Invalid global ID/, fn ->
        GlobalId.decode!("invalid")
      end
    end
  end

  describe "type/1" do
    test "extracts type name from global ID" do
      global_id = Base.encode64("User:123")
      assert {:ok, "User"} = GlobalId.type(global_id)
    end

    test "returns error for invalid global ID" do
      assert {:error, :invalid_global_id} = GlobalId.type("invalid")
    end
  end

  describe "local_id/1" do
    test "extracts local ID from global ID" do
      global_id = Base.encode64("User:123")
      assert {:ok, "123"} = GlobalId.local_id(global_id)
    end

    test "returns error for invalid global ID" do
      assert {:error, :invalid_global_id} = GlobalId.local_id("invalid")
    end
  end

  describe "decode_id/1" do
    test "parses integer local IDs" do
      global_id = Base.encode64("User:123")
      assert {:ok, {"User", 123}} = GlobalId.decode_id(global_id)
    end

    test "keeps string local IDs as strings" do
      global_id = Base.encode64("User:abc-123")
      assert {:ok, {"User", "abc-123"}} = GlobalId.decode_id(global_id)
    end

    test "returns error for invalid global ID" do
      assert {:error, :invalid_global_id} = GlobalId.decode_id("invalid")
    end
  end

  describe "round-trip encoding" do
    test "encode then decode returns original values" do
      types_and_ids = [
        {"User", 1},
        {"Post", "abc-123"},
        {"Comment", 999_999},
        {:user_profile, 42},
        {:organization_member, "member-id"}
      ]

      for {type, id} <- types_and_ids do
        encoded = GlobalId.encode(type, id)
        {:ok, {decoded_type, decoded_id}} = GlobalId.decode(encoded)

        expected_type =
          if is_atom(type) do
            type
            |> Atom.to_string()
            |> String.split("_")
            |> Enum.map(&String.capitalize/1)
            |> Enum.join()
          else
            type
          end

        assert decoded_type == expected_type
        assert decoded_id == to_string(id)
      end
    end
  end
end
