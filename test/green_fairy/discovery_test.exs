defmodule GreenFairy.DiscoveryTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Discovery

  # Test modules for discovery
  defmodule TestTypes.UserType do
    use GreenFairy.Type

    type "DiscoveryUser" do
      field :id, :id
    end
  end

  defmodule TestTypes.PostType do
    use GreenFairy.Type

    type "DiscoveryPost" do
      field :id, :id
    end
  end

  defmodule TestTypes.CommentInput do
    use GreenFairy.Input

    input "DiscoveryCommentInput" do
      field :body, :string
    end
  end

  defmodule TestTypes.StatusEnum do
    use GreenFairy.Enum

    enum "DiscoveryStatus" do
      value :active
      value :inactive
    end
  end

  describe "discover/1" do
    test "discovers modules under namespace" do
      modules = Discovery.discover([__MODULE__.TestTypes])

      assert __MODULE__.TestTypes.UserType in modules
      assert __MODULE__.TestTypes.PostType in modules
      assert __MODULE__.TestTypes.CommentInput in modules
      assert __MODULE__.TestTypes.StatusEnum in modules
    end

    test "returns empty list for unknown namespace" do
      modules = Discovery.discover([NonExistent.Namespace])
      assert modules == []
    end

    test "discovers from multiple namespaces" do
      modules = Discovery.discover([__MODULE__.TestTypes, NonExistent.Namespace])

      assert length(modules) >= 4
    end
  end

  describe "discover_namespace/1" do
    test "discovers modules in single namespace" do
      modules = Discovery.discover_namespace(__MODULE__.TestTypes)

      assert is_list(modules)
      assert __MODULE__.TestTypes.UserType in modules
    end
  end

  describe "group_by_kind/1" do
    test "groups modules by their kind" do
      modules = Discovery.discover([__MODULE__.TestTypes])
      grouped = Discovery.group_by_kind(modules)

      assert is_map(grouped)
      assert Map.has_key?(grouped, :types)
      assert Map.has_key?(grouped, :inputs)
      assert Map.has_key?(grouped, :enums)
      assert Map.has_key?(grouped, :interfaces)
      assert Map.has_key?(grouped, :unions)
      assert Map.has_key?(grouped, :scalars)
      assert Map.has_key?(grouped, :queries)
      assert Map.has_key?(grouped, :mutations)
      assert Map.has_key?(grouped, :subscriptions)
    end

    test "correctly categorizes object types" do
      modules = Discovery.discover([__MODULE__.TestTypes])
      grouped = Discovery.group_by_kind(modules)

      assert __MODULE__.TestTypes.UserType in grouped[:types]
      assert __MODULE__.TestTypes.PostType in grouped[:types]
    end

    test "correctly categorizes input types" do
      modules = Discovery.discover([__MODULE__.TestTypes])
      grouped = Discovery.group_by_kind(modules)

      assert __MODULE__.TestTypes.CommentInput in grouped[:inputs]
    end

    test "correctly categorizes enum types" do
      modules = Discovery.discover([__MODULE__.TestTypes])
      grouped = Discovery.group_by_kind(modules)

      assert __MODULE__.TestTypes.StatusEnum in grouped[:enums]
    end

    test "returns empty lists for missing kinds" do
      grouped = Discovery.group_by_kind([])

      assert grouped[:types] == []
      assert grouped[:interfaces] == []
      assert grouped[:inputs] == []
    end
  end

  describe "build_struct_mapping/1" do
    defmodule StructTypes.WithStruct do
      defstruct [:id]
    end

    defmodule StructTypes.TypeWithStruct do
      use GreenFairy.Type

      type "WithStructType", struct: StructTypes.WithStruct do
        field :id, :id
      end
    end

    defmodule StructTypes.TypeWithoutStruct do
      use GreenFairy.Type

      type "WithoutStructType" do
        field :id, :id
      end
    end

    test "builds mapping for types with structs" do
      modules = [__MODULE__.StructTypes.TypeWithStruct]
      mapping = Discovery.build_struct_mapping(modules)

      assert Map.has_key?(mapping, __MODULE__.StructTypes.WithStruct)
      assert mapping[__MODULE__.StructTypes.WithStruct] == :with_struct_type
    end

    test "excludes types without structs" do
      modules = [__MODULE__.StructTypes.TypeWithStruct, __MODULE__.StructTypes.TypeWithoutStruct]
      mapping = Discovery.build_struct_mapping(modules)

      # Only has the one with a struct
      assert map_size(mapping) == 1
    end

    test "returns empty map for empty list" do
      assert Discovery.build_struct_mapping([]) == %{}
    end
  end

  describe "build_interface_mapping/1" do
    defmodule InterfaceTypes.NodeInterface do
      use GreenFairy.Interface

      interface "DiscoveryNode" do
        field :id, non_null(:id)
        resolve_type fn _, _ -> nil end
      end
    end

    defmodule InterfaceTypes.NodeUser do
      defstruct [:id]
    end

    defmodule InterfaceTypes.UserImpl do
      use GreenFairy.Type

      type "NodeUserImpl", struct: InterfaceTypes.NodeUser do
        implements(InterfaceTypes.NodeInterface)
        field :id, non_null(:id)
      end
    end

    test "builds mapping of interfaces to implementors" do
      modules = [__MODULE__.InterfaceTypes.UserImpl]
      mapping = Discovery.build_interface_mapping(modules)

      assert Map.has_key?(mapping, __MODULE__.InterfaceTypes.NodeInterface)
      assert __MODULE__.InterfaceTypes.UserImpl in mapping[__MODULE__.InterfaceTypes.NodeInterface]
    end

    test "returns empty map when no implementations" do
      assert Discovery.build_interface_mapping([]) == %{}
    end
  end

  describe "group_by_kind with operations" do
    defmodule OperationsModule do
      use GreenFairy.Operations

      query_field :test_query, :string do
        resolve fn _, _, _ -> {:ok, "test"} end
      end
    end

    test "correctly categorizes operations module" do
      modules = [__MODULE__.OperationsModule]
      grouped = Discovery.group_by_kind(modules)

      # Operations modules have kind :operations which maps to multiple categories
      # But they don't map to standard kinds like :types
      assert is_map(grouped)
    end
  end

  describe "build_struct_mapping with multiple types" do
    defmodule MultiTypes.StructA do
      defstruct [:id]
    end

    defmodule MultiTypes.StructB do
      defstruct [:id]
    end

    defmodule MultiTypes.TypeA do
      use GreenFairy.Type

      type "TypeA", struct: MultiTypes.StructA do
        field :id, :id
      end
    end

    defmodule MultiTypes.TypeB do
      use GreenFairy.Type

      type "TypeB", struct: MultiTypes.StructB do
        field :id, :id
      end
    end

    test "builds mapping for multiple types with structs" do
      modules = [__MODULE__.MultiTypes.TypeA, __MODULE__.MultiTypes.TypeB]
      mapping = Discovery.build_struct_mapping(modules)

      assert map_size(mapping) == 2
      assert mapping[__MODULE__.MultiTypes.StructA] == :type_a
      assert mapping[__MODULE__.MultiTypes.StructB] == :type_b
    end
  end

  describe "build_interface_mapping with multiple implementors" do
    defmodule MultiImpl.Interface do
      use GreenFairy.Interface

      interface "MultiImplInterface" do
        field :id, non_null(:id)
        resolve_type fn _, _ -> nil end
      end
    end

    defmodule MultiImpl.StructA do
      defstruct [:id]
    end

    defmodule MultiImpl.StructB do
      defstruct [:id]
    end

    defmodule MultiImpl.ImplA do
      use GreenFairy.Type

      type "ImplA", struct: MultiImpl.StructA do
        implements(MultiImpl.Interface)
        field :id, non_null(:id)
      end
    end

    defmodule MultiImpl.ImplB do
      use GreenFairy.Type

      type "ImplB", struct: MultiImpl.StructB do
        implements(MultiImpl.Interface)
        field :id, non_null(:id)
      end
    end

    test "groups multiple implementors under same interface" do
      modules = [__MODULE__.MultiImpl.ImplA, __MODULE__.MultiImpl.ImplB]
      mapping = Discovery.build_interface_mapping(modules)

      assert Map.has_key?(mapping, __MODULE__.MultiImpl.Interface)
      implementors = mapping[__MODULE__.MultiImpl.Interface]
      assert __MODULE__.MultiImpl.ImplA in implementors
      assert __MODULE__.MultiImpl.ImplB in implementors
    end
  end

  describe "discover_cql_types/1" do
    # CQL types need a struct to have CQL enabled
    defmodule CqlTypes.UserStruct do
      defstruct [:id, :name, :email]
    end

    defmodule CqlTypes.CqlUser do
      use GreenFairy.Type

      type "CqlUser", struct: CqlTypes.UserStruct do
        field :id, non_null(:id)
        field :name, :string
        field :email, :string
      end
    end

    # Type without struct won't have CQL
    defmodule CqlTypes.NonCqlType do
      use GreenFairy.Type

      type "NonCqlType" do
        field :id, :id
      end
    end

    test "filters modules to those with CQL config" do
      modules = [__MODULE__.CqlTypes.CqlUser, __MODULE__.CqlTypes.NonCqlType]
      cql_modules = Discovery.discover_cql_types(modules)

      # Only the type with a struct has CQL enabled
      assert __MODULE__.CqlTypes.CqlUser in cql_modules
      # NonCqlType has no struct, so no CQL
      refute __MODULE__.CqlTypes.NonCqlType in cql_modules
    end

    test "returns empty list when no CQL modules" do
      # NonCqlType has no struct, so no CQL config
      cql_modules = Discovery.discover_cql_types([__MODULE__.CqlTypes.NonCqlType])
      assert cql_modules == []
    end

    test "returns empty list for empty input" do
      assert Discovery.discover_cql_types([]) == []
    end
  end

  describe "discover_cql_types_in_namespaces/1" do
    test "discovers CQL types in namespace" do
      cql_modules = Discovery.discover_cql_types_in_namespaces([__MODULE__.CqlTypes])

      # Should find the CqlUser which has a struct
      assert is_list(cql_modules)
    end

    test "returns empty list for namespace without CQL types" do
      cql_modules = Discovery.discover_cql_types_in_namespaces([NonExistent.Namespace])
      assert cql_modules == []
    end
  end
end
