defmodule GreenFairy.Introspection.VisibilityTest do
  use ExUnit.Case, async: true

  # ============================================================================
  # Test Types
  # ============================================================================

  defmodule TestUser do
    defstruct [:id, :name, :email, :ssn]
  end

  defmodule TestSecret do
    defstruct [:id, :cpu, :memory]
  end

  # Type with field-level visibility
  defmodule UserType do
    use GreenFairy.Type

    type "VisUser", struct: TestUser, cql: false do
      field :id, non_null(:id)
      field :name, :string

      field :ssn, :string do
        visible fn ctx -> ctx[:admin] end
      end
    end
  end

  # Type with type-level visibility (hidden from non-admins)
  defmodule InternalMetricsType do
    use GreenFairy.Type

    type "VisInternalMetrics", struct: TestSecret, cql: false do
      visible fn ctx -> ctx[:admin] end

      field :cpu, :float
      field :memory, :float
    end
  end

  # Type with both type-level and field-level visibility
  defmodule CombinedType do
    use GreenFairy.Type

    type "VisCombined", struct: TestSecret, cql: false do
      visible fn ctx -> ctx[:admin] || ctx[:internal] end

      field :cpu, :float

      field :memory, :float do
        visible fn ctx -> ctx[:admin] end
      end
    end
  end

  # Type without any visibility (default behavior)
  defmodule PublicType do
    use GreenFairy.Type

    type "VisPublic", struct: TestUser, cql: false do
      field :id, non_null(:id)
      field :name, :string
    end
  end

  # ============================================================================
  # Unit Tests: __type_visible__
  # ============================================================================

  describe "__type_visible__/1" do
    test "type without visible callback is always visible" do
      assert PublicType.__type_visible__(%{}) == true
      assert PublicType.__type_visible__(%{admin: true}) == true
    end

    test "type with visible callback respects context" do
      assert InternalMetricsType.__type_visible__(%{admin: true}) == true
      assert InternalMetricsType.__type_visible__(%{}) == false
      assert InternalMetricsType.__type_visible__(%{admin: false}) == false
    end

    test "combined type respects type-level visibility" do
      assert CombinedType.__type_visible__(%{admin: true}) == true
      assert CombinedType.__type_visible__(%{internal: true}) == true
      assert CombinedType.__type_visible__(%{}) == false
    end
  end

  # ============================================================================
  # Unit Tests: __field_visible__
  # ============================================================================

  describe "__field_visible__/2" do
    test "field without visible callback is always visible" do
      assert UserType.__field_visible__(:id, %{}) == true
      assert UserType.__field_visible__(:name, %{}) == true
      assert UserType.__field_visible__(:id, %{admin: true}) == true
    end

    test "field with visible callback respects context" do
      assert UserType.__field_visible__(:ssn, %{admin: true}) == true
      assert UserType.__field_visible__(:ssn, %{}) == false
      assert UserType.__field_visible__(:ssn, %{admin: false}) == false
    end

    test "combined type field-level visibility" do
      # cpu has no field-level visible, always visible (if type is visible)
      assert CombinedType.__field_visible__(:cpu, %{}) == true
      assert CombinedType.__field_visible__(:cpu, %{admin: true}) == true

      # memory has field-level visible requiring admin
      assert CombinedType.__field_visible__(:memory, %{admin: true}) == true
      assert CombinedType.__field_visible__(:memory, %{internal: true}) == false
    end
  end

  # ============================================================================
  # Integration Tests with Schema
  # ============================================================================

  defmodule VisibilityTestSchema do
    use GreenFairy.Schema

    import_types UserType
    import_types InternalMetricsType
    import_types CombinedType
    import_types PublicType

    root_query do
      field :user, :vis_user do
        resolve fn _, _, _ -> {:ok, %TestUser{id: "1", name: "Alice"}} end
      end

      field :metrics, :vis_internal_metrics do
        resolve fn _, _, _ -> {:ok, %TestSecret{id: "1", cpu: 0.5, memory: 1024.0}} end
      end

      field :combined, :vis_combined do
        resolve fn _, _, _ -> {:ok, %TestSecret{id: "2", cpu: 0.8, memory: 2048.0}} end
      end

      field :public, :vis_public do
        resolve fn _, _, _ -> {:ok, %TestUser{id: "2", name: "Bob"}} end
      end
    end
  end

  describe "introspection with visibility" do
    @introspect_types """
    {
      __schema {
        types {
          name
        }
      }
    }
    """

    test "admin context sees all types in __schema { types }" do
      {:ok, %{data: data}} =
        VisibilityTestSchema.run(@introspect_types, context: %{admin: true})

      type_names = Enum.map(data["__schema"]["types"], & &1["name"])
      assert "VisInternalMetrics" in type_names
      assert "VisUser" in type_names
      assert "VisPublic" in type_names
    end

    test "anonymous context hides types with visible callback" do
      {:ok, %{data: data}} =
        VisibilityTestSchema.run(@introspect_types, context: %{})

      type_names = Enum.map(data["__schema"]["types"], & &1["name"])
      refute "VisInternalMetrics" in type_names
      refute "VisCombined" in type_names
      # Types without visible callback remain visible
      assert "VisUser" in type_names
      assert "VisPublic" in type_names
    end

    test "__type(name: ...) returns nil for hidden types" do
      query = """
      {
        __type(name: "VisInternalMetrics") {
          name
        }
      }
      """

      {:ok, %{data: data}} =
        VisibilityTestSchema.run(query, context: %{})

      assert data["__type"] == nil
    end

    test "__type(name: ...) returns type for admin context" do
      query = """
      {
        __type(name: "VisInternalMetrics") {
          name
        }
      }
      """

      {:ok, %{data: data}} =
        VisibilityTestSchema.run(query, context: %{admin: true})

      assert data["__type"]["name"] == "VisInternalMetrics"
    end

    test "__type fields are filtered by field visibility" do
      query = """
      {
        __type(name: "VisUser") {
          fields {
            name
          }
        }
      }
      """

      # Admin sees all fields
      {:ok, %{data: admin_data}} =
        VisibilityTestSchema.run(query, context: %{admin: true})

      admin_fields = Enum.map(admin_data["__type"]["fields"], & &1["name"])
      assert "ssn" in admin_fields
      assert "name" in admin_fields
      assert "id" in admin_fields

      # Anonymous user doesn't see ssn
      {:ok, %{data: anon_data}} =
        VisibilityTestSchema.run(query, context: %{})

      anon_fields = Enum.map(anon_data["__type"]["fields"], & &1["name"])
      refute "ssn" in anon_fields
      assert "name" in anon_fields
      assert "id" in anon_fields
    end

    test "type without visible callback is always fully visible" do
      query = """
      {
        __type(name: "VisPublic") {
          fields {
            name
          }
        }
      }
      """

      {:ok, %{data: data}} =
        VisibilityTestSchema.run(query, context: %{})

      field_names = Enum.map(data["__type"]["fields"], & &1["name"])
      assert "id" in field_names
      assert "name" in field_names
    end

    test "combined type+field visibility: type visible but some fields hidden" do
      query = """
      {
        __type(name: "VisCombined") {
          fields {
            name
          }
        }
      }
      """

      # Internal user sees the type but not admin-only fields
      {:ok, %{data: data}} =
        VisibilityTestSchema.run(query, context: %{internal: true})

      field_names = Enum.map(data["__type"]["fields"], & &1["name"])
      assert "cpu" in field_names
      refute "memory" in field_names

      # Admin sees everything
      {:ok, %{data: admin_data}} =
        VisibilityTestSchema.run(query, context: %{admin: true})

      admin_fields = Enum.map(admin_data["__type"]["fields"], & &1["name"])
      assert "cpu" in admin_fields
      assert "memory" in admin_fields
    end
  end
end
