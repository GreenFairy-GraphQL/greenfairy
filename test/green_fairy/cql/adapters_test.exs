defmodule GreenFairy.CQL.AdaptersTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.Adapters.MySQL
  alias GreenFairy.CQL.Adapters.SQLite
  alias GreenFairy.CQL.Adapters.MSSQL
  alias GreenFairy.CQL.Adapters.Postgres
  alias GreenFairy.CQL.Adapters.Elasticsearch

  defmodule TestSchema do
    use Ecto.Schema

    schema "test_records" do
      field :name, :string
      field :age, :integer
    end
  end

  describe "MySQL adapter" do
    test "sort_directions returns asc and desc" do
      assert MySQL.sort_directions() == [:asc, :desc]
    end

    test "sort_direction_enum without namespace" do
      assert MySQL.sort_direction_enum(nil) == :cql_sort_direction
    end

    test "sort_direction_enum with namespace" do
      assert MySQL.sort_direction_enum(:analytics) == :cql_analytics_sort_direction
    end

    test "supports_geo_ordering? returns false" do
      refute MySQL.supports_geo_ordering?()
    end

    test "supports_priority_ordering? returns true" do
      assert MySQL.supports_priority_ordering?()
    end

    test "capabilities returns expected map" do
      caps = MySQL.capabilities()

      assert caps.native_arrays == false
      assert caps.supports_json_operators == true
      assert caps.emulated_ilike == true
    end

    test "operator_type_for returns correct identifier" do
      assert MySQL.operator_type_for(:string) == :cql_op_string_input
      assert MySQL.operator_type_for(:integer) == :cql_op_integer_input
    end

    test "supported_operators for scalar category" do
      operators = MySQL.supported_operators(:scalar, :string)

      assert :_eq in operators
      assert :_neq in operators
      assert :_like in operators
      assert :_ilike in operators
    end

    test "supported_operators for array category" do
      operators = MySQL.supported_operators(:array, {:array, :string})

      assert :_includes in operators
      assert :_excludes in operators
      assert :_is_null in operators
    end

    test "supported_operators for json category" do
      operators = MySQL.supported_operators(:json, :map)

      assert :_contains in operators
      assert :_has_key in operators
    end

    test "supported_operators for unknown category returns empty" do
      assert MySQL.supported_operators(:unknown, :any) == []
    end

    test "operator_inputs returns map of input types" do
      inputs = MySQL.operator_inputs()

      assert Map.has_key?(inputs, :cql_op_id_input)
      assert Map.has_key?(inputs, :cql_op_string_input)
      assert Map.has_key?(inputs, :cql_op_integer_input)
      assert Map.has_key?(inputs, :cql_op_boolean_input)
    end

    test "apply_operator with 5 args (direct call)" do
      import Ecto.Query
      query = from(t in TestSchema)

      result = MySQL.apply_operator(query, :name, :_eq, "test", field_type: :string)

      assert %Ecto.Query{} = result
    end

    test "apply_operator with 6 args (via primary adapter)" do
      import Ecto.Query
      query = from(t in TestSchema)

      result = MySQL.apply_operator(TestSchema, query, :name, :_eq, "test", field_type: :string)

      assert %Ecto.Query{} = result
    end

    test "apply_operator with unknown field type returns query unchanged" do
      import Ecto.Query
      query = from(t in TestSchema)

      result = MySQL.apply_operator(query, :name, :_eq, "test", field_type: :unknown_type)

      assert result == query
    end
  end

  describe "SQLite adapter" do
    test "sort_directions returns asc and desc" do
      assert SQLite.sort_directions() == [:asc, :desc]
    end

    test "sort_direction_enum without namespace" do
      assert SQLite.sort_direction_enum(nil) == :cql_sort_direction
    end

    test "sort_direction_enum with namespace" do
      assert SQLite.sort_direction_enum(:local) == :cql_local_sort_direction
    end

    test "supports_geo_ordering? returns false" do
      refute SQLite.supports_geo_ordering?()
    end

    test "supports_priority_ordering? returns false" do
      refute SQLite.supports_priority_ordering?()
    end

    test "capabilities returns expected map" do
      caps = SQLite.capabilities()

      assert caps.native_arrays == false
      assert caps.limited_json == true
    end

    test "operator_type_for returns correct identifier" do
      assert SQLite.operator_type_for(:string) == :cql_op_string_input
    end

    test "supported_operators for scalar category" do
      operators = SQLite.supported_operators(:scalar, :string)

      assert :_eq in operators
      assert :_like in operators
    end

    test "supported_operators for unknown category returns empty" do
      assert SQLite.supported_operators(:unknown, :any) == []
    end

    test "operator_inputs returns map of input types" do
      inputs = SQLite.operator_inputs()

      assert Map.has_key?(inputs, :cql_op_id_input)
      assert Map.has_key?(inputs, :cql_op_string_input)
    end

    test "apply_operator with field_type" do
      import Ecto.Query
      query = from(t in TestSchema)

      result = SQLite.apply_operator(query, :name, :_eq, "test", field_type: :string)

      assert %Ecto.Query{} = result
    end
  end

  describe "MSSQL adapter" do
    test "sort_directions returns asc and desc" do
      assert MSSQL.sort_directions() == [:asc, :desc]
    end

    test "sort_direction_enum without namespace" do
      assert MSSQL.sort_direction_enum(nil) == :cql_sort_direction
    end

    test "supports_geo_ordering? returns false" do
      refute MSSQL.supports_geo_ordering?()
    end

    test "supports_priority_ordering? returns true" do
      assert MSSQL.supports_priority_ordering?()
    end

    test "capabilities returns expected map" do
      caps = MSSQL.capabilities()

      assert caps.native_arrays == false
      assert caps.supports_full_text_search == true
    end

    test "operator_type_for returns correct identifier" do
      assert MSSQL.operator_type_for(:string) == :cql_op_string_input
    end

    test "supported_operators for scalar category" do
      operators = MSSQL.supported_operators(:scalar, :string)

      assert :_eq in operators
      assert :_like in operators
    end

    test "supported_operators for unknown category returns empty" do
      assert MSSQL.supported_operators(:unknown, :any) == []
    end

    test "operator_inputs returns map of input types" do
      inputs = MSSQL.operator_inputs()

      assert Map.has_key?(inputs, :cql_op_id_input)
      assert Map.has_key?(inputs, :cql_op_string_input)
    end

    test "apply_operator with field_type" do
      import Ecto.Query
      query = from(t in TestSchema)

      result = MSSQL.apply_operator(query, :name, :_eq, "test", field_type: :string)

      assert %Ecto.Query{} = result
    end
  end

  describe "Postgres adapter" do
    test "sort_directions includes nulls options" do
      directions = Postgres.sort_directions()

      assert :asc in directions
      assert :desc in directions
      assert :asc_nulls_first in directions
      assert :asc_nulls_last in directions
      assert :desc_nulls_first in directions
      assert :desc_nulls_last in directions
    end

    test "supports_geo_ordering? returns true" do
      assert Postgres.supports_geo_ordering?()
    end

    test "supports_priority_ordering? returns true" do
      assert Postgres.supports_priority_ordering?()
    end

    test "capabilities returns expected map" do
      caps = Postgres.capabilities()

      assert caps.native_arrays == true
      assert caps.supports_full_text_search == true
      assert caps.supports_json_operators == true
    end

    test "operator_type_for returns correct identifier" do
      assert Postgres.operator_type_for(:string) == :cql_op_string_input
    end

    test "supported_operators for scalar category" do
      operators = Postgres.supported_operators(:scalar, :string)

      assert :_eq in operators
      assert :_ilike in operators
      assert :_like in operators
    end

    test "operator_inputs returns map of input types" do
      inputs = Postgres.operator_inputs()

      assert Map.has_key?(inputs, :cql_op_id_input)
      assert Map.has_key?(inputs, :cql_op_string_input)
    end
  end

  describe "Elasticsearch adapter" do
    test "sort_directions includes special options" do
      directions = Elasticsearch.sort_directions()

      assert :asc in directions
      assert :desc in directions
      assert :_score in directions
      assert :_geo_distance in directions
    end

    test "supports_geo_ordering? returns true" do
      assert Elasticsearch.supports_geo_ordering?()
    end

    test "capabilities returns expected map" do
      caps = Elasticsearch.capabilities()

      assert caps.supports_full_text_search == true
      assert caps.supports_fuzzy_search == true
    end

    test "operator_type_for returns correct identifier" do
      assert Elasticsearch.operator_type_for(:string) == :cql_op_string_input
    end

    test "supported_operators for scalar category includes ES-specific" do
      operators = Elasticsearch.supported_operators(:scalar, :string)

      assert :_eq in operators
      assert :_match in operators
      assert :_match_phrase in operators
    end

    test "operator_inputs returns map of input types" do
      inputs = Elasticsearch.operator_inputs()

      assert Map.has_key?(inputs, :cql_op_id_input)
      assert Map.has_key?(inputs, :cql_op_string_input)
    end
  end
end
