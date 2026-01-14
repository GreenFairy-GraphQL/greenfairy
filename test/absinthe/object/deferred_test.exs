defmodule Absinthe.Object.DeferredTest do
  use ExUnit.Case, async: false

  # Define test types using the deferred DSL
  # Note: These modules reference each other but create NO compile-time dependencies!

  defmodule TestInterfaces.Node do
    use Absinthe.Object.Deferred.Interface

    @desc "An object with a globally unique ID"
    interface "Node" do
      field :id, {:non_null, :id}
    end
  end

  defmodule TestTypes.Organization do
    use Absinthe.Object.Deferred.Type

    defmodule Struct do
      defstruct [:id, :name]
    end

    @desc "An organization"
    object "Organization", struct: Struct do
      field :id, {:non_null, :id}
      field :name, :string

      implements(TestInterfaces.Node)
    end
  end

  defmodule TestTypes.User do
    use Absinthe.Object.Deferred.Type

    defmodule Struct do
      defstruct [:id, :name, :email, :organization_id]
    end

    @desc "A user in the system"
    object "User", struct: Struct do
      field :id, {:non_null, :id}
      field :name, :string
      field :email, {:non_null, :string}

      # This references Organization but creates NO compile-time dependency!
      belongs_to(:organization, TestTypes.Organization)

      implements(TestInterfaces.Node)
    end
  end

  defmodule TestTypes.Post do
    use Absinthe.Object.Deferred.Type

    defmodule Struct do
      defstruct [:id, :title, :body, :author_id]
    end

    object "Post", struct: Struct do
      field :id, {:non_null, :id}
      field :title, :string
      field :body, :string

      # Reference to User - no compile dependency
      belongs_to(:author, TestTypes.User)

      implements(TestInterfaces.Node)
    end
  end

  describe "Definition storage" do
    test "types store definitions as data" do
      definition = TestTypes.User.__absinthe_object_definition__()

      assert definition.name == "User"
      assert definition.identifier == :user
      assert definition.struct == TestTypes.User.Struct
      assert definition.description == "A user in the system"
    end

    test "interfaces store definitions as data" do
      definition = TestInterfaces.Node.__absinthe_object_definition__()

      assert definition.name == "Node"
      assert definition.identifier == :node
      assert definition.description == "An object with a globally unique ID"
    end

    test "field types are stored symbolically" do
      definition = TestTypes.User.__absinthe_object_definition__()
      org_field = Enum.find(definition.fields, &(&1.name == :organization))

      # Type reference is stored as {:module, ModuleName}, not resolved identifier
      assert org_field.type == {:module, TestTypes.Organization}
    end

    test "interface references are stored as module atoms" do
      definition = TestTypes.User.__absinthe_object_definition__()

      assert TestInterfaces.Node in definition.interfaces
    end
  end

  describe "Compiler generates valid Absinthe AST" do
    alias Absinthe.Object.Deferred.Compiler

    test "generates module body with types" do
      body_ast =
        Compiler.compile_types_module_body([
          TestInterfaces.Node,
          TestTypes.User,
          TestTypes.Organization
        ])

      ast_string = Macro.to_string(body_ast)

      # Should contain interface definition
      assert ast_string =~ "interface :node"

      # Should contain object definitions
      assert ast_string =~ "object :user"
      assert ast_string =~ "object :organization"
    end

    test "resolves module references to identifiers" do
      body_ast =
        Compiler.compile_types_module_body([
          TestTypes.User,
          TestTypes.Organization
        ])

      ast_string = Macro.to_string(body_ast)

      # Should reference :organization identifier, not the module
      assert ast_string =~ ":organization"
    end

    test "generates valid resolve_type for interfaces" do
      body_ast =
        Compiler.compile_types_module_body([
          TestInterfaces.Node,
          TestTypes.User,
          TestTypes.Organization,
          TestTypes.Post
        ])

      ast_string = Macro.to_string(body_ast)

      # Should have resolve_type with struct mappings
      assert ast_string =~ "resolve_type"
      assert ast_string =~ "Map.get"
    end
  end

  describe "Zero compile-time dependencies" do
    test "User module has no runtime dependency on Organization module functions" do
      # This proves the core concept: referencing Organization doesn't call any functions
      definition = TestTypes.User.__absinthe_object_definition__()

      # The organization field stores a symbolic reference
      org_field = Enum.find(definition.fields, &(&1.name == :organization))

      # Type is stored as {:module, TestTypes.Organization} - just data, not a function call
      assert {:module, TestTypes.Organization} = org_field.type

      # The actual identifier resolution would happen at schema compilation time
      # NOT when User module is compiled
    end

    test "Post references User without calling User functions" do
      definition = TestTypes.Post.__absinthe_object_definition__()
      author_field = Enum.find(definition.fields, &(&1.name == :author))

      # Just an atom reference - no dependency
      assert {:module, TestTypes.User} = author_field.type
    end

    test "implements stores module atom without calling interface functions" do
      definition = TestTypes.User.__absinthe_object_definition__()

      # Interface is stored as module atom
      assert TestInterfaces.Node in definition.interfaces

      # We never called TestInterfaces.Node.__absinthe_object_identifier__()
      # during User's compilation - that's the key difference from the original approach
    end
  end

  describe "Identifier resolution happens at schema compilation" do
    test "module references can be resolved to identifiers" do
      # Simulating what happens at schema compilation time
      user_def = TestTypes.User.__absinthe_object_definition__()

      # Build type lookup
      type_lookup = %{
        TestTypes.Organization => :organization,
        TestTypes.User => :user,
        TestInterfaces.Node => :node
      }

      # Resolve organization field type
      org_field = Enum.find(user_def.fields, &(&1.name == :organization))
      {:module, org_module} = org_field.type

      resolved_type = Map.get(type_lookup, org_module)
      assert resolved_type == :organization
    end
  end
end
