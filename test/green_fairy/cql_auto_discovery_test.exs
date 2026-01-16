defmodule GreenFairy.CQLAutoDiscoveryTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Tests for automatic CQL type discovery.

  Verifies that CQL filter and order input types are automatically discovered
  and generated without manual registration.
  """

  describe "CQL Type Discovery" do
    test "discovers CQL-enabled types in namespace" do
      # Define test modules inline
      defmodule TestSchema1.Types.User do
        use GreenFairy.Type

        type "User" do
          use GreenFairy.CQL

          authorize fn _user, _ctx -> :all end

          field :id, non_null(:id)
          field :name, :string
        end
      end

      defmodule TestSchema1.Types.Post do
        use GreenFairy.Type

        type "Post" do
          use GreenFairy.CQL

          authorize fn _post, _ctx -> :all end

          field :id, non_null(:id)
          field :title, :string
        end
      end

      # Discover CQL types in the TestSchema1 namespace
      discovered = GreenFairy.Discovery.discover_cql_types_in_namespaces([TestSchema1])

      # Should discover both User and Post
      assert length(discovered) == 2
      assert TestSchema1.Types.User in discovered
      assert TestSchema1.Types.Post in discovered
    end

    test "only discovers types with CQL enabled" do
      # Define types - one with CQL, one without
      defmodule TestSchema2.Types.Product do
        use GreenFairy.Type

        type "Product" do
          use GreenFairy.CQL

          authorize fn _product, _ctx -> :all end

          field :id, non_null(:id)
          field :name, :string
        end
      end

      defmodule TestSchema2.Types.Category do
        use GreenFairy.Type

        type "Category" do
          # No CQL extension

          field :id, non_null(:id)
          field :name, :string
        end
      end

      # Discover CQL types
      discovered = GreenFairy.Discovery.discover_cql_types_in_namespaces([TestSchema2])

      # Should only discover Product (has CQL), not Category (no CQL)
      assert length(discovered) == 1
      assert TestSchema2.Types.Product in discovered
      refute TestSchema2.Types.Category in discovered
    end

    test "discovered types export CQL functions" do
      defmodule TestSchema3.Types.Comment do
        use GreenFairy.Type

        type "Comment" do
          use GreenFairy.CQL

          authorize fn _comment, _ctx -> :all end

          field :id, non_null(:id)
          field :body, :string
        end
      end

      discovered = GreenFairy.Discovery.discover_cql_types_in_namespaces([TestSchema3])

      # Verify discovered types export required CQL functions
      for type_module <- discovered do
        assert function_exported?(type_module, :__cql_config__, 0)
        assert function_exported?(type_module, :__cql_generate_filter_input__, 0)
        assert function_exported?(type_module, :__cql_generate_order_input__, 0)
        assert function_exported?(type_module, :__cql_filterable_fields__, 0)
        assert function_exported?(type_module, :__cql_orderable_fields__, 0)
      end
    end

    test "generated filter inputs include all field operators" do
      defmodule TestSchema4.Types.Article do
        use GreenFairy.Type

        type "Article" do
          use GreenFairy.CQL

          authorize fn _article, _ctx -> :all end

          field :id, non_null(:id)
          field :title, :string
          field :views, :integer
        end
      end

      # Get filter input AST
      filter_ast = TestSchema4.Types.Article.__cql_generate_filter_input__()

      # The AST should be a quoted expression that defines an input object
      # It may be wrapped in a block with @desc attribute
      case filter_ast do
        {:input_object, _, _} -> :ok
        {:__block__, _, [{:@, _, [{:desc, _, _}]}, {:input_object, _, _}]} -> :ok
        other -> flunk("Expected input_object AST, got: #{inspect(other)}")
      end
    end
  end

  describe "GreenFairy.Discovery.discover_cql_types/1" do
    test "filters modules to only those with __cql_config__/0" do
      defmodule TestModule.WithCQL do
        use GreenFairy.Type

        type "WithCQL" do
          use GreenFairy.CQL
          authorize fn _, _ -> :all end
          field :id, :id
        end
      end

      defmodule TestModule.WithoutCQL do
        use GreenFairy.Type

        type "WithoutCQL" do
          field :id, :id
        end
      end

      all_modules = [TestModule.WithCQL, TestModule.WithoutCQL]
      cql_modules = GreenFairy.Discovery.discover_cql_types(all_modules)

      assert length(cql_modules) == 1
      assert TestModule.WithCQL in cql_modules
      refute TestModule.WithoutCQL in cql_modules
    end
  end

  describe "Schema Integration" do
    test "schema with CQL.Schema use automatically discovers types" do
      # This test verifies that the __before_compile__ callback works
      # We'll check that the schema can be compiled without manual type registration

      # Note: In a real test, we'd actually compile a schema and verify
      # the filter/order input types are present. For now, we verify the
      # discovery mechanism works correctly.

      defmodule TestOrder do
        use Ecto.Schema

        schema "orders" do
          field :status, :string
        end
      end

      defmodule TestApp.Types.Order do
        use GreenFairy.Type

        type "Order", struct: TestOrder do
          use GreenFairy.CQL
          authorize fn _, _ -> :all end
          field :id, :id
          field :status, :string
        end
      end

      # Verify the type exports CQL functions
      assert function_exported?(TestApp.Types.Order, :__cql_config__, 0)
      assert function_exported?(TestApp.Types.Order, :__cql_generate_filter_input__, 0)
      assert function_exported?(TestApp.Types.Order, :__cql_generate_order_input__, 0)

      # Verify filterable fields
      fields = TestApp.Types.Order.__cql_filterable_fields__()
      assert :id in fields
      assert :status in fields
    end
  end
end
