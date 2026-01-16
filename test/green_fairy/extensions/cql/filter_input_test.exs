defmodule GreenFairy.CQL.FilterInputTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.Schema.FilterInput

  describe "filter_type_identifier/1" do
    test "generates identifier from string type name" do
      assert FilterInput.filter_type_identifier("User") == :cql_filter_user_input
      assert FilterInput.filter_type_identifier("BlogPost") == :cql_filter_blog_post_input
      assert FilterInput.filter_type_identifier("APIKey") == :cql_filter_api_key_input
    end

    test "generates identifier from atom type name" do
      assert FilterInput.filter_type_identifier(:user) == :cql_filter_user_input
      assert FilterInput.filter_type_identifier(:blog_post) == :cql_filter_blog_post_input
    end
  end

  describe "generate/2" do
    test "generates filter input AST with combinator fields" do
      fields = [{:id, :id}, {:name, :string}]
      ast = FilterInput.generate("User", fields)

      assert {:__block__, _, _} = ast
    end

    test "generates filter input with correct identifier" do
      fields = [{:id, :id}]
      ast = FilterInput.generate("User", fields)

      # The AST should contain the identifier :cql_filter_user_input
      ast_string = Macro.to_string(ast)
      assert ast_string =~ "cql_filter_user_input"
    end

    test "includes _and, _or, _not combinator fields" do
      fields = [{:id, :id}]
      ast = FilterInput.generate("User", fields)
      ast_string = Macro.to_string(ast)

      assert ast_string =~ "_and"
      assert ast_string =~ "_or"
      assert ast_string =~ "_not"
    end

    test "includes field-specific operator types" do
      fields = [{:id, :id}, {:name, :string}, {:age, :integer}]
      ast = FilterInput.generate("User", fields)
      ast_string = Macro.to_string(ast)

      assert ast_string =~ "cql_op_id_input"
      assert ast_string =~ "cql_op_string_input"
      assert ast_string =~ "cql_op_integer_input"
    end
  end

  describe "generate/3 with custom filters" do
    test "uses custom filter operator type" do
      fields = [{:id, :id}, {:computed_field, nil}]

      custom_filters = %{
        computed_field: %{operators: [:eq, :contains]}
      }

      ast = FilterInput.generate("User", fields, custom_filters)
      ast_string = Macro.to_string(ast)

      # Should use string input because of :contains operator
      assert ast_string =~ "computed_field"
      assert ast_string =~ "cql_op_string_input"
    end

    test "maps custom filters with comparison operators to integer" do
      fields = [{:score, nil}]

      custom_filters = %{
        score: %{operators: [:eq, :gt, :lt]}
      }

      ast = FilterInput.generate("Test", fields, custom_filters)
      ast_string = Macro.to_string(ast)

      assert ast_string =~ "cql_op_integer_input"
    end

    test "maps custom filters with basic operators to generic" do
      fields = [{:custom, nil}]

      custom_filters = %{
        custom: %{operators: [:eq, :in]}
      }

      ast = FilterInput.generate("Test", fields, custom_filters)
      ast_string = Macro.to_string(ast)

      assert ast_string =~ "cql_op_generic_input"
    end
  end

  describe "field_info/2" do
    test "returns field information with operator types" do
      fields = [{:id, :id}, {:name, :string}, {:age, :integer}]
      info = FilterInput.field_info(fields)

      assert {:id, :id, :cql_op_id_input} in info
      assert {:name, :string, :cql_op_string_input} in info
      assert {:age, :integer, :cql_op_integer_input} in info
    end

    test "returns JSON operator type for map fields" do
      fields = [{:data, :map}]
      info = FilterInput.field_info(fields)

      assert [{:data, :map, :cql_op_json_input}] == info
    end

    test "includes custom filter information" do
      fields = [{:custom, nil}]
      custom_filters = %{custom: %{operators: [:eq, :contains]}}

      info = FilterInput.field_info(fields, custom_filters)

      # Should return string input type for contains operator
      assert [{:custom, nil, :cql_op_string_input}] == info
    end
  end

  describe "input_name/1 (backwards compatibility)" do
    test "generates filter input name from string" do
      assert FilterInput.input_name("User") == :UserFilter
    end

    test "generates filter input name from atom" do
      assert FilterInput.input_name(:user) == :UserFilter
      assert FilterInput.input_name(:blog_post) == :BlogPostFilter
    end
  end
end
