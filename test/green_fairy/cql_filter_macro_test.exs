defmodule GreenFairy.CQLFilterMacroTest do
  @moduledoc """
  Tests for the `filter` macro in CQL.

  The `filter` macro allows defining custom filters that are NOT schema fields,
  with an `apply` function that handles all filter logic.
  """
  use ExUnit.Case, async: false

  import Ecto.Query

  # Test schema for filter tests
  defmodule TestWorker do
    defstruct [:id, :name, :birthdate, :email]

    def __schema__(:source), do: "workers"
    def __schema__(:prefix), do: nil
    def __schema__(:fields), do: [:id, :name, :birthdate, :email]
    def __schema__(:primary_key), do: [:id]
    def __schema__(:associations), do: []
    def __schema__(:embeds), do: []

    def __schema__(:type, :id), do: :id
    def __schema__(:type, :name), do: :string
    def __schema__(:type, :birthdate), do: :date
    def __schema__(:type, :email), do: :string
    def __schema__(:association, _field), do: nil
  end

  defmodule TestWorkerType do
    use GreenFairy.Type
    import Ecto.Query

    alias GreenFairy.CQLFilterMacroTest.TestWorker

    type "Worker", struct: TestWorker do
      field :id, non_null(:id)
      field :name, :string
      field :birthdate, :date

      # Pattern 1: Boolean filter with custom constraint
      filter(:worker_over18, :boolean,
        apply: fn query, op, value, _ctx ->
          case {op, value} do
            {:eq, true} ->
              {:ok, where(query, [w], w.birthdate <= fragment("CURRENT_DATE - interval '18 years'"))}

            {:eq, false} ->
              {:ok, where(query, [w], w.birthdate > fragment("CURRENT_DATE - interval '18 years'"))}

            _ ->
              {:ok, query}
          end
        end,
        description: "Whether the worker is over 18 years of age"
      )

      # Pattern 2: String filter with custom logic
      filter(:name_prefix, :string,
        apply: fn query, op, value, _ctx ->
          case op do
            :eq ->
              pattern = "#{value}%"
              {:ok, where(query, [w], like(w.name, ^pattern))}

            :contains ->
              pattern = "%#{value}%"
              {:ok, where(query, [w], like(w.name, ^pattern))}

            _ ->
              {:ok, query}
          end
        end
      )

      # Pattern 3: Hidden filter (not in schema)
      filter(:internal_flag, :boolean,
        apply: fn query, _op, _value, _ctx -> {:ok, query} end,
        hidden: true
      )
    end
  end

  describe "filter macro registration" do
    test "type has __cql_filters__ function" do
      assert function_exported?(TestWorkerType, :__cql_filters__, 0)
    end

    test "__cql_filters__ returns map of filter configs" do
      filters = TestWorkerType.__cql_filters__()

      assert is_map(filters)
      assert Map.has_key?(filters, :worker_over18)
      assert Map.has_key?(filters, :name_prefix)
      assert Map.has_key?(filters, :internal_flag)
    end

    test "filter config contains expected fields" do
      filters = TestWorkerType.__cql_filters__()
      worker_filter = filters[:worker_over18]

      assert worker_filter.field == :worker_over18
      assert worker_filter.type == :boolean
      assert is_function(worker_filter.apply_fn)
      assert worker_filter.description == "Whether the worker is over 18 years of age"
      assert worker_filter.hidden == false
    end

    test "hidden filters are marked as hidden" do
      filters = TestWorkerType.__cql_filters__()
      internal_filter = filters[:internal_flag]

      assert internal_filter.hidden == true
    end

    test "filter fields are included in filterable fields" do
      fields = TestWorkerType.__cql_filterable_fields__()

      assert :worker_over18 in fields
      assert :name_prefix in fields
      assert :internal_flag in fields
    end
  end

  describe "filter input generation" do
    test "non-hidden filter fields appear in filter_fields" do
      filter_fields = TestWorkerType.__cql_filter_fields__()
      field_names = Enum.map(filter_fields, fn {name, _type} -> name end)

      assert :worker_over18 in field_names
      assert :name_prefix in field_names
      # Hidden filters should NOT appear in filter_fields (used for GraphQL schema)
      refute :internal_flag in field_names
    end

    test "filter fields have their types set" do
      filter_fields = TestWorkerType.__cql_filter_fields__()
      filter_map = Map.new(filter_fields)

      assert filter_map[:worker_over18] == :boolean
      assert filter_map[:name_prefix] == :string
    end
  end

  describe "query compilation with filters" do
    test "compile applies custom filter function" do
      filter = %{worker_over18: %{_eq: true}}
      query = from(w in TestWorker)

      {:ok, result} =
        GreenFairy.CQL.QueryCompiler.compile(
          query,
          filter,
          TestWorker,
          adapter: GreenFairy.Adapters.Ecto,
          type_module: TestWorkerType
        )

      # The result should have a where clause
      assert result.wheres != []
    end

    test "compile handles multiple operators on custom filter" do
      filter = %{name_prefix: %{_eq: "John"}}
      query = from(w in TestWorker)

      {:ok, result} =
        GreenFairy.CQL.QueryCompiler.compile(
          query,
          filter,
          TestWorker,
          adapter: GreenFairy.Adapters.Ecto,
          type_module: TestWorkerType
        )

      assert result.wheres != []
    end

    test "compile passes context to apply function" do
      # Create a filter that captures context
      defmodule ContextTestWorkerType do
        use GreenFairy.Type
        import Ecto.Query

        alias GreenFairy.CQLFilterMacroTest.TestWorker

        type "ContextTestWorker", struct: TestWorker do
          field :id, non_null(:id)

          filter(:with_context, :boolean,
            apply: fn query, _op, _value, ctx ->
              # Context should have args, context, and parent_alias
              if Map.has_key?(ctx, :args) and Map.has_key?(ctx, :context) do
                {:ok, query}
              else
                {:error, "Missing context"}
              end
            end
          )
        end
      end

      filter = %{with_context: %{_eq: true}}
      query = from(w in TestWorker)

      {:ok, _result} =
        GreenFairy.CQL.QueryCompiler.compile(
          query,
          filter,
          TestWorker,
          adapter: GreenFairy.Adapters.Ecto,
          type_module: ContextTestWorkerType,
          args: %{foo: "bar"},
          context: %{current_user: nil}
        )
    end

    test "compile handles error return from apply function" do
      defmodule ErrorTestWorkerType do
        use GreenFairy.Type

        alias GreenFairy.CQLFilterMacroTest.TestWorker

        type "ErrorTestWorker", struct: TestWorker do
          field :id, non_null(:id)

          filter(:always_error, :boolean,
            apply: fn query, _op, _value, _ctx ->
              {:error, "Always fails"}
            end
          )
        end
      end

      filter = %{always_error: %{_eq: true}}
      query = from(w in TestWorker)

      # Should still succeed, but query is unchanged
      {:ok, result} =
        GreenFairy.CQL.QueryCompiler.compile(
          query,
          filter,
          TestWorker,
          adapter: GreenFairy.Adapters.Ecto,
          type_module: ErrorTestWorkerType
        )

      # Query should be unchanged (no where clauses added)
      assert result.wheres == []
    end
  end

  describe "operator normalization" do
    test "operators with underscores are normalized" do
      defmodule NormTestWorkerType do
        use GreenFairy.Type
        import Ecto.Query

        alias GreenFairy.CQLFilterMacroTest.TestWorker

        type "NormTestWorker", struct: TestWorker do
          field :id, non_null(:id)

          # Filter that tracks which operator it receives
          filter(:check_op, :boolean,
            apply: fn query, op, _value, _ctx ->
              # The op should be normalized (no leading underscore)
              if op == :eq do
                {:ok, where(query, [w], w.id == 1)}
              else
                {:ok, query}
              end
            end
          )
        end
      end

      # Input has _eq with underscore
      filter = %{check_op: %{_eq: true}}
      query = from(w in TestWorker)

      {:ok, result} =
        GreenFairy.CQL.QueryCompiler.compile(
          query,
          filter,
          TestWorker,
          adapter: GreenFairy.Adapters.Ecto,
          type_module: NormTestWorkerType
        )

      # Filter should have been applied (op was normalized to :eq)
      assert result.wheres != []
    end
  end
end
