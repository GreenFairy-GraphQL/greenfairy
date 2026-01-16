defmodule GreenFairy.Field.Association.ValidatePaginationTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Field.Association.ValidatePagination

  defp resolution(args) do
    %Absinthe.Resolution{arguments: args, state: :unresolved, value: nil, errors: []}
  end

  describe "call/2 - limit validation" do
    test "passes when limit is nil" do
      res = resolution(%{limit: nil})

      result = ValidatePagination.call(res, [])

      assert result.state == :unresolved
      assert result.errors == []
    end

    test "passes when limit is within default max (100)" do
      res = resolution(%{limit: 50})

      result = ValidatePagination.call(res, [])

      assert result.state == :unresolved
      assert result.errors == []
    end

    test "passes when limit equals max limit" do
      res = resolution(%{limit: 100})

      result = ValidatePagination.call(res, [])

      assert result.state == :unresolved
    end

    test "passes when limit is within custom max limit" do
      res = resolution(%{limit: 500})

      result = ValidatePagination.call(res, max_limit: 1000)

      assert result.state == :unresolved
    end

    test "fails when limit exceeds default max (100)" do
      res = resolution(%{limit: 150})

      result = ValidatePagination.call(res, [])

      assert result.state == :resolved
      assert "limit cannot exceed 100" in result.errors
    end

    test "fails when limit exceeds custom max limit" do
      res = resolution(%{limit: 250})

      result = ValidatePagination.call(res, max_limit: 200)

      assert result.state == :resolved
      assert "limit cannot exceed 200" in result.errors
    end

    test "fails when limit is 0" do
      res = resolution(%{limit: 0})

      result = ValidatePagination.call(res, [])

      assert result.state == :resolved
      assert "limit must be greater than 0" in result.errors
    end

    test "fails when limit is negative" do
      res = resolution(%{limit: -5})

      result = ValidatePagination.call(res, [])

      assert result.state == :resolved
      assert "limit must be greater than 0" in result.errors
    end

    test "fails when limit is not an integer" do
      res = resolution(%{limit: "50"})

      result = ValidatePagination.call(res, [])

      assert result.state == :resolved
      assert "limit must be an integer" in result.errors
    end

    test "fails when limit is a float" do
      res = resolution(%{limit: 50.5})

      result = ValidatePagination.call(res, [])

      assert result.state == :resolved
      assert "limit must be an integer" in result.errors
    end
  end

  describe "call/2 - offset validation" do
    test "passes when offset is nil" do
      res = resolution(%{offset: nil})

      result = ValidatePagination.call(res, [])

      assert result.state == :unresolved
    end

    test "passes when offset is 0" do
      res = resolution(%{offset: 0})

      result = ValidatePagination.call(res, [])

      assert result.state == :unresolved
    end

    test "passes when offset is within default max (10000)" do
      res = resolution(%{offset: 5000})

      result = ValidatePagination.call(res, [])

      assert result.state == :unresolved
    end

    test "passes when offset equals max offset" do
      res = resolution(%{offset: 10000})

      result = ValidatePagination.call(res, [])

      assert result.state == :unresolved
    end

    test "passes when offset is within custom max offset" do
      res = resolution(%{offset: 50000})

      result = ValidatePagination.call(res, max_offset: 100_000)

      assert result.state == :unresolved
    end

    test "fails when offset exceeds default max (10000)" do
      res = resolution(%{offset: 15000})

      result = ValidatePagination.call(res, [])

      assert result.state == :resolved
      assert "offset cannot exceed 10000" in result.errors
    end

    test "fails when offset exceeds custom max offset" do
      res = resolution(%{offset: 250})

      result = ValidatePagination.call(res, max_offset: 200)

      assert result.state == :resolved
      assert "offset cannot exceed 200" in result.errors
    end

    test "fails when offset is negative" do
      res = resolution(%{offset: -1})

      result = ValidatePagination.call(res, [])

      assert result.state == :resolved
      assert "offset must be greater than or equal to 0" in result.errors
    end

    test "fails when offset is not an integer" do
      res = resolution(%{offset: "100"})

      result = ValidatePagination.call(res, [])

      assert result.state == :resolved
      assert "offset must be an integer" in result.errors
    end

    test "fails when offset is a float" do
      res = resolution(%{offset: 100.5})

      result = ValidatePagination.call(res, [])

      assert result.state == :resolved
      assert "offset must be an integer" in result.errors
    end
  end

  describe "call/2 - combined limit and offset" do
    test "passes with valid limit and offset" do
      res = resolution(%{limit: 25, offset: 100})

      result = ValidatePagination.call(res, [])

      assert result.state == :unresolved
    end

    test "fails on limit before checking offset" do
      res = resolution(%{limit: 500, offset: 50000})

      result = ValidatePagination.call(res, [])

      # Limit is checked first
      assert result.state == :resolved
      assert "limit cannot exceed 100" in result.errors
    end

    test "fails on offset when limit is valid" do
      res = resolution(%{limit: 50, offset: 50000})

      result = ValidatePagination.call(res, [])

      assert result.state == :resolved
      assert "offset cannot exceed 10000" in result.errors
    end

    test "passes with custom max_limit and max_offset" do
      res = resolution(%{limit: 500, offset: 50000})

      result = ValidatePagination.call(res, max_limit: 1000, max_offset: 100_000)

      assert result.state == :unresolved
    end
  end
end
