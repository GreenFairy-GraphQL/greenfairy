defmodule GreenFairy.CQL.QueryFieldTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.QueryField

  describe "new/1" do
    test "creates QueryField with required options" do
      field = QueryField.new(field: :name, field_type: :string)

      assert %QueryField{} = field
      assert field.field == :name
      assert field.field_type == :string
      assert field.column == :name
      assert field.hidden == false
      assert field.allow_in_nested == true
    end

    test "accepts custom column name" do
      field = QueryField.new(field: :name, field_type: :string, column: :full_name)

      assert field.column == :full_name
    end

    test "accepts description" do
      field = QueryField.new(field: :name, field_type: :string, description: "User's name")

      assert field.description == "User's name"
    end

    test "accepts hidden option" do
      field = QueryField.new(field: :secret, field_type: :string, hidden: true)

      assert field.hidden == true
    end

    test "accepts operators option" do
      field = QueryField.new(field: :status, field_type: :string, operators: [:eq, :neq])

      assert field.operators == [:eq, :neq]
    end

    test "accepts custom_constraint function" do
      constraint_fn = fn query, _value -> query end
      field = QueryField.new(field: :custom, field_type: :string, custom_constraint: constraint_fn)

      assert field.custom_constraint == constraint_fn
    end

    test "accepts array field types" do
      field = QueryField.new(field: :tags, field_type: {:array, :string})

      assert field.field_type == {:array, :string}
    end

    test "raises for invalid field type" do
      assert_raise ArgumentError, ~r/Invalid field_type/, fn ->
        QueryField.new(field: :invalid, field_type: :unknown_type)
      end
    end
  end

  describe "valid_types/0" do
    test "returns list of valid types" do
      types = QueryField.valid_types()

      assert is_list(types)
      assert :string in types
      assert :integer in types
      assert :datetime in types
      assert {:array, :string} in types
    end
  end

  describe "allowed_in_nested?/1" do
    test "returns true for regular fields" do
      field = QueryField.new(field: :name, field_type: :string)

      assert QueryField.allowed_in_nested?(field) == true
    end

    test "returns false when allow_in_nested is false" do
      field = QueryField.new(field: :name, field_type: :string, allow_in_nested: false)

      assert QueryField.allowed_in_nested?(field) == false
    end

    test "returns false when custom_constraint is set" do
      constraint_fn = fn query, _value -> query end
      field = QueryField.new(field: :custom, field_type: :string, custom_constraint: constraint_fn)

      assert QueryField.allowed_in_nested?(field) == false
    end
  end

  describe "default_operators/1" do
    test "returns operators for :string" do
      ops = QueryField.default_operators(:string)
      assert :eq in ops
      assert :contains in ops
    end

    test "returns operators for :integer" do
      ops = QueryField.default_operators(:integer)
      assert :eq in ops
      assert :gt in ops
      assert :lt in ops
    end

    test "returns operators for :boolean" do
      ops = QueryField.default_operators(:boolean)
      assert :eq in ops
      assert :neq in ops
    end

    test "returns operators for :datetime" do
      ops = QueryField.default_operators(:datetime)
      assert :eq in ops
      assert :between in ops
    end

    test "returns operators for :date" do
      ops = QueryField.default_operators(:date)
      assert :eq in ops
      assert :gt in ops
    end

    test "returns operators for :time" do
      ops = QueryField.default_operators(:time)
      assert :eq in ops
    end

    test "returns operators for :id" do
      ops = QueryField.default_operators(:id)
      assert :eq in ops
      assert :in in ops
    end

    test "returns operators for :binary_id" do
      ops = QueryField.default_operators(:binary_id)
      assert :eq in ops
    end

    test "returns operators for :location" do
      ops = QueryField.default_operators(:location)
      assert :st_dwithin in ops
    end

    test "returns operators for :geo_point" do
      ops = QueryField.default_operators(:geo_point)
      assert :st_within_bounding_box in ops
    end

    test "returns operators for :float" do
      ops = QueryField.default_operators(:float)
      assert :gt in ops
    end

    test "returns operators for :decimal" do
      ops = QueryField.default_operators(:decimal)
      assert :lte in ops
    end

    test "returns operators for :money" do
      ops = QueryField.default_operators(:money)
      assert :eq in ops
    end

    test "returns operators for :duration" do
      ops = QueryField.default_operators(:duration)
      assert :neq in ops
    end

    test "returns operators for array types" do
      ops = QueryField.default_operators({:array, :string})
      assert :includes in ops
      assert :excludes in ops
      assert :is_empty in ops
    end

    test "returns default operators for unknown types" do
      ops = QueryField.default_operators(:unknown)
      assert :eq in ops
      assert :in in ops
      assert :is_nil in ops
    end
  end
end
