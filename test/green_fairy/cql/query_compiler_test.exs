defmodule GreenFairy.CQL.QueryCompilerTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.QueryCompiler

  # Test schemas for compilation tests
  defmodule Organization do
    use Ecto.Schema

    schema "organizations" do
      field :name, :string
      field :status, :string
    end
  end

  defmodule User do
    use Ecto.Schema

    schema "users" do
      field :name, :string
      field :email, :string
      field :age, :integer
      field :role, :string
      belongs_to(:organization, Organization)
    end
  end

  describe "compile/4" do
    test "returns unchanged query for nil filter" do
      query = User
      assert {:ok, result} = QueryCompiler.compile(query, nil, User)
      assert result == query
    end

    test "returns unchanged query for empty filter" do
      query = User
      assert {:ok, result} = QueryCompiler.compile(query, %{}, User)
      assert result == query
    end

    test "compiles simple _eq operator" do
      query = User
      filter = %{name: %{_eq: "Alice"}}

      assert {:ok, result} = QueryCompiler.compile(query, filter, User)
      assert %Ecto.Query{} = result
    end

    test "compiles _ne operator" do
      query = User
      filter = %{name: %{_ne: "Bob"}}

      assert {:ok, result} = QueryCompiler.compile(query, filter, User)
      assert %Ecto.Query{} = result
    end

    test "compiles comparison operators" do
      query = User
      filter = %{age: %{_gt: 18, _lt: 65}}

      assert {:ok, result} = QueryCompiler.compile(query, filter, User)
      assert %Ecto.Query{} = result
    end

    test "compiles _in operator" do
      query = User
      filter = %{role: %{_in: ["admin", "moderator"]}}

      assert {:ok, result} = QueryCompiler.compile(query, filter, User)
      assert %Ecto.Query{} = result
    end

    test "compiles _nin operator" do
      query = User
      filter = %{role: %{_nin: ["banned", "suspended"]}}

      assert {:ok, result} = QueryCompiler.compile(query, filter, User)
      assert %Ecto.Query{} = result
    end

    test "compiles _is_null operator" do
      query = User

      filter_true = %{email: %{_is_null: true}}
      assert {:ok, result} = QueryCompiler.compile(query, filter_true, User)
      assert %Ecto.Query{} = result

      filter_false = %{email: %{_is_null: false}}
      assert {:ok, result} = QueryCompiler.compile(query, filter_false, User)
      assert %Ecto.Query{} = result
    end

    test "compiles _eq with nil value" do
      query = User
      filter = %{email: %{_eq: nil}}

      assert {:ok, result} = QueryCompiler.compile(query, filter, User)
      assert %Ecto.Query{} = result
    end

    test "compiles _ne with nil value" do
      query = User
      filter = %{email: %{_ne: nil}}

      assert {:ok, result} = QueryCompiler.compile(query, filter, User)
      assert %Ecto.Query{} = result
    end

    test "compiles _like operator" do
      query = User
      filter = %{name: %{_like: "A%"}}

      assert {:ok, result} = QueryCompiler.compile(query, filter, User)
      assert %Ecto.Query{} = result
    end

    test "compiles _ilike operator" do
      query = User
      filter = %{name: %{_ilike: "a%"}}

      assert {:ok, result} = QueryCompiler.compile(query, filter, User)
      assert %Ecto.Query{} = result
    end

    test "compiles multiple fields" do
      query = User
      filter = %{name: %{_eq: "Alice"}, age: %{_gte: 21}}

      assert {:ok, result} = QueryCompiler.compile(query, filter, User)
      assert %Ecto.Query{} = result
    end
  end

  describe "compile/4 with logical operators" do
    test "compiles _and operator" do
      query = User

      filter = %{
        _and: [
          %{name: %{_eq: "Alice"}},
          %{age: %{_gte: 18}}
        ]
      }

      assert {:ok, result} = QueryCompiler.compile(query, filter, User)
      assert %Ecto.Query{} = result
    end

    test "compiles _or operator" do
      query = User

      filter = %{
        _or: [
          %{name: %{_eq: "Alice"}},
          %{name: %{_eq: "Bob"}}
        ]
      }

      assert {:ok, result} = QueryCompiler.compile(query, filter, User)
      assert %Ecto.Query{} = result
    end

    test "compiles _not operator" do
      query = User

      filter = %{
        _not: %{role: %{_eq: "banned"}}
      }

      assert {:ok, result} = QueryCompiler.compile(query, filter, User)
      assert %Ecto.Query{} = result
    end

    test "compiles nested logical operators" do
      query = User

      filter = %{
        _or: [
          %{
            _and: [
              %{name: %{_eq: "Alice"}},
              %{age: %{_gte: 21}}
            ]
          },
          %{role: %{_eq: "admin"}}
        ]
      }

      assert {:ok, result} = QueryCompiler.compile(query, filter, User)
      assert %Ecto.Query{} = result
    end
  end

  describe "compile/4 with _exists validation" do
    test "returns error when _exists used at top level" do
      query = User
      filter = %{_exists: true}

      assert {:error, msg} = QueryCompiler.compile(query, filter, User, is_nested: false)
      assert msg =~ "can only be used in associated filters"
    end

    test "allows _exists at top level when is_nested: true" do
      query = User
      filter = %{_exists: true}

      assert {:ok, _result} = QueryCompiler.compile(query, filter, User, is_nested: true)
    end

    test "returns error when _exists combined with other operators" do
      query = User
      filter = %{_exists: true, name: %{_eq: "test"}}

      assert {:error, msg} = QueryCompiler.compile(query, filter, User, is_nested: true)
      assert msg =~ "cannot be combined"
    end
  end

  describe "compile!/4" do
    test "returns query on success" do
      query = User
      filter = %{name: %{_eq: "Alice"}}

      result = QueryCompiler.compile!(query, filter, User)
      assert %Ecto.Query{} = result
    end

    test "raises on validation error" do
      query = User
      filter = %{_exists: true}

      assert_raise ArgumentError, ~r/can only be used in associated filters/, fn ->
        QueryCompiler.compile!(query, filter, User, is_nested: false)
      end
    end
  end

  describe "operator lists" do
    test "comparison_operators returns expected operators" do
      ops = QueryCompiler.comparison_operators()
      assert :_eq in ops
      assert :_ne in ops
      assert :_gt in ops
      assert :_gte in ops
      assert :_lt in ops
      assert :_lte in ops
    end

    test "list_operators returns expected operators" do
      ops = QueryCompiler.list_operators()
      assert :_in in ops
      assert :_nin in ops
    end

    test "string_operators returns expected operators" do
      ops = QueryCompiler.string_operators()
      assert :_like in ops
      assert :_ilike in ops
      assert :_nlike in ops
      assert :_nilike in ops
    end

    test "null_operators returns expected operators" do
      ops = QueryCompiler.null_operators()
      assert :_is_null in ops
    end

    test "logical_operators returns expected operators" do
      ops = QueryCompiler.logical_operators()
      assert :_and in ops
      assert :_or in ops
      assert :_not in ops
    end

    test "all_operators combines all operator lists" do
      all = QueryCompiler.all_operators()
      assert :_eq in all
      assert :_in in all
      assert :_like in all
      assert :_is_null in all
      assert :_and in all
    end
  end
end
