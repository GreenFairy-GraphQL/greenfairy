defmodule GreenFairy.Field.ConnectionAggregateTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Field.ConnectionAggregate

  describe "infer_aggregates/1" do
    test "infers all operations for numeric fields" do
      fields = [
        %{name: :amount, type: :integer, opts: [], resolver: false},
        %{name: :price, type: :float, opts: [], resolver: false},
        %{name: :total, type: :decimal, opts: [], resolver: false}
      ]

      {aggregates, field_types} = ConnectionAggregate.infer_aggregates(fields)

      assert aggregates.sum == [:amount, :price, :total]
      assert aggregates.avg == [:amount, :price, :total]
      assert aggregates.min == [:amount, :price, :total]
      assert aggregates.max == [:amount, :price, :total]
      assert field_types == %{amount: :integer, price: :float, total: :decimal}
    end

    test "infers only min/max for temporal fields" do
      fields = [
        %{name: :created_at, type: :datetime, opts: [], resolver: false},
        %{name: :start_date, type: :date, opts: [], resolver: false},
        %{name: :start_time, type: :time, opts: [], resolver: false},
        %{name: :naive_ts, type: :naive_datetime, opts: [], resolver: false},
        %{name: :utc_ts, type: :utc_datetime, opts: [], resolver: false}
      ]

      {aggregates, field_types} = ConnectionAggregate.infer_aggregates(fields)

      assert aggregates.sum == []
      assert aggregates.avg == []
      assert aggregates.min == [:created_at, :start_date, :start_time, :naive_ts, :utc_ts]
      assert aggregates.max == [:created_at, :start_date, :start_time, :naive_ts, :utc_ts]
      assert field_types[:created_at] == :datetime
      assert field_types[:start_date] == :date
    end

    test "excludes string, boolean, id, and custom types" do
      fields = [
        %{name: :name, type: :string, opts: [], resolver: false},
        %{name: :active, type: :boolean, opts: [], resolver: false},
        %{name: :id, type: :id, opts: [], resolver: false},
        %{name: :status, type: :custom_enum, opts: [], resolver: false}
      ]

      {aggregates, _field_types} = ConnectionAggregate.infer_aggregates(fields)

      assert aggregates == nil
    end

    test "excludes fields with resolver: true" do
      fields = [
        %{name: :amount, type: :float, opts: [], resolver: true},
        %{name: :price, type: :float, opts: [], resolver: false}
      ]

      {aggregates, field_types} = ConnectionAggregate.infer_aggregates(fields)

      assert aggregates.sum == [:price]
      assert aggregates.avg == [:price]
      refute Map.has_key?(field_types, :amount)
    end

    test "excludes fields with aggregate: false" do
      fields = [
        %{name: :amount, type: :float, opts: [aggregate: false], resolver: false},
        %{name: :price, type: :float, opts: [], resolver: false}
      ]

      {aggregates, field_types} = ConnectionAggregate.infer_aggregates(fields)

      assert aggregates.sum == [:price]
      assert aggregates.avg == [:price]
      refute Map.has_key?(field_types, :amount)
    end

    test "returns nil aggregates when no aggregatable fields" do
      fields = [
        %{name: :name, type: :string, opts: [], resolver: false},
        %{name: :active, type: :boolean, opts: [], resolver: false}
      ]

      {aggregates, _field_types} = ConnectionAggregate.infer_aggregates(fields)

      assert aggregates == nil
    end

    test "returns nil aggregates for empty fields" do
      {aggregates, field_types} = ConnectionAggregate.infer_aggregates([])

      assert aggregates == nil
      assert field_types == %{}
    end

    test "handles mixed numeric and temporal fields" do
      fields = [
        %{name: :hours_worked, type: :float, opts: [], resolver: false},
        %{name: :total_pay, type: :decimal, opts: [], resolver: false},
        %{name: :start_time, type: :datetime, opts: [], resolver: false},
        %{name: :name, type: :string, opts: [], resolver: false}
      ]

      {aggregates, field_types} = ConnectionAggregate.infer_aggregates(fields)

      assert aggregates.sum == [:hours_worked, :total_pay]
      assert aggregates.avg == [:hours_worked, :total_pay]
      assert aggregates.min == [:hours_worked, :total_pay, :start_time]
      assert aggregates.max == [:hours_worked, :total_pay, :start_time]
      assert field_types[:hours_worked] == :float
      assert field_types[:start_time] == :datetime
      assert field_types[:name] == :string
    end
  end

  describe "generate_aggregate_types/3" do
    test "generates types for all aggregate operations" do
      aggregates = %{
        sum: [:amount, :quantity],
        avg: [:price, :discount],
        min: [:created_at],
        max: [:updated_at]
      }

      result = ConnectionAggregate.generate_aggregate_types(:orders, :order, aggregates)

      # Should generate 5 types: main + sum + avg + min + max
      assert length(result) == 5
    end

    test "generates types only for non-empty operations" do
      aggregates = %{
        sum: [:amount],
        avg: [],
        min: [],
        max: []
      }

      result = ConnectionAggregate.generate_aggregate_types(:orders, :order, aggregates)

      # Should generate 2 types: main + sum
      assert length(result) == 2
    end

    test "generates main type even with no operations" do
      aggregates = %{
        sum: [],
        avg: [],
        min: [],
        max: []
      }

      result = ConnectionAggregate.generate_aggregate_types(:orders, :order, aggregates)

      # Should generate 1 type: main only
      assert length(result) == 1
    end

    test "returns quoted AST" do
      aggregates = %{
        sum: [:amount],
        avg: [],
        min: [],
        max: []
      }

      result = ConnectionAggregate.generate_aggregate_types(:orders, :order, aggregates)

      # Each result should be a quoted block
      Enum.each(result, fn quoted ->
        assert is_tuple(quoted)
      end)
    end
  end

  describe "resolve_aggregate_field/3" do
    test "executes deferred function and returns result" do
      parent = %{_sum_fns: %{amount: fn -> 100 end}}

      {:ok, result} = ConnectionAggregate.resolve_aggregate_field(parent, :_sum_fns, :amount)

      assert result == 100
    end

    test "returns value directly when not a function" do
      parent = %{sum: %{amount: 100}}

      {:ok, result} = ConnectionAggregate.resolve_aggregate_field(parent, :sum, :amount)

      assert result == 100
    end

    test "returns nil when field map key not present" do
      parent = %{other: %{}}

      {:ok, result} = ConnectionAggregate.resolve_aggregate_field(parent, :_sum_fns, :amount)

      assert result == nil
    end

    test "returns nil when field name not in map" do
      parent = %{_sum_fns: %{other: 50}}

      {:ok, result} = ConnectionAggregate.resolve_aggregate_field(parent, :_sum_fns, :amount)

      assert result == nil
    end

    test "handles avg aggregates" do
      parent = %{_avg_fns: %{rating: fn -> 4.5 end}}

      {:ok, result} = ConnectionAggregate.resolve_aggregate_field(parent, :_avg_fns, :rating)

      assert result == 4.5
    end

    test "handles min aggregates" do
      parent = %{_min_fns: %{created_at: fn -> ~D[2024-01-01] end}}

      {:ok, result} = ConnectionAggregate.resolve_aggregate_field(parent, :_min_fns, :created_at)

      assert result == ~D[2024-01-01]
    end

    test "handles max aggregates" do
      parent = %{_max_fns: %{updated_at: fn -> ~D[2024-12-31] end}}

      {:ok, result} = ConnectionAggregate.resolve_aggregate_field(parent, :_max_fns, :updated_at)

      assert result == ~D[2024-12-31]
    end
  end

  describe "generate_aggregate_types/4 with field_types" do
    test "uses original types for min/max fields" do
      aggregates = %{
        sum: [:amount],
        avg: [:amount],
        min: [:amount, :created_at],
        max: [:amount, :created_at]
      }

      field_types = %{amount: :float, created_at: :datetime}

      result = ConnectionAggregate.generate_aggregate_types(:orders, :order, aggregates, field_types)

      # Should generate 5 types: main + sum + avg + min + max
      assert length(result) == 5
    end

    test "falls back to :string for min/max when no field_types" do
      aggregates = %{
        sum: [],
        avg: [],
        min: [:created_at],
        max: [:updated_at]
      }

      result = ConnectionAggregate.generate_aggregate_types(:orders, :order, aggregates)

      # Should generate 3 types: main + min + max
      assert length(result) == 3
    end
  end

  describe "compute_aggregates/2" do
    defmodule MockAggregateRepo do
      def aggregate(_query, :sum, :amount), do: 1000
      def aggregate(_query, :sum, :quantity), do: 50
      def aggregate(_query, :avg, :price), do: 20.0
      def aggregate(_query, :avg, :rating), do: 4.5
      def aggregate(_query, :min, :created_at), do: ~D[2024-01-01]
      def aggregate(_query, :max, :updated_at), do: ~D[2024-12-31]
    end

    defmodule AggregateItem do
      use Ecto.Schema

      schema "items" do
        field :amount, :integer
        field :quantity, :integer
        field :price, :float
        field :rating, :float
        field :created_at, :date
        field :updated_at, :date
      end
    end

    test "computes eager aggregates with all operations" do
      import Ecto.Query
      query = from(i in AggregateItem)

      aggregates = %{
        sum: [:amount, :quantity],
        avg: [:price, :rating],
        min: [:created_at],
        max: [:updated_at]
      }

      result =
        ConnectionAggregate.compute_aggregates(query, repo: MockAggregateRepo, aggregates: aggregates, deferred: false)

      assert result.sum[:amount] == 1000
      assert result.sum[:quantity] == 50
      assert result.avg[:price] == 20.0
      assert result.avg[:rating] == 4.5
      assert result.min[:created_at] == ~D[2024-01-01]
      assert result.max[:updated_at] == ~D[2024-12-31]
    end

    test "computes deferred aggregates with all operations" do
      import Ecto.Query
      query = from(i in AggregateItem)

      aggregates = %{
        sum: [:amount],
        avg: [:price],
        min: [:created_at],
        max: [:updated_at]
      }

      result =
        ConnectionAggregate.compute_aggregates(query, repo: MockAggregateRepo, aggregates: aggregates, deferred: true)

      # Deferred mode returns functions
      assert is_function(result._sum_fns[:amount], 0)
      assert is_function(result._avg_fns[:price], 0)
      assert is_function(result._min_fns[:created_at], 0)
      assert is_function(result._max_fns[:updated_at], 0)

      # Functions should return values when called
      assert result._sum_fns[:amount].() == 1000
      assert result._avg_fns[:price].() == 20.0
      assert result._min_fns[:created_at].() == ~D[2024-01-01]
      assert result._max_fns[:updated_at].() == ~D[2024-12-31]
    end

    test "computes eager aggregates with only sum" do
      import Ecto.Query
      query = from(i in AggregateItem)
      aggregates = %{sum: [:amount], avg: [], min: [], max: []}

      result =
        ConnectionAggregate.compute_aggregates(query, repo: MockAggregateRepo, aggregates: aggregates, deferred: false)

      assert result.sum[:amount] == 1000
      refute Map.has_key?(result, :avg)
      refute Map.has_key?(result, :min)
      refute Map.has_key?(result, :max)
    end

    test "computes eager aggregates with only avg" do
      import Ecto.Query
      query = from(i in AggregateItem)
      aggregates = %{sum: [], avg: [:price], min: [], max: []}

      result =
        ConnectionAggregate.compute_aggregates(query, repo: MockAggregateRepo, aggregates: aggregates, deferred: false)

      assert result.avg[:price] == 20.0
      refute Map.has_key?(result, :sum)
    end

    test "computes eager aggregates with only min" do
      import Ecto.Query
      query = from(i in AggregateItem)
      aggregates = %{sum: [], avg: [], min: [:created_at], max: []}

      result =
        ConnectionAggregate.compute_aggregates(query, repo: MockAggregateRepo, aggregates: aggregates, deferred: false)

      assert result.min[:created_at] == ~D[2024-01-01]
    end

    test "computes eager aggregates with only max" do
      import Ecto.Query
      query = from(i in AggregateItem)
      aggregates = %{sum: [], avg: [], min: [], max: [:updated_at]}

      result =
        ConnectionAggregate.compute_aggregates(query, repo: MockAggregateRepo, aggregates: aggregates, deferred: false)

      assert result.max[:updated_at] == ~D[2024-12-31]
    end

    test "computes deferred aggregates with only sum" do
      import Ecto.Query
      query = from(i in AggregateItem)
      aggregates = %{sum: [:amount], avg: [], min: [], max: []}

      result =
        ConnectionAggregate.compute_aggregates(query, repo: MockAggregateRepo, aggregates: aggregates, deferred: true)

      assert is_function(result._sum_fns[:amount], 0)
      refute Map.has_key?(result, :_avg_fns)
    end

    test "computes deferred aggregates with only avg" do
      import Ecto.Query
      query = from(i in AggregateItem)
      aggregates = %{sum: [], avg: [:price], min: [], max: []}

      result =
        ConnectionAggregate.compute_aggregates(query, repo: MockAggregateRepo, aggregates: aggregates, deferred: true)

      assert is_function(result._avg_fns[:price], 0)
      refute Map.has_key?(result, :_sum_fns)
    end

    test "computes deferred aggregates with only min" do
      import Ecto.Query
      query = from(i in AggregateItem)
      aggregates = %{sum: [], avg: [], min: [:created_at], max: []}

      result =
        ConnectionAggregate.compute_aggregates(query, repo: MockAggregateRepo, aggregates: aggregates, deferred: true)

      assert is_function(result._min_fns[:created_at], 0)
    end

    test "computes deferred aggregates with only max" do
      import Ecto.Query
      query = from(i in AggregateItem)
      aggregates = %{sum: [], avg: [], min: [], max: [:updated_at]}

      result =
        ConnectionAggregate.compute_aggregates(query, repo: MockAggregateRepo, aggregates: aggregates, deferred: true)

      assert is_function(result._max_fns[:updated_at], 0)
    end

    test "returns empty map when no aggregates defined" do
      import Ecto.Query
      query = from(i in AggregateItem)
      aggregates = %{sum: [], avg: [], min: [], max: []}

      result =
        ConnectionAggregate.compute_aggregates(query, repo: MockAggregateRepo, aggregates: aggregates, deferred: false)

      assert result == %{}
    end

    test "defaults to deferred mode" do
      import Ecto.Query
      query = from(i in AggregateItem)
      aggregates = %{sum: [:amount], avg: [], min: [], max: []}

      result = ConnectionAggregate.compute_aggregates(query, repo: MockAggregateRepo, aggregates: aggregates)

      # Default is deferred: true
      assert is_function(result._sum_fns[:amount], 0)
    end
  end
end
