defmodule GreenFairy.CQLAdapterTestHelper do
  @moduledoc """
  Shared test helpers for CQL adapter tests.

  Provides common test utilities for testing database adapters:
  - Mock Ecto.Query generation
  - SQL fragment inspection
  - Common test scenarios
  """

  import Ecto.Query
  import ExUnit.Assertions

  @doc """
  Creates a base Ecto query for testing.
  """
  def base_query(schema \\ __MODULE__.User) do
    from(u in schema)
  end

  @doc """
  Extracts the WHERE fragment from an Ecto.Query for inspection.
  """
  def get_where_fragment(query) do
    case query.wheres do
      [] -> nil
      [%{expr: expr}] -> expr
      [%{expr: expr} | _] -> expr
    end
  end

  @doc """
  Extracts all WHERE fragments from an Ecto.Query.
  """
  def get_all_where_fragments(query) do
    Enum.map(query.wheres, fn %{expr: expr} -> expr end)
  end

  @doc """
  Checks if a query contains a fragment with the given SQL pattern.
  """
  def has_fragment?(query, pattern) do
    query.wheres
    |> Enum.any?(fn where ->
      case where.expr do
        {:fragment, _, fragments} ->
          Enum.any?(fragments, fn
            {:raw, sql} -> String.contains?(sql, pattern)
            _ -> false
          end)

        _ ->
          false
      end
    end)
  end

  @doc """
  Checks if a query has WHERE clauses.
  """
  def has_where?(query) do
    query.wheres != []
  end

  @doc """
  Test that an adapter implements all required behavior callbacks.
  """
  def assert_adapter_behavior(adapter_module) do
    Code.ensure_loaded!(adapter_module)
    assert function_exported?(adapter_module, :supported_operators, 2)
    assert function_exported?(adapter_module, :apply_operator, 5)
    assert function_exported?(adapter_module, :capabilities, 0)
  end

  @doc """
  Test that an operator is supported for a given category.
  """
  def assert_operator_supported(adapter, category, operator) do
    operators = adapter.supported_operators(category, :string)
    assert operator in operators,
           "Expected #{inspect(operator)} to be in #{inspect(operators)} for #{category}"
  end

  @doc """
  Test that an operator is NOT supported for a given category.
  """
  def refute_operator_supported(adapter, category, operator) do
    operators = adapter.supported_operators(category, :string)
    refute operator in operators,
           "Expected #{inspect(operator)} to NOT be in #{inspect(operators)} for #{category}"
  end

  @doc """
  Test that applying an operator creates a valid query.
  """
  def assert_query_valid(query, field, operator, value, adapter, opts \\ []) do
    result = adapter.apply_operator(query, field, operator, value, opts)
    assert %Ecto.Query{} = result
    assert has_where?(result), "Expected query to have WHERE clause"
    result
  end

  @doc """
  Mock User schema for testing.
  """
  defmodule User do
    use Ecto.Schema

    schema "users" do
      field :name, :string
      field :email, :string
      field :age, :integer
      field :active, :boolean
      field :tags, {:array, :string}
      field :role_ids, {:array, :integer}
      field :metadata, :map
      field :inserted_at, :naive_datetime
    end
  end

  @doc """
  Mock Post schema for testing associations.
  """
  defmodule Post do
    use Ecto.Schema

    schema "posts" do
      field :title, :string
      field :body, :string
      field :status, :string
      field :tags, {:array, :string}
      belongs_to :user, GreenFairy.CQLAdapterTestHelper.User
    end
  end

  @doc """
  Common scalar operator test scenarios.
  Returns a list of {operator, value, description} tuples.
  """
  def scalar_test_scenarios do
    [
      {:_eq, "test", "equality"},
      {:_neq, "test", "not equal"},
      {:_gt, 10, "greater than"},
      {:_gte, 10, "greater than or equal"},
      {:_lt, 10, "less than"},
      {:_lte, 10, "less than or equal"},
      {:_in, ["a", "b", "c"], "in list"},
      {:_nin, ["a", "b"], "not in list"},
      {:_is_null, true, "is null"},
      {:_is_null, false, "is not null"}
    ]
  end

  @doc """
  Common string operator test scenarios.
  """
  def string_test_scenarios do
    [
      {:_like, "%test%", "like pattern"},
      {:_nlike, "%test%", "not like pattern"},
      {:_ilike, "%test%", "case-insensitive like"},
      {:_nilike, "%test%", "not case-insensitive like"},
      {:_starts_with, "prefix", "starts with"},
      {:_istarts_with, "prefix", "case-insensitive starts with"},
      {:_ends_with, "suffix", "ends with"},
      {:_iends_with, "suffix", "case-insensitive ends with"},
      {:_contains, "substring", "contains"},
      {:_icontains, "substring", "case-insensitive contains"}
    ]
  end

  @doc """
  Common array operator test scenarios.
  """
  def array_test_scenarios do
    [
      {:_includes, "tag1", "includes single value"},
      {:_excludes, "tag1", "excludes single value"},
      {:_includes_all, ["tag1", "tag2"], "includes all values"},
      {:_includes_any, ["tag1", "tag2"], "includes any value"},
      {:_is_empty, true, "is empty"},
      {:_is_empty, false, "is not empty"}
    ]
  end

  @doc """
  Verify that a query was modified (has WHERE clauses).
  """
  def assert_query_modified(original_query, modified_query) do
    original_where_count = length(original_query.wheres)
    modified_where_count = length(modified_query.wheres)

    assert modified_where_count > original_where_count,
           "Expected query to be modified. Original: #{original_where_count}, Modified: #{modified_where_count}"
  end
end
