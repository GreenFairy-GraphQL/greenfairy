defmodule GreenFairy.QueryTest do
  use ExUnit.Case, async: true

  # Define a fake type module for testing type reference extraction
  defmodule FakePostType do
    def __green_fairy_kind__, do: :type
  end

  defmodule TestQueries do
    use GreenFairy.Query

    queries do
      field :hello, :string do
        resolve fn _, _, _ -> {:ok, "world"} end
      end

      field :echo, :string do
        arg :message, non_null(:string)
        resolve fn _, %{message: msg}, _ -> {:ok, msg} end
      end
    end
  end

  # Test with module alias type references
  defmodule TestQueriesWithTypeRefs do
    use GreenFairy.Query

    queries do
      # Field with module type reference
      field :post, GreenFairy.QueryTest.FakePostType do
        resolve fn _, _, _ -> {:ok, %{}} end
      end

      # Field with non_null wrapped module type
      field :required_post, non_null(GreenFairy.QueryTest.FakePostType) do
        resolve fn _, _, _ -> {:ok, %{}} end
      end

      # Field with list_of wrapped module type
      field :posts, list_of(GreenFairy.QueryTest.FakePostType) do
        resolve fn _, _, _ -> {:ok, []} end
      end

      # Field with non_null(list_of()) wrapping
      field :all_posts, non_null(list_of(GreenFairy.QueryTest.FakePostType)) do
        resolve fn _, _, _ -> {:ok, []} end
      end

      # Field with custom type atom (non-builtin)
      field :category, :custom_category do
        resolve fn _, _, _ -> {:ok, :tech} end
      end

      # Field with opts
      field :version, :string, description: "Version"
    end
  end

  # Test with a single field (non-block)
  defmodule SingleFieldQuery do
    use GreenFairy.Query

    queries do
      field :single, :string do
        resolve fn _, _, _ -> {:ok, "single"} end
      end
    end
  end

  describe "Query module" do
    test "defines __green_fairy_kind__" do
      assert TestQueries.__green_fairy_kind__() == :queries
    end

    test "defines __green_fairy_definition__" do
      definition = TestQueries.__green_fairy_definition__()

      assert definition.kind == :queries
      assert definition.has_queries == true
    end

    test "stores query fields block" do
      assert function_exported?(TestQueries, :__green_fairy_query_fields__, 0)
    end
  end

  describe "Query module without queries block" do
    defmodule EmptyQueries do
      use GreenFairy.Query
    end

    test "has has_queries as false" do
      definition = EmptyQueries.__green_fairy_definition__()
      assert definition.has_queries == false
    end
  end

  describe "Type reference extraction" do
    test "extracts module type references from queries" do
      refs = TestQueriesWithTypeRefs.__green_fairy_referenced_types__()

      # Should have extracted the FakePostType module references
      assert is_list(refs)
      # Module aliases are stored as AST tuples, so we check for non-empty list
      assert length(refs) > 0
    end

    test "extracts custom atom types (non-builtins)" do
      refs = TestQueriesWithTypeRefs.__green_fairy_referenced_types__()

      # :custom_category is not a builtin, so it should be extracted
      assert :custom_category in refs
    end

    test "query fields identifier is correct" do
      assert TestQueriesWithTypeRefs.__green_fairy_query_fields_identifier__() == :green_fairy_queries
    end

    test "single field query works" do
      assert SingleFieldQuery.__green_fairy_kind__() == :queries
    end
  end

  describe "Query integration with schema" do
    defmodule QuerySchema do
      use Absinthe.Schema

      import_types TestQueries

      query do
        import_fields :green_fairy_queries
      end
    end

    test "queries can be executed" do
      assert {:ok, %{data: %{"hello" => "world"}}} =
               Absinthe.run("{ hello }", QuerySchema)
    end

    test "queries with args work" do
      assert {:ok, %{data: %{"echo" => "test"}}} =
               Absinthe.run(~s|{ echo(message: "test") }|, QuerySchema)
    end
  end

  describe "edge cases" do
    # Query with only field name (no type or block)
    defmodule QueryWithMinimalField do
      use GreenFairy.Query

      queries do
        # Field with only name and type atom that is a builtin
        field :status, :boolean

        # Field with name only (will fail but tests extraction path)
        # Note: Absinthe requires type, this is just for coverage
      end
    end

    test "handles field with just name and builtin type" do
      refs = QueryWithMinimalField.__green_fairy_referenced_types__()
      # Builtin types like :boolean should not be extracted
      assert :boolean not in refs
    end

    # Query with catchall pattern match
    defmodule QueryWithCatchall do
      use GreenFairy.Query

      queries do
        # These exercise different extract_type_from_args patterns
        field :simple, :string, description: "A simple field"
      end
    end

    test "handles field with opts list" do
      definition = QueryWithCatchall.__green_fairy_definition__()
      assert definition.has_queries == true
    end
  end
end
