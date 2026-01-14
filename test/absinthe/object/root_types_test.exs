defmodule Absinthe.Object.RootTypesTest do
  use ExUnit.Case, async: true

  # Define modules at top level for proper compilation order
  defmodule SimpleRootQuery do
    use Absinthe.Object.RootQuery

    root_query_fields do
      field :ping, :string do
        resolve fn _, _, _ -> {:ok, "pong"} end
      end
    end
  end

  defmodule SimpleRootMutation do
    use Absinthe.Object.RootMutation

    root_mutation_fields do
      field :do_something, :boolean do
        resolve fn _, _, _ -> {:ok, true} end
      end
    end
  end

  defmodule SimpleRootSubscription do
    use Absinthe.Object.RootSubscription

    root_subscription_fields do
      field :on_event, :string do
        config fn _, _ -> {:ok, topic: "*"} end
      end
    end
  end

  defmodule IntegrationSchema do
    use Absinthe.Schema

    import_types Absinthe.Object.RootTypesTest.SimpleRootQuery
    import_types Absinthe.Object.RootTypesTest.SimpleRootMutation
    import_types Absinthe.Object.RootTypesTest.SimpleRootSubscription

    query do
      import_fields :absinthe_object_root_query_fields
    end

    mutation do
      import_fields :absinthe_object_root_mutation_fields
    end

    subscription do
      import_fields :absinthe_object_root_subscription_fields
    end
  end

  describe "RootQuery" do
    test "defines __absinthe_object_definition__" do
      assert SimpleRootQuery.__absinthe_object_definition__() == %{kind: :root_query}
    end

    test "defines __absinthe_object_kind__" do
      assert SimpleRootQuery.__absinthe_object_kind__() == :root_query
    end

    test "defines __absinthe_object_query_fields_identifier__" do
      assert SimpleRootQuery.__absinthe_object_query_fields_identifier__() ==
               :absinthe_object_root_query_fields
    end
  end

  describe "RootMutation" do
    test "defines __absinthe_object_definition__" do
      assert SimpleRootMutation.__absinthe_object_definition__() == %{kind: :root_mutation}
    end

    test "defines __absinthe_object_kind__" do
      assert SimpleRootMutation.__absinthe_object_kind__() == :root_mutation
    end

    test "defines __absinthe_object_mutation_fields_identifier__" do
      assert SimpleRootMutation.__absinthe_object_mutation_fields_identifier__() ==
               :absinthe_object_root_mutation_fields
    end
  end

  describe "RootSubscription" do
    test "defines __absinthe_object_definition__" do
      assert SimpleRootSubscription.__absinthe_object_definition__() == %{kind: :root_subscription}
    end

    test "defines __absinthe_object_kind__" do
      assert SimpleRootSubscription.__absinthe_object_kind__() == :root_subscription
    end

    test "defines __absinthe_object_subscription_fields_identifier__" do
      assert SimpleRootSubscription.__absinthe_object_subscription_fields_identifier__() ==
               :absinthe_object_root_subscription_fields
    end
  end

  describe "Schema integration" do
    test "query fields are available in schema" do
      type = Absinthe.Schema.lookup_type(IntegrationSchema, :query)
      assert Map.has_key?(type.fields, :ping)
    end

    test "mutation fields are available in schema" do
      type = Absinthe.Schema.lookup_type(IntegrationSchema, :mutation)
      assert Map.has_key?(type.fields, :do_something)
    end

    test "subscription fields are available in schema" do
      type = Absinthe.Schema.lookup_type(IntegrationSchema, :subscription)
      assert Map.has_key?(type.fields, :on_event)
    end

    test "can execute query" do
      assert {:ok, %{data: %{"ping" => "pong"}}} =
               Absinthe.run("{ ping }", IntegrationSchema)
    end

    test "can execute mutation" do
      assert {:ok, %{data: %{"doSomething" => true}}} =
               Absinthe.run("mutation { doSomething }", IntegrationSchema)
    end
  end

  describe "RootQuery compile error" do
    test "raises when root_query_fields not defined" do
      assert_raise CompileError, ~r/RootQuery module must define fields using root_query_fields\/1/, fn ->
        Code.compile_string("""
        defmodule InvalidRootQuery do
          use Absinthe.Object.RootQuery
          # Missing root_query_fields!
        end
        """)
      end
    end
  end

  describe "RootMutation compile error" do
    test "raises when root_mutation_fields not defined" do
      assert_raise CompileError, ~r/RootMutation module must define fields using root_mutation_fields\/1/, fn ->
        Code.compile_string("""
        defmodule InvalidRootMutation do
          use Absinthe.Object.RootMutation
          # Missing root_mutation_fields!
        end
        """)
      end
    end
  end

  describe "RootSubscription compile error" do
    test "raises when root_subscription_fields not defined" do
      assert_raise CompileError, ~r/RootSubscription module must define fields using root_subscription_fields\/1/, fn ->
        Code.compile_string("""
        defmodule InvalidRootSubscription do
          use Absinthe.Object.RootSubscription
          # Missing root_subscription_fields!
        end
        """)
      end
    end
  end

  # Test support module coverage
  describe "Support module functions" do
    alias Absinthe.Object.Test.RootQueryExample
    alias Absinthe.Object.Test.RootMutationExample

    test "RootQueryExample has correct definition" do
      assert RootQueryExample.__absinthe_object_definition__() == %{kind: :root_query}
    end

    test "RootQueryExample has correct kind" do
      assert RootQueryExample.__absinthe_object_kind__() == :root_query
    end

    test "RootQueryExample has correct identifier" do
      assert RootQueryExample.__absinthe_object_query_fields_identifier__() == :absinthe_object_root_query_fields
    end

    test "RootMutationExample has correct definition" do
      assert RootMutationExample.__absinthe_object_definition__() == %{kind: :root_mutation}
    end

    test "RootMutationExample has correct kind" do
      assert RootMutationExample.__absinthe_object_kind__() == :root_mutation
    end

    test "RootMutationExample has correct identifier" do
      assert RootMutationExample.__absinthe_object_mutation_fields_identifier__() ==
               :absinthe_object_root_mutation_fields
    end
  end
end
