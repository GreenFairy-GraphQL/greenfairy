defmodule GreenFairy.CQL.QueryFieldTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.QueryField

  describe "new/1" do
    test "creates query field with required options" do
      field = QueryField.new(field: :name, field_type: :string)

      assert %QueryField{} = field
      assert field.field == :name
      assert field.field_type == :string
      assert field.column == :name
      assert field.hidden == false
      assert field.allow_in_nested == true
    end

    test "creates query field with custom column" do
      field = QueryField.new(field: :name, field_type: :string, column: :full_name)

      assert field.column == :full_name
    end

    test "creates query field with description" do
      field =
        QueryField.new(
          field: :email,
          field_type: :string,
          description: "User's email address"
        )

      assert field.description == "User's email address"
    end

    test "creates hidden field" do
      field = QueryField.new(field: :password, field_type: :string, hidden: true)

      assert field.hidden == true
    end

    test "creates field with custom operators" do
      field =
        QueryField.new(
          field: :name,
          field_type: :string,
          operators: [:eq, :contains]
        )

      assert field.operators == [:eq, :contains]
    end

    test "creates field with custom constraint" do
      constraint_fn = fn query, _value -> query end

      field =
        QueryField.new(
          field: :name,
          field_type: :string,
          custom_constraint: constraint_fn
        )

      assert field.custom_constraint == constraint_fn
    end

    test "creates field with allow_in_nested false" do
      field =
        QueryField.new(
          field: :computed,
          field_type: :string,
          allow_in_nested: false
        )

      assert field.allow_in_nested == false
    end

    test "supports all basic types" do
      types = [
        :string,
        :integer,
        :float,
        :decimal,
        :boolean,
        :datetime,
        :date,
        :time,
        :id,
        :binary_id,
        :location,
        :geo_point,
        :money,
        :duration
      ]

      for type <- types do
        field = QueryField.new(field: :test, field_type: type)
        assert field.field_type == type
      end
    end

    test "supports array types" do
      array_types = [{:array, :id}, {:array, :string}, {:array, :integer}, {:array, :datetime}]

      for type <- array_types do
        field = QueryField.new(field: :test, field_type: type)
        assert field.field_type == type
      end
    end

    test "raises for invalid field type" do
      assert_raise ArgumentError, ~r/Invalid field_type/, fn ->
        QueryField.new(field: :test, field_type: :invalid_type)
      end
    end
  end

  describe "valid_types/0" do
    test "returns list of valid types" do
      types = QueryField.valid_types()

      assert :string in types
      assert :integer in types
      assert :datetime in types
      assert {:array, :id} in types
    end
  end

  describe "allowed_in_nested?/1" do
    test "returns true for normal fields" do
      field = QueryField.new(field: :name, field_type: :string)

      assert QueryField.allowed_in_nested?(field) == true
    end

    test "returns false for fields with allow_in_nested: false" do
      field = QueryField.new(field: :name, field_type: :string, allow_in_nested: false)

      assert QueryField.allowed_in_nested?(field) == false
    end

    test "returns false for fields with custom constraints" do
      field =
        QueryField.new(
          field: :name,
          field_type: :string,
          custom_constraint: fn q, _v -> q end
        )

      assert QueryField.allowed_in_nested?(field) == false
    end
  end

  describe "default_operators/1" do
    test "returns operators for string type" do
      ops = QueryField.default_operators(:string)

      assert :eq in ops
      assert :contains in ops
      assert :starts_with in ops
    end

    test "returns operators for integer type" do
      ops = QueryField.default_operators(:integer)

      assert :eq in ops
      assert :gt in ops
      assert :lt in ops
      assert :in in ops
    end

    test "returns operators for datetime type" do
      ops = QueryField.default_operators(:datetime)

      assert :eq in ops
      assert :gt in ops
      assert :between in ops
    end

    test "returns operators for boolean type" do
      ops = QueryField.default_operators(:boolean)

      assert :eq in ops
      assert :neq in ops
      assert :is_nil in ops
      refute :gt in ops
    end

    test "returns operators for geo types" do
      ops = QueryField.default_operators(:geo_point)

      assert :st_dwithin in ops
      assert :st_within_bounding_box in ops
    end

    test "returns operators for array types" do
      ops = QueryField.default_operators({:array, :string})

      assert :includes in ops
      assert :excludes in ops
      assert :is_empty in ops
    end

    test "returns basic operators for unknown types" do
      ops = QueryField.default_operators(:unknown)

      assert :eq in ops
      assert :in in ops
    end
  end
end
