defmodule GreenFairy.TypeRegistryTest do
  use ExUnit.Case, async: false

  alias GreenFairy.TypeRegistry

  setup do
    # Clear the registry before each test
    TypeRegistry.clear()
    :ok
  end

  describe "init/0" do
    test "creates the ETS table if it doesn't exist" do
      # First clear by deleting the table if exists
      if :ets.whereis(:green_fairy_type_registry) != :undefined do
        :ets.delete(:green_fairy_type_registry)
      end

      assert TypeRegistry.init() == :ok
      assert :ets.whereis(:green_fairy_type_registry) != :undefined
    end

    test "is idempotent - doesn't fail if table exists" do
      TypeRegistry.init()
      assert TypeRegistry.init() == :ok
    end
  end

  describe "register/2" do
    test "registers an identifier to module mapping" do
      assert TypeRegistry.register(:test_type, FakeModule) == :ok

      assert TypeRegistry.lookup_module(:test_type) == FakeModule
    end

    test "can register multiple types" do
      TypeRegistry.register(:type_a, ModuleA)
      TypeRegistry.register(:type_b, ModuleB)

      assert TypeRegistry.lookup_module(:type_a) == ModuleA
      assert TypeRegistry.lookup_module(:type_b) == ModuleB
    end

    test "overwrites existing registration" do
      TypeRegistry.register(:test_type, OldModule)
      TypeRegistry.register(:test_type, NewModule)

      assert TypeRegistry.lookup_module(:test_type) == NewModule
    end
  end

  describe "lookup_module/1" do
    test "returns module for registered identifier" do
      TypeRegistry.register(:registered_type, RegisteredModule)

      assert TypeRegistry.lookup_module(:registered_type) == RegisteredModule
    end

    test "returns nil for unregistered identifier" do
      assert TypeRegistry.lookup_module(:unregistered_type) == nil
    end

    test "returns nil when table doesn't exist" do
      # Delete the table
      if :ets.whereis(:green_fairy_type_registry) != :undefined do
        :ets.delete(:green_fairy_type_registry)
      end

      assert TypeRegistry.lookup_module(:any_type) == nil
    end
  end

  describe "all/0" do
    test "returns empty list when no registrations" do
      assert TypeRegistry.all() == []
    end

    test "returns all registered types" do
      TypeRegistry.register(:type_a, ModuleA)
      TypeRegistry.register(:type_b, ModuleB)

      all_types = TypeRegistry.all()

      assert {:type_a, ModuleA} in all_types
      assert {:type_b, ModuleB} in all_types
    end

    test "returns empty list when table doesn't exist" do
      # Delete the table
      if :ets.whereis(:green_fairy_type_registry) != :undefined do
        :ets.delete(:green_fairy_type_registry)
      end

      assert TypeRegistry.all() == []
    end
  end

  describe "clear/0" do
    test "removes all registrations" do
      TypeRegistry.register(:type_a, ModuleA)
      TypeRegistry.register(:type_b, ModuleB)

      assert TypeRegistry.clear() == :ok
      assert TypeRegistry.all() == []
    end

    test "returns ok even if table doesn't exist" do
      # Delete the table
      if :ets.whereis(:green_fairy_type_registry) != :undefined do
        :ets.delete(:green_fairy_type_registry)
      end

      assert TypeRegistry.clear() == :ok
    end
  end
end
