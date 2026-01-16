defmodule GreenFairy.SchemaTest do
  use ExUnit.Case, async: false

  # Use the pre-compiled support module for integration tests
  alias GreenFairy.Test.SchemaWithRootsExample

  describe "Schema with explicit root modules" do
    test "schema compiles and can execute queries" do
      assert {:ok, %{data: %{"hello" => "world"}}} =
               Absinthe.run("{ hello }", SchemaWithRootsExample)
    end

    test "schema tracks discovered modules" do
      # Ensure module is loaded before checking function_exported?
      Code.ensure_loaded!(SchemaWithRootsExample)
      assert function_exported?(SchemaWithRootsExample, :__green_fairy_discovered__, 0)
    end
  end

  describe "resolve_type_for/2" do
    defmodule TestStruct do
      defstruct [:id]
    end

    defmodule AnotherStruct do
      defstruct [:id]
    end

    test "returns type for known struct" do
      mapping = %{
        TestStruct => :test_type,
        AnotherStruct => :another_type
      }

      assert :test_type == GreenFairy.Schema.resolve_type_for(%TestStruct{id: 1}, mapping)
      assert :another_type == GreenFairy.Schema.resolve_type_for(%AnotherStruct{id: 2}, mapping)
    end

    test "returns nil for unknown struct" do
      mapping = %{TestStruct => :test_type}

      assert nil == GreenFairy.Schema.resolve_type_for(%AnotherStruct{id: 1}, mapping)
    end

    test "returns nil for non-struct values" do
      mapping = %{TestStruct => :test_type}

      assert nil == GreenFairy.Schema.resolve_type_for("string", mapping)
      assert nil == GreenFairy.Schema.resolve_type_for(123, mapping)
      assert nil == GreenFairy.Schema.resolve_type_for(nil, mapping)
    end

    test "returns nil for plain maps without __struct__" do
      mapping = %{TestStruct => :test_type}

      assert nil == GreenFairy.Schema.resolve_type_for(%{id: 1, name: "test"}, mapping)
    end

    test "handles empty mapping" do
      assert nil == GreenFairy.Schema.resolve_type_for(%TestStruct{id: 1}, %{})
    end
  end

  describe "Schema with inline roots" do
    defmodule InlineRootSchema do
      use GreenFairy.Schema

      root_query do
        field :inline_ping, :string do
          resolve fn _, _, _ -> {:ok, "inline_pong"} end
        end
      end

      root_mutation do
        field :inline_action, :boolean do
          resolve fn _, _, _ -> {:ok, true} end
        end
      end
    end

    test "inline query fields work" do
      assert {:ok, %{data: %{"inlinePing" => "inline_pong"}}} =
               Absinthe.run("{ inlinePing }", InlineRootSchema)
    end

    test "inline mutation fields work" do
      assert {:ok, %{data: %{"inlineAction" => true}}} =
               Absinthe.run("mutation { inlineAction }", InlineRootSchema)
    end
  end

  describe "Schema discovery" do
    test "discovered modules list is accessible" do
      # Access the discovered modules function
      discovered = SchemaWithRootsExample.__green_fairy_discovered__()
      assert is_list(discovered)
    end
  end

  describe "Schema with inline subscription" do
    defmodule InlineSubscriptionSchema do
      use GreenFairy.Schema

      root_query do
        field :sub_ping, :string do
          resolve fn _, _, _ -> {:ok, "sub_pong"} end
        end
      end

      root_subscription do
        field :inline_event, :string do
          config fn _, _ -> {:ok, topic: "events"} end
        end
      end
    end

    test "inline subscription schema compiles" do
      type = Absinthe.Schema.lookup_type(InlineSubscriptionSchema, :subscription)
      assert type != nil
      assert Map.has_key?(type.fields, :inline_event)
    end

    test "query works with subscription schema" do
      assert {:ok, %{data: %{"subPing" => "sub_pong"}}} =
               Absinthe.run("{ subPing }", InlineSubscriptionSchema)
    end
  end

  describe "Schema without explicit types" do
    defmodule EmptyDiscoverySchema do
      use GreenFairy.Schema

      root_query do
        field :empty_ping, :string do
          resolve fn _, _, _ -> {:ok, "empty_pong"} end
        end
      end
    end

    test "schema with empty discovery compiles" do
      assert {:ok, %{data: %{"emptyPing" => "empty_pong"}}} =
               Absinthe.run("{ emptyPing }", EmptyDiscoverySchema)
    end
  end

  describe "resolve_type_for/2 additional edge cases" do
    test "returns nil for tuple value" do
      assert nil == GreenFairy.Schema.resolve_type_for({:ok, "value"}, %{TestStruct => :test_type})
    end

    test "returns nil for list value" do
      assert nil == GreenFairy.Schema.resolve_type_for([1, 2, 3], %{TestStruct => :test_type})
    end

    test "returns nil for atom value" do
      assert nil == GreenFairy.Schema.resolve_type_for(:some_atom, %{TestStruct => :test_type})
    end
  end
end
