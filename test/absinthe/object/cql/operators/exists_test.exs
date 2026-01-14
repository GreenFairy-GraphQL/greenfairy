defmodule Absinthe.Object.CQL.Operators.ExistsTest do
  use ExUnit.Case, async: true

  alias Absinthe.Object.CQL.Operators.Exists

  describe "validate_exists_usage/2" do
    test "returns :ok when _exists is not present" do
      filter = %{name: %{_eq: "test"}}
      assert Exists.validate_exists_usage(filter) == :ok
    end

    test "returns :ok when _exists is used alone in nested context" do
      filter = %{_exists: true}
      assert Exists.validate_exists_usage(filter, is_nested: true) == :ok
    end

    test "returns error when _exists used at top level" do
      filter = %{_exists: true}
      assert {:error, msg} = Exists.validate_exists_usage(filter, is_nested: false)
      assert msg =~ "can only be used in associated filters"
    end

    test "returns error when _exists combined with other operators" do
      filter = %{_exists: true, name: %{_eq: "test"}}
      assert {:error, msg} = Exists.validate_exists_usage(filter, is_nested: true)
      assert msg =~ "cannot be combined with other operators"
    end
  end

  describe "validate_exists_in_logical_operator/2" do
    test "returns :ok when filters don't contain _exists directly" do
      filters = [
        %{name: %{_eq: "test"}},
        %{status: %{_eq: "active"}}
      ]

      assert Exists.validate_exists_in_logical_operator(filters, :_or) == :ok
    end

    test "returns :ok when _exists is nested in association" do
      filters = [
        %{organization: %{_exists: true}},
        %{name: %{_eq: "test"}}
      ]

      assert Exists.validate_exists_in_logical_operator(filters, :_or) == :ok
    end

    test "returns error when _exists is direct member of logical operator" do
      filters = [
        %{_exists: true},
        %{name: %{_eq: "test"}}
      ]

      assert {:error, msg} = Exists.validate_exists_in_logical_operator(filters, :_or)
      assert msg =~ "cannot be used as a direct member of `_or`"
    end

    test "returns error with correct operator name for _and" do
      filters = [
        %{_exists: false},
        %{status: %{_eq: "active"}}
      ]

      assert {:error, msg} = Exists.validate_exists_in_logical_operator(filters, :_and)
      assert msg =~ "cannot be used as a direct member of `_and`"
    end
  end
end
