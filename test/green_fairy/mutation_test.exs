defmodule GreenFairy.MutationTest do
  use ExUnit.Case, async: true

  # Define a fake type module for testing type reference extraction
  defmodule FakeUserType do
    def __green_fairy_kind__, do: :type
  end

  defmodule TestMutations do
    use GreenFairy.Mutation

    mutations do
      field :create_item, :string do
        arg :name, non_null(:string)
        resolve fn _, %{name: name}, _ -> {:ok, "Created: #{name}"} end
      end

      field :delete_item, :boolean do
        arg :id, non_null(:id)
        resolve fn _, _, _ -> {:ok, true} end
      end
    end
  end

  # Test with module alias type references
  defmodule TestMutationsWithTypeRefs do
    use GreenFairy.Mutation

    mutations do
      # Field with module type reference (should be extracted)
      field :create_user, GreenFairy.MutationTest.FakeUserType do
        resolve fn _, _, _ -> {:ok, %{}} end
      end

      # Field with non_null wrapped module type
      field :update_user, non_null(GreenFairy.MutationTest.FakeUserType) do
        resolve fn _, _, _ -> {:ok, %{}} end
      end

      # Field with list_of wrapped module type
      field :bulk_create, list_of(GreenFairy.MutationTest.FakeUserType) do
        resolve fn _, _, _ -> {:ok, []} end
      end

      # Field with non_null(list_of()) wrapping
      field :bulk_update, non_null(list_of(GreenFairy.MutationTest.FakeUserType)) do
        resolve fn _, _, _ -> {:ok, []} end
      end

      # Field with custom type atom (non-builtin)
      field :get_status, :custom_status do
        resolve fn _, _, _ -> {:ok, :active} end
      end

      # Field with opts
      field :simple_field, :string, description: "Simple"
    end
  end

  # Test with a single field (non-block)
  defmodule SingleFieldMutation do
    use GreenFairy.Mutation

    mutations do
      field :single, :string do
        resolve fn _, _, _ -> {:ok, "single"} end
      end
    end
  end

  describe "Mutation module" do
    test "defines __green_fairy_kind__" do
      assert TestMutations.__green_fairy_kind__() == :mutations
    end

    test "defines __green_fairy_definition__" do
      definition = TestMutations.__green_fairy_definition__()

      assert definition.kind == :mutations
      assert definition.has_mutations == true
    end

    test "stores mutation fields block" do
      assert function_exported?(TestMutations, :__green_fairy_mutation_fields__, 0)
    end
  end

  describe "Mutation module without mutations block" do
    defmodule EmptyMutations do
      use GreenFairy.Mutation
    end

    test "has has_mutations as false" do
      definition = EmptyMutations.__green_fairy_definition__()
      assert definition.has_mutations == false
    end
  end

  describe "Type reference extraction" do
    test "extracts module type references from mutations" do
      refs = TestMutationsWithTypeRefs.__green_fairy_referenced_types__()

      # Should have extracted the FakeUserType module references
      assert is_list(refs)
      # Module aliases are stored as AST tuples, so we check for non-empty list
      assert length(refs) > 0
    end

    test "extracts custom atom types (non-builtins)" do
      refs = TestMutationsWithTypeRefs.__green_fairy_referenced_types__()

      # :custom_status is not a builtin, so it should be extracted
      assert :custom_status in refs
    end

    test "mutation fields identifier is correct" do
      assert TestMutationsWithTypeRefs.__green_fairy_mutation_fields_identifier__() == :green_fairy_mutations
    end

    test "single field mutation works" do
      assert SingleFieldMutation.__green_fairy_kind__() == :mutations
    end
  end

  describe "Mutation integration with schema" do
    defmodule MutationSchema do
      use Absinthe.Schema

      import_types TestMutations

      query do
        field :dummy, :string do
          resolve fn _, _, _ -> {:ok, "dummy"} end
        end
      end

      mutation do
        import_fields :green_fairy_mutations
      end
    end

    test "mutations can be executed" do
      assert {:ok, %{data: %{"createItem" => "Created: Test"}}} =
               Absinthe.run(~s|mutation { createItem(name: "Test") }|, MutationSchema)
    end

    test "mutations with boolean return work" do
      assert {:ok, %{data: %{"deleteItem" => true}}} =
               Absinthe.run(~s|mutation { deleteItem(id: "123") }|, MutationSchema)
    end
  end

  describe "edge cases" do
    # Mutation with only field name (no type or block)
    defmodule MutationWithMinimalField do
      use GreenFairy.Mutation

      mutations do
        # Field with only name and type atom that is a builtin
        field :check, :boolean

        # Field with name only (tests extraction catchall path)
      end
    end

    test "handles field with just name and builtin type" do
      refs = MutationWithMinimalField.__green_fairy_referenced_types__()
      # Builtin types like :boolean should not be extracted
      assert :boolean not in refs
    end

    # Mutation with catchall pattern match
    defmodule MutationWithOpts do
      use GreenFairy.Mutation

      mutations do
        # These exercise different extract_type_from_args patterns
        field :ping, :string, description: "A ping mutation"
      end
    end

    test "handles field with opts list" do
      definition = MutationWithOpts.__green_fairy_definition__()
      assert definition.has_mutations == true
    end
  end
end
