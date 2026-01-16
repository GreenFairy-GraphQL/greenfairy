defmodule GreenFairy.CQL.PeriodOperatorsTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.Scalars.DateTime
  alias GreenFairy.CQL.Scalars.DateTime.Ecto, as: DateTimeEcto
  alias GreenFairy.CQL.Scalars.DateTime.Exlasticsearch, as: DateTimeExlasticsearch

  # Test schema for Ecto queries
  defmodule TestSchema do
    use Ecto.Schema

    schema "test_records" do
      field :created_at, :utc_datetime
      field :updated_at, :utc_datetime
    end
  end

  describe "DateTime scalar" do
    test "operator_input includes period operators for all adapters" do
      for adapter <- [:postgres, :mysql, :sqlite, :mssql, :elasticsearch] do
        {operators, _type, _desc} = DateTime.operator_input(adapter)

        assert :_period in operators, "#{adapter} should include _period operator"
        assert :_current_period in operators, "#{adapter} should include _current_period operator"
        assert :_between in operators, "#{adapter} should include _between operator"
      end
    end

    test "auxiliary_types returns all owned input/enum modules" do
      types = DateTime.auxiliary_types()

      assert DateTime.PeriodDirection in types
      assert DateTime.PeriodUnit in types
      assert DateTime.PeriodInput in types
      assert DateTime.CurrentPeriodInput in types
    end

    test "delegates to Exlasticsearch for elasticsearch adapter" do
      query = %{query: %{bool: %{must: []}}}

      result = DateTime.apply_operator(
        query,
        :created_at,
        :_current_period,
        %{unit: :day},
        :elasticsearch,
        []
      )

      assert get_in(result, [:query, :bool, :must]) != []
    end

    test "delegates to Ecto for postgres adapter" do
      import Ecto.Query
      query = from(t in TestSchema)

      result = DateTime.apply_operator(
        query,
        :created_at,
        :_current_period,
        %{unit: :day},
        :postgres,
        []
      )

      assert %Ecto.Query{} = result
    end
  end

  describe "DateTime.Ecto._period operator" do
    import Ecto.Query

    test "last N days generates correct query" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(
        query,
        :created_at,
        :_period,
        %{direction: :last, unit: :day, count: 7},
        adapter: :postgres
      )

      assert %Ecto.Query{wheres: [%{expr: expr}]} = result
      assert {:fragment, _, _} = expr
    end

    test "next N months generates correct query" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(
        query,
        :created_at,
        :_period,
        %{direction: :next, unit: :month, count: 3},
        adapter: :postgres
      )

      assert %Ecto.Query{wheres: [%{expr: expr}]} = result
      assert {:fragment, _, _} = expr
    end

    test "count defaults to 1 when not provided" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(
        query,
        :created_at,
        :_period,
        %{direction: :last, unit: :week},
        adapter: :postgres
      )

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "works with all supported units" do
      query = from(t in TestSchema)

      for unit <- [:hour, :day, :week, :month, :quarter, :year] do
        result = DateTimeEcto.apply_operator(
          query,
          :created_at,
          :_period,
          %{direction: :last, unit: unit, count: 2},
          adapter: :postgres
        )

        assert %Ecto.Query{wheres: [%{}]} = result, "Failed for unit: #{unit}"
      end
    end

    test "works with binding option" do
      query = from(t in TestSchema, as: :test)

      result = DateTimeEcto.apply_operator(
        query,
        :created_at,
        :_period,
        %{direction: :last, unit: :day, count: 7},
        adapter: :postgres, binding: :test
      )

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "works with MySQL adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(
        query,
        :created_at,
        :_period,
        %{direction: :last, unit: :day, count: 7},
        adapter: :mysql
      )

      assert %Ecto.Query{wheres: [%{expr: expr}]} = result
      assert {:fragment, _, _} = expr
    end

    test "works with SQLite adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(
        query,
        :created_at,
        :_period,
        %{direction: :last, unit: :day, count: 7},
        adapter: :sqlite
      )

      assert %Ecto.Query{wheres: [%{expr: expr}]} = result
      assert {:fragment, _, _} = expr
    end

    test "works with MSSQL adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(
        query,
        :created_at,
        :_period,
        %{direction: :last, unit: :day, count: 7},
        adapter: :mssql
      )

      assert %Ecto.Query{wheres: [%{expr: expr}]} = result
      assert {:fragment, _, _} = expr
    end
  end

  describe "DateTime.Ecto._current_period operator" do
    import Ecto.Query

    test "this day generates correct query" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(
        query,
        :created_at,
        :_current_period,
        %{unit: :day},
        adapter: :postgres
      )

      assert %Ecto.Query{wheres: [%{expr: expr}]} = result
      assert {:fragment, _, _} = expr
    end

    test "this week generates correct query" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(
        query,
        :created_at,
        :_current_period,
        %{unit: :week},
        adapter: :postgres
      )

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this month generates correct query" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(
        query,
        :created_at,
        :_current_period,
        %{unit: :month},
        adapter: :postgres
      )

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this quarter generates correct query" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(
        query,
        :created_at,
        :_current_period,
        %{unit: :quarter},
        adapter: :postgres
      )

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this year generates correct query" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(
        query,
        :created_at,
        :_current_period,
        %{unit: :year},
        adapter: :postgres
      )

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "works with all supported units for all adapters" do
      query = from(t in TestSchema)

      for adapter <- [:postgres, :mysql, :sqlite, :mssql] do
        for unit <- [:hour, :day, :week, :month, :quarter, :year] do
          result = DateTimeEcto.apply_operator(
            query,
            :created_at,
            :_current_period,
            %{unit: unit},
            adapter: adapter
          )

          assert %Ecto.Query{wheres: [%{}]} = result,
            "Failed for adapter: #{adapter}, unit: #{unit}"
        end
      end
    end
  end

  describe "DateTime.Ecto._between operator" do
    import Ecto.Query

    test "generates BETWEEN query" do
      query = from(t in TestSchema)
      start_date = ~U[2024-01-01 00:00:00Z]
      end_date = ~U[2024-01-31 23:59:59Z]

      result = DateTimeEcto.apply_operator(
        query,
        :created_at,
        :_between,
        [start_date, end_date],
        adapter: :postgres
      )

      assert %Ecto.Query{wheres: [%{expr: {:fragment, _, _}}]} = result
    end

    test "works with binding" do
      query = from(t in TestSchema, as: :test)
      start_date = ~U[2024-01-01 00:00:00Z]
      end_date = ~U[2024-01-31 23:59:59Z]

      result = DateTimeEcto.apply_operator(
        query,
        :created_at,
        :_between,
        [start_date, end_date],
        adapter: :postgres, binding: :test
      )

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end

  describe "DateTime.Ecto standard operators" do
    import Ecto.Query

    test "delegates to Integer.Ecto for standard comparison operators" do
      query = from(t in TestSchema)
      now = Elixir.DateTime.utc_now()

      result = DateTimeEcto.apply_operator(
        query,
        :created_at,
        :_eq,
        now,
        adapter: :postgres
      )

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end

  describe "DateTime.Exlasticsearch._period operator" do
    test "last N days generates correct Elasticsearch query" do
      query = %{query: %{bool: %{must: []}}}

      result = DateTimeExlasticsearch.apply_operator(
        query,
        :created_at,
        :_period,
        %{direction: :last, unit: :day, count: 7},
        []
      )

      [range_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{range: %{"created_at" => %{gte: "now-7d", lt: "now"}}} = range_clause
    end

    test "next N months generates correct Elasticsearch query" do
      query = %{query: %{bool: %{must: []}}}

      result = DateTimeExlasticsearch.apply_operator(
        query,
        :created_at,
        :_period,
        %{direction: :next, unit: :month, count: 3},
        []
      )

      [range_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{range: %{"created_at" => %{gt: "now", lte: "now+3M"}}} = range_clause
    end

    test "quarter uses months (3x count)" do
      query = %{query: %{bool: %{must: []}}}

      result = DateTimeExlasticsearch.apply_operator(
        query,
        :created_at,
        :_period,
        %{direction: :last, unit: :quarter, count: 2},
        []
      )

      [range_clause | _] = get_in(result, [:query, :bool, :must])
      # 2 quarters = 6 months
      assert %{range: %{"created_at" => %{gte: "now-6M", lt: "now"}}} = range_clause
    end

    test "count defaults to 1 when not provided" do
      query = %{query: %{bool: %{must: []}}}

      result = DateTimeExlasticsearch.apply_operator(
        query,
        :created_at,
        :_period,
        %{direction: :last, unit: :week},
        []
      )

      [range_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{range: %{"created_at" => %{gte: "now-1w", lt: "now"}}} = range_clause
    end

    test "works with all supported units" do
      query = %{query: %{bool: %{must: []}}}

      expected_units = [
        {:hour, "h"},
        {:day, "d"},
        {:week, "w"},
        {:month, "M"},
        {:quarter, "M"},  # quarters use months
        {:year, "y"}
      ]

      for {unit, _es_char} <- expected_units do
        result = DateTimeExlasticsearch.apply_operator(
          query,
          :created_at,
          :_period,
          %{direction: :last, unit: unit, count: 1},
          []
        )

        [range_clause | _] = get_in(result, [:query, :bool, :must])
        assert %{range: %{"created_at" => %{gte: _, lt: "now"}}} = range_clause
      end
    end

    test "works with binding option" do
      query = %{query: %{bool: %{must: []}}}

      result = DateTimeExlasticsearch.apply_operator(
        query,
        :created_at,
        :_period,
        %{direction: :last, unit: :day, count: 7},
        binding: :parent
      )

      [range_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{range: %{"parent.created_at" => %{}}} = range_clause
    end
  end

  describe "DateTime.Exlasticsearch._current_period operator" do
    test "this day uses day rounding" do
      query = %{query: %{bool: %{must: []}}}

      result = DateTimeExlasticsearch.apply_operator(
        query,
        :created_at,
        :_current_period,
        %{unit: :day},
        []
      )

      [range_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{range: %{"created_at" => %{gte: "now/d", lt: "now/d+1d"}}} = range_clause
    end

    test "this week uses week rounding" do
      query = %{query: %{bool: %{must: []}}}

      result = DateTimeExlasticsearch.apply_operator(
        query,
        :created_at,
        :_current_period,
        %{unit: :week},
        []
      )

      [range_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{range: %{"created_at" => %{gte: "now/w", lt: "now/w+1w"}}} = range_clause
    end

    test "this month uses month rounding" do
      query = %{query: %{bool: %{must: []}}}

      result = DateTimeExlasticsearch.apply_operator(
        query,
        :created_at,
        :_current_period,
        %{unit: :month},
        []
      )

      [range_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{range: %{"created_at" => %{gte: "now/M", lt: "now/M+1M"}}} = range_clause
    end

    test "this year uses year rounding" do
      query = %{query: %{bool: %{must: []}}}

      result = DateTimeExlasticsearch.apply_operator(
        query,
        :created_at,
        :_current_period,
        %{unit: :year},
        []
      )

      [range_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{range: %{"created_at" => %{gte: "now/y", lt: "now/y+1y"}}} = range_clause
    end

    test "this hour uses hour rounding" do
      query = %{query: %{bool: %{must: []}}}

      result = DateTimeExlasticsearch.apply_operator(
        query,
        :created_at,
        :_current_period,
        %{unit: :hour},
        []
      )

      [range_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{range: %{"created_at" => %{gte: "now/h", lt: "now/h+1h"}}} = range_clause
    end

    test "this quarter uses month rounding with 3 month span" do
      query = %{query: %{bool: %{must: []}}}

      result = DateTimeExlasticsearch.apply_operator(
        query,
        :created_at,
        :_current_period,
        %{unit: :quarter},
        []
      )

      [range_clause | _] = get_in(result, [:query, :bool, :must])
      # Quarter uses month rounding with 3M span (approximation)
      assert %{range: %{"created_at" => %{gte: "now/M", lt: "now/M+3M"}}} = range_clause
    end
  end

  describe "DateTime.Exlasticsearch._between operator" do
    test "generates range query with gte and lte" do
      query = %{query: %{bool: %{must: []}}}
      start_date = "2024-01-01T00:00:00Z"
      end_date = "2024-01-31T23:59:59Z"

      result = DateTimeExlasticsearch.apply_operator(
        query,
        :created_at,
        :_between,
        [start_date, end_date],
        []
      )

      [range_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{range: %{"created_at" => %{gte: ^start_date, lte: ^end_date}}} = range_clause
    end
  end

  describe "DateTime.Exlasticsearch standard operators" do
    test "delegates to Integer.Exlasticsearch for standard comparison operators" do
      query = %{query: %{bool: %{must: []}}}

      result = DateTimeExlasticsearch.apply_operator(
        query,
        :created_at,
        :_eq,
        "2024-01-01T00:00:00Z",
        []
      )

      [term_clause | _] = get_in(result, [:query, :bool, :must])
      assert %{term: %{"created_at" => "2024-01-01T00:00:00Z"}} = term_clause
    end
  end

  describe "PeriodDirection enum" do
    test "defines correct values" do
      assert DateTime.PeriodDirection.__green_fairy_kind__() == :enum
    end
  end

  describe "PeriodUnit enum" do
    test "defines correct values" do
      assert DateTime.PeriodUnit.__green_fairy_kind__() == :enum
    end
  end

  describe "PeriodInput input type" do
    test "defines correct kind" do
      assert DateTime.PeriodInput.__green_fairy_kind__() == :input_object
    end
  end

  describe "CurrentPeriodInput input type" do
    test "defines correct kind" do
      assert DateTime.CurrentPeriodInput.__green_fairy_kind__() == :input_object
    end
  end

  describe "Date scalar delegation" do
    test "includes period operators via DateTime delegation" do
      {operators, _type, _desc} = GreenFairy.CQL.Scalars.Date.operator_input(:postgres)

      assert :_period in operators
      assert :_current_period in operators
    end
  end

  describe "NaiveDateTime scalar delegation" do
    test "includes period operators via DateTime delegation" do
      {operators, _type, _desc} = GreenFairy.CQL.Scalars.NaiveDateTime.operator_input(:postgres)

      assert :_period in operators
      assert :_current_period in operators
    end
  end
end
