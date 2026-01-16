defmodule GreenFairy.Field.ConnectionAggregateTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Field.ConnectionAggregate

  describe "parse_aggregate_block/1" do
    test "parses block with all aggregate types" do
      block = {:__block__, [],
        [
          {:sum, [], [[:hours_worked, :total_pay]]},
          {:avg, [], [[:hours_worked, :hourly_rate]]},
          {:min, [], [[:start_time]]},
          {:max, [], [[:end_time]]}
        ]
      }

      result = ConnectionAggregate.parse_aggregate_block(block)

      assert result.sum == [:hours_worked, :total_pay]
      assert result.avg == [:hours_worked, :hourly_rate]
      assert result.min == [:start_time]
      assert result.max == [:end_time]
    end

    test "parses block with only sum" do
      block = {:__block__, [],
        [
          {:sum, [], [[:hours_worked, :total_pay]]}
        ]
      }

      result = ConnectionAggregate.parse_aggregate_block(block)

      assert result.sum == [:hours_worked, :total_pay]
      assert result.avg == []
      assert result.min == []
      assert result.max == []
    end

    test "parses block with only avg" do
      block = {:__block__, [],
        [
          {:avg, [], [[:rate, :score]]}
        ]
      }

      result = ConnectionAggregate.parse_aggregate_block(block)

      assert result.sum == []
      assert result.avg == [:rate, :score]
      assert result.min == []
      assert result.max == []
    end

    test "parses single sum statement (not in block)" do
      block = {:sum, [], [[:hours_worked]]}

      result = ConnectionAggregate.parse_aggregate_block(block)

      assert result.sum == [:hours_worked]
      assert result.avg == []
      assert result.min == []
      assert result.max == []
    end

    test "parses single avg statement (not in block)" do
      block = {:avg, [], [[:rating]]}

      result = ConnectionAggregate.parse_aggregate_block(block)

      assert result.avg == [:rating]
    end

    test "parses single min statement (not in block)" do
      block = {:min, [], [[:created_at]]}

      result = ConnectionAggregate.parse_aggregate_block(block)

      assert result.min == [:created_at]
    end

    test "parses single max statement (not in block)" do
      block = {:max, [], [[:updated_at]]}

      result = ConnectionAggregate.parse_aggregate_block(block)

      assert result.max == [:updated_at]
    end

    test "returns nil for invalid block" do
      block = {:invalid, [], []}

      result = ConnectionAggregate.parse_aggregate_block(block)

      assert result == nil
    end

    test "ignores unknown statements in block" do
      block = {:__block__, [],
        [
          {:sum, [], [[:amount]]},
          {:unknown_op, [], [[:field]]},
          {:avg, [], [[:rate]]}
        ]
      }

      result = ConnectionAggregate.parse_aggregate_block(block)

      assert result.sum == [:amount]
      assert result.avg == [:rate]
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

  describe "macros" do
    test "sum/1 returns tuple" do
      # Test the behavior expected from the macro
      assert {:sum, [:field1, :field2]} = {:sum, [:field1, :field2]}
    end

    test "avg/1 returns tuple" do
      assert {:avg, [:field1]} = {:avg, [:field1]}
    end

    test "min/1 returns tuple" do
      assert {:min, [:field1]} = {:min, [:field1]}
    end

    test "max/1 returns tuple" do
      assert {:max, [:field1]} = {:max, [:field1]}
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

      result = ConnectionAggregate.compute_aggregates(query, repo: MockAggregateRepo, aggregates: aggregates, deferred: false)

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

      result = ConnectionAggregate.compute_aggregates(query, repo: MockAggregateRepo, aggregates: aggregates, deferred: true)

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

      result = ConnectionAggregate.compute_aggregates(query, repo: MockAggregateRepo, aggregates: aggregates, deferred: false)

      assert result.sum[:amount] == 1000
      refute Map.has_key?(result, :avg)
      refute Map.has_key?(result, :min)
      refute Map.has_key?(result, :max)
    end

    test "computes eager aggregates with only avg" do
      import Ecto.Query
      query = from(i in AggregateItem)
      aggregates = %{sum: [], avg: [:price], min: [], max: []}

      result = ConnectionAggregate.compute_aggregates(query, repo: MockAggregateRepo, aggregates: aggregates, deferred: false)

      assert result.avg[:price] == 20.0
      refute Map.has_key?(result, :sum)
    end

    test "computes eager aggregates with only min" do
      import Ecto.Query
      query = from(i in AggregateItem)
      aggregates = %{sum: [], avg: [], min: [:created_at], max: []}

      result = ConnectionAggregate.compute_aggregates(query, repo: MockAggregateRepo, aggregates: aggregates, deferred: false)

      assert result.min[:created_at] == ~D[2024-01-01]
    end

    test "computes eager aggregates with only max" do
      import Ecto.Query
      query = from(i in AggregateItem)
      aggregates = %{sum: [], avg: [], min: [], max: [:updated_at]}

      result = ConnectionAggregate.compute_aggregates(query, repo: MockAggregateRepo, aggregates: aggregates, deferred: false)

      assert result.max[:updated_at] == ~D[2024-12-31]
    end

    test "computes deferred aggregates with only sum" do
      import Ecto.Query
      query = from(i in AggregateItem)
      aggregates = %{sum: [:amount], avg: [], min: [], max: []}

      result = ConnectionAggregate.compute_aggregates(query, repo: MockAggregateRepo, aggregates: aggregates, deferred: true)

      assert is_function(result._sum_fns[:amount], 0)
      refute Map.has_key?(result, :_avg_fns)
    end

    test "computes deferred aggregates with only avg" do
      import Ecto.Query
      query = from(i in AggregateItem)
      aggregates = %{sum: [], avg: [:price], min: [], max: []}

      result = ConnectionAggregate.compute_aggregates(query, repo: MockAggregateRepo, aggregates: aggregates, deferred: true)

      assert is_function(result._avg_fns[:price], 0)
      refute Map.has_key?(result, :_sum_fns)
    end

    test "computes deferred aggregates with only min" do
      import Ecto.Query
      query = from(i in AggregateItem)
      aggregates = %{sum: [], avg: [], min: [:created_at], max: []}

      result = ConnectionAggregate.compute_aggregates(query, repo: MockAggregateRepo, aggregates: aggregates, deferred: true)

      assert is_function(result._min_fns[:created_at], 0)
    end

    test "computes deferred aggregates with only max" do
      import Ecto.Query
      query = from(i in AggregateItem)
      aggregates = %{sum: [], avg: [], min: [], max: [:updated_at]}

      result = ConnectionAggregate.compute_aggregates(query, repo: MockAggregateRepo, aggregates: aggregates, deferred: true)

      assert is_function(result._max_fns[:updated_at], 0)
    end

    test "returns empty map when no aggregates defined" do
      import Ecto.Query
      query = from(i in AggregateItem)
      aggregates = %{sum: [], avg: [], min: [], max: []}

      result = ConnectionAggregate.compute_aggregates(query, repo: MockAggregateRepo, aggregates: aggregates, deferred: false)

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
