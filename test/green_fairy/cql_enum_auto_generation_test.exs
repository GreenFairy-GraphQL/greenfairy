defmodule GreenFairy.CQL.EnumAutoGenerationTest do
  @moduledoc """
  Tests for automatic CQL enum filter generation.

  Verifies that when a GreenFairy enum is used in a CQL-enabled type's field,
  the system automatically generates type-specific operator inputs instead of
  using the generic enum input.
  """
  use ExUnit.Case, async: false

  alias GreenFairy.TypeRegistry
  alias GreenFairy.CQL.Schema.EnumOperatorInput
  alias GreenFairy.CQL.Schema.FilterInput
  alias GreenFairy.CQL.ScalarMapper

  # ==========================================================================
  # Test Enums
  # ==========================================================================

  defmodule TestOrderStatus do
    use GreenFairy.Enum

    enum "OrderStatus" do
      value :pending
      value :shipped
      value :delivered
      value :cancelled
    end
  end

  defmodule TestUserRole do
    use GreenFairy.Enum

    enum "UserRole" do
      value :admin
      value :member
      value :guest
    end
  end

  # ==========================================================================
  # Test Type with Enum Field
  # ==========================================================================

  defmodule TestOrder do
    defstruct [:id, :status, :user_role, :tags]

    def __schema__(:source), do: "orders"
    def __schema__(:prefix), do: nil
    def __schema__(:fields), do: [:id, :status, :user_role, :tags]
    def __schema__(:primary_key), do: [:id]
    def __schema__(:type, :id), do: :id
    def __schema__(:type, :status), do: {:parameterized, Ecto.Enum, %{values: [:pending, :shipped, :delivered, :cancelled]}}
    def __schema__(:type, :user_role), do: {:parameterized, Ecto.Enum, %{values: [:admin, :member, :guest]}}
    def __schema__(:type, :tags), do: {:array, {:parameterized, Ecto.Enum, %{values: [:urgent, :normal]}}}
    def __schema__(:associations), do: []
    def __schema__(:embeds), do: []
    def __schema__(:association, _field), do: nil
  end

  # ==========================================================================
  # Tests
  # ==========================================================================

  describe "TypeRegistry enum detection" do
    setup do
      # Register the test enums
      TypeRegistry.register(:order_status, TestOrderStatus)
      TypeRegistry.register(:user_role, TestUserRole)
      :ok
    end

    test "is_enum?/1 returns true for registered GreenFairy enums" do
      assert TypeRegistry.is_enum?(:order_status) == true
      assert TypeRegistry.is_enum?(:user_role) == true
    end

    test "is_enum?/1 returns false for non-enum types" do
      assert TypeRegistry.is_enum?(:string) == false
      assert TypeRegistry.is_enum?(:integer) == false
      assert TypeRegistry.is_enum?(:not_registered) == false
    end

    test "all_enums/0 returns all registered enum identifiers" do
      enums = TypeRegistry.all_enums()
      assert :order_status in enums
      assert :user_role in enums
    end
  end

  describe "EnumOperatorInput generation" do
    test "operator_type_identifier/1 generates correct identifier for enum" do
      assert EnumOperatorInput.operator_type_identifier(:order_status) == :cql_enum_order_status_input
      assert EnumOperatorInput.operator_type_identifier(:user_role) == :cql_enum_user_role_input
    end

    test "operator_type_identifier/1 handles string enum names" do
      assert EnumOperatorInput.operator_type_identifier("OrderStatus") == :cql_enum_order_status_input
      assert EnumOperatorInput.operator_type_identifier("UserRole") == :cql_enum_user_role_input
    end

    test "array_operator_type_identifier/1 generates correct identifier for enum arrays" do
      assert EnumOperatorInput.array_operator_type_identifier(:order_status) == :cql_enum_order_status_array_input
      assert EnumOperatorInput.array_operator_type_identifier(:user_role) == :cql_enum_user_role_array_input
    end

    test "generate/1 produces valid AST for enum operator input" do
      ast = EnumOperatorInput.generate(:order_status)
      ast_string = Macro.to_string(ast)

      # Should define an input_object with the correct identifier
      assert ast_string =~ "input_object(:cql_enum_order_status_input)"

      # Should have enum-specific fields with the actual enum type
      assert ast_string =~ "field(:_eq, :order_status)"
      assert ast_string =~ "field(:_neq, :order_status)"
      assert ast_string =~ "field(:_in, list_of(non_null(:order_status)))"
      assert ast_string =~ "field(:_nin, list_of(non_null(:order_status)))"
      assert ast_string =~ "field(:_is_null, :boolean)"
    end

    test "generate_array/1 produces valid AST for enum array operator input" do
      ast = EnumOperatorInput.generate_array(:order_status)
      ast_string = Macro.to_string(ast)

      # Should define an input_object with the correct identifier
      assert ast_string =~ "input_object(:cql_enum_order_status_array_input)"

      # Should have array-specific operators
      assert ast_string =~ "field(:_includes, :order_status)"
      assert ast_string =~ "field(:_excludes, :order_status)"
      assert ast_string =~ "field(:_includes_all, list_of(non_null(:order_status)))"
      assert ast_string =~ "field(:_is_empty, :boolean)"
    end
  end

  describe "FilterInput with enum detection" do
    setup do
      TypeRegistry.register(:order_status, TestOrderStatus)
      TypeRegistry.register(:user_role, TestUserRole)
      :ok
    end

    test "detects enum types in filter fields" do
      fields = [
        {:id, :id},
        {:status, :order_status},  # GreenFairy enum
        {:name, :string}
      ]

      enum_types = FilterInput.extract_enum_types(fields)
      assert :order_status in enum_types
      refute :string in enum_types
      refute :id in enum_types
    end

    test "detects array enum types in filter fields" do
      fields = [
        {:id, :id},
        {:tags, {:array, :order_status}}  # Array of GreenFairy enum
      ]

      enum_types = FilterInput.extract_enum_types(fields)
      assert :order_status in enum_types
    end

    test "field_info returns type-specific enum operator input" do
      fields = [
        {:id, :id},
        {:status, :order_status},
        {:name, :string}
      ]

      info = FilterInput.field_info(fields)

      # Find the status field info
      status_info = Enum.find(info, fn {name, _, _} -> name == :status end)
      assert {_, :order_status, :cql_enum_order_status_input} = status_info

      # Verify non-enum fields still use standard types
      id_info = Enum.find(info, fn {name, _, _} -> name == :id end)
      assert {_, :id, :cql_op_id_input} = id_info

      name_info = Enum.find(info, fn {name, _, _} -> name == :name end)
      assert {_, :string, :cql_op_string_input} = name_info
    end
  end

  describe "ScalarMapper with enum support" do
    setup do
      TypeRegistry.register(:order_status, TestOrderStatus)
      :ok
    end

    test "operator_type_identifier returns type-specific input for GreenFairy enum" do
      # When passing a GreenFairy enum identifier, should return type-specific input
      assert ScalarMapper.operator_type_identifier(:order_status) == :cql_enum_order_status_input
    end

    test "operator_type_identifier returns type-specific input for array of enum" do
      assert ScalarMapper.operator_type_identifier({:array, :order_status}) == :cql_enum_order_status_array_input
    end

    test "operator_type_identifier returns generic enum input for Ecto.Enum" do
      # Ecto.Enum types (not GreenFairy enums) still use generic input
      ecto_enum_type = {:parameterized, Ecto.Enum, %{values: [:a, :b]}}
      assert ScalarMapper.operator_type_identifier(ecto_enum_type) == :cql_op_enum_input
    end

    test "standard types are not affected by enum detection" do
      assert ScalarMapper.operator_type_identifier(:string) == :cql_op_string_input
      assert ScalarMapper.operator_type_identifier(:integer) == :cql_op_integer_input
      assert ScalarMapper.operator_type_identifier(:boolean) == :cql_op_boolean_input
    end
  end

  describe "End-to-end: Filter input generation with enums" do
    setup do
      TypeRegistry.register(:order_status, TestOrderStatus)
      TypeRegistry.register(:user_role, TestUserRole)
      :ok
    end

    test "generate/2 creates filter with type-specific enum operator references" do
      fields = [
        {:id, :id},
        {:status, :order_status},
        {:role, :user_role},
        {:name, :string}
      ]

      ast = FilterInput.generate("Order", fields)
      ast_string = Macro.to_string(ast)

      # Should reference type-specific enum inputs
      assert ast_string =~ "field(:status, :cql_enum_order_status_input)"
      assert ast_string =~ "field(:role, :cql_enum_user_role_input)"

      # Should still use standard inputs for non-enum fields
      assert ast_string =~ "field(:id, :cql_op_id_input)"
      assert ast_string =~ "field(:name, :cql_op_string_input)"
    end

    test "extracted enum types can be used to generate operator inputs" do
      fields = [
        {:id, :id},
        {:status, :order_status},
        {:role, :user_role}
      ]

      enum_types = FilterInput.extract_enum_types(fields)

      # Generate operator inputs for all extracted enums
      operator_asts = EnumOperatorInput.generate_all(enum_types)

      # Should generate 4 inputs (scalar + array for each enum)
      assert length(operator_asts) == 4

      all_ast_string = operator_asts |> Enum.map(&Macro.to_string/1) |> Enum.join("\n")

      assert all_ast_string =~ "cql_enum_order_status_input"
      assert all_ast_string =~ "cql_enum_order_status_array_input"
      assert all_ast_string =~ "cql_enum_user_role_input"
      assert all_ast_string =~ "cql_enum_user_role_array_input"
    end
  end
end
