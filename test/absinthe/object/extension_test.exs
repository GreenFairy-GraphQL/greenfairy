defmodule Absinthe.Object.ExtensionTest do
  use ExUnit.Case, async: true

  # Test extension that adds custom macros
  defmodule TestExtension do
    use Absinthe.Object.Extension

    @impl true
    def using(_opts) do
      quote do
        import Absinthe.Object.ExtensionTest.TestExtension.Macros
        Module.register_attribute(__MODULE__, :test_extension_metadata, accumulate: true)
      end
    end

    @impl true
    def before_compile(_env, config) do
      quote do
        def __test_extension_config__ do
          unquote(Macro.escape(config))
        end
      end
    end

    defmodule Macros do
      @moduledoc false

      defmacro custom_field(name) do
        quote do
          @test_extension_metadata {:custom_field, unquote(name)}
          field unquote(name), :string
        end
      end
    end
  end

  # Another extension to test multiple extensions
  defmodule AnotherExtension do
    use Absinthe.Object.Extension

    @impl true
    def using(_opts) do
      quote do
        Module.register_attribute(__MODULE__, :another_metadata, accumulate: true)
      end
    end

    @impl true
    def before_compile(_env, _config) do
      quote do
        def __has_another_extension__ do
          true
        end
      end
    end
  end

  # Test struct
  defmodule TestUser do
    defstruct [:id, :name, :email]
  end

  # Type using the test extension
  defmodule ExtendedUserType do
    use Absinthe.Object.Type

    type "ExtendedUser", struct: TestUser do
      use TestExtension

      field :id, non_null(:id)
      field :name, :string

      # Use custom macro from extension
      custom_field(:dynamic_field)
    end
  end

  # Type using multiple extensions
  defmodule MultiExtendedType do
    use Absinthe.Object.Type

    type "MultiExtended", struct: TestUser do
      use TestExtension
      use AnotherExtension

      field :id, non_null(:id)
    end
  end

  describe "Extension behaviour" do
    test "using/1 callback is required" do
      # Check the behaviour module directly
      assert {:using, 1} in Absinthe.Object.Extension.behaviour_info(:callbacks)
    end

    test "transform_field/2 callback is optional" do
      assert {:transform_field, 2} in Absinthe.Object.Extension.behaviour_info(:optional_callbacks)
    end

    test "before_compile/2 callback is optional" do
      assert {:before_compile, 2} in Absinthe.Object.Extension.behaviour_info(:optional_callbacks)
    end
  end

  describe "using extensions in types" do
    test "extension is registered in type definition" do
      definition = ExtendedUserType.__absinthe_object_definition__()
      assert TestExtension in definition.extensions
    end

    test "__absinthe_object_extensions__ returns list of extensions" do
      extensions = ExtendedUserType.__absinthe_object_extensions__()
      assert is_list(extensions)
      assert TestExtension in extensions
    end

    test "extension using/1 callback runs and imports macros" do
      # The custom_field macro was imported and used
      definition = ExtendedUserType.__absinthe_object_definition__()
      # Type should have compiled without error, meaning macros were imported
      assert definition.name == "ExtendedUser"
    end

    test "extension before_compile/2 callback injects functions" do
      # The before_compile callback should have added this function
      config = ExtendedUserType.__test_extension_config__()
      assert is_map(config)
      assert config.type_name == "ExtendedUser"
      assert config.type_identifier == :extended_user
      assert config.struct == TestUser
    end
  end

  describe "multiple extensions" do
    test "multiple extensions can be used in same type" do
      extensions = MultiExtendedType.__absinthe_object_extensions__()
      assert TestExtension in extensions
      assert AnotherExtension in extensions
    end

    test "all extension before_compile callbacks run" do
      # TestExtension adds __test_extension_config__
      assert function_exported?(MultiExtendedType, :__test_extension_config__, 0)

      # AnotherExtension adds __has_another_extension__
      assert MultiExtendedType.__has_another_extension__() == true
    end

    test "extensions are registered in order" do
      extensions = MultiExtendedType.__absinthe_object_extensions__()
      assert extensions == [TestExtension, AnotherExtension]
    end
  end

  describe "extension module detection" do
    test "module with using/1 is detected as extension" do
      # The Type module uses is_extension_module? internally
      # We can verify by using an extension in a type block
      extensions = ExtendedUserType.__absinthe_object_extensions__()
      assert TestExtension in extensions
    end

    test "regular modules are passed through unchanged" do
      # Non-extension use statements should work normally
      # This is implicitly tested by the fact that Absinthe.Object.Type uses
      # Absinthe.Schema.Notation which isn't an extension
      definition = ExtendedUserType.__absinthe_object_definition__()
      assert definition.kind == :object
    end
  end

  describe "extension with options" do
    defmodule OptionExtension do
      use Absinthe.Object.Extension

      @impl true
      def using(opts) do
        prefix = Keyword.get(opts, :prefix, "default")

        quote do
          @option_extension_prefix unquote(prefix)

          def __option_extension_prefix__ do
            @option_extension_prefix
          end
        end
      end
    end

    defmodule TypeWithOptions do
      use Absinthe.Object.Type

      type "TypeWithOptions" do
        use OptionExtension, prefix: "custom"

        field :id, :id
      end
    end

    test "extension receives options from use statement" do
      assert TypeWithOptions.__option_extension_prefix__() == "custom"
    end
  end
end
