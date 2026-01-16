defmodule GreenFairy.CQL.Scalars.DateTime.EctoTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.Scalars.DateTime.Ecto, as: DateTimeEcto

  defmodule TestSchema do
    use Ecto.Schema

    schema "test_records" do
      field :created_at, :utc_datetime
    end
  end

  import Ecto.Query

  describe "_between operator" do
    test "without binding" do
      query = from(t in TestSchema)
      start_val = ~U[2024-01-01 00:00:00Z]
      end_val = ~U[2024-12-31 23:59:59Z]

      result = DateTimeEcto.apply_operator(query, :created_at, :_between, [start_val, end_val], [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "with binding" do
      query = from(t in TestSchema, as: :record)
      start_val = ~U[2024-01-01 00:00:00Z]
      end_val = ~U[2024-12-31 23:59:59Z]

      result = DateTimeEcto.apply_operator(query, :created_at, :_between, [start_val, end_val], binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end

  describe "_period operator" do
    test "last days without count defaults to 1" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_period, %{direction: :last, unit: :day}, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "last N days with postgres adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_period,
        %{direction: :last, unit: :day, count: 7}, adapter: :postgres)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "last N days with postgres adapter and binding" do
      query = from(t in TestSchema, as: :record)

      result = DateTimeEcto.apply_operator(query, :created_at, :_period,
        %{direction: :last, unit: :day, count: 7}, adapter: :postgres, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "next N days with postgres adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_period,
        %{direction: :next, unit: :day, count: 30}, adapter: :postgres)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "next N days with postgres adapter and binding" do
      query = from(t in TestSchema, as: :record)

      result = DateTimeEcto.apply_operator(query, :created_at, :_period,
        %{direction: :next, unit: :day, count: 30}, adapter: :postgres, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "last N weeks with mysql adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_period,
        %{direction: :last, unit: :week, count: 2}, adapter: :mysql)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "last N weeks with mysql adapter and binding" do
      query = from(t in TestSchema, as: :record)

      result = DateTimeEcto.apply_operator(query, :created_at, :_period,
        %{direction: :last, unit: :week, count: 2}, adapter: :mysql, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "next N months with mysql adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_period,
        %{direction: :next, unit: :month, count: 3}, adapter: :mysql)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "next N months with mysql adapter and binding" do
      query = from(t in TestSchema, as: :record)

      result = DateTimeEcto.apply_operator(query, :created_at, :_period,
        %{direction: :next, unit: :month, count: 3}, adapter: :mysql, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "last N hours with sqlite adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_period,
        %{direction: :last, unit: :hour, count: 6}, adapter: :sqlite)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "last N hours with sqlite adapter and binding" do
      query = from(t in TestSchema, as: :record)

      result = DateTimeEcto.apply_operator(query, :created_at, :_period,
        %{direction: :last, unit: :hour, count: 6}, adapter: :sqlite, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "next N years with sqlite adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_period,
        %{direction: :next, unit: :year, count: 1}, adapter: :sqlite)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "next N years with sqlite adapter and binding" do
      query = from(t in TestSchema, as: :record)

      result = DateTimeEcto.apply_operator(query, :created_at, :_period,
        %{direction: :next, unit: :year, count: 1}, adapter: :sqlite, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "last N quarters with mssql adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_period,
        %{direction: :last, unit: :quarter, count: 2}, adapter: :mssql)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "last N quarters with mssql adapter and binding" do
      query = from(t in TestSchema, as: :record)

      result = DateTimeEcto.apply_operator(query, :created_at, :_period,
        %{direction: :last, unit: :quarter, count: 2}, adapter: :mssql, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "next N quarters with mssql adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_period,
        %{direction: :next, unit: :quarter, count: 1}, adapter: :mssql)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "next N quarters with mssql adapter and binding" do
      query = from(t in TestSchema, as: :record)

      result = DateTimeEcto.apply_operator(query, :created_at, :_period,
        %{direction: :next, unit: :quarter, count: 1}, adapter: :mssql, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "falls back to postgres for unknown adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_period,
        %{direction: :last, unit: :day, count: 7}, adapter: :unknown)

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end

  describe "_current_period operator" do
    test "this hour with postgres adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :hour}, adapter: :postgres)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this hour with postgres adapter and binding" do
      query = from(t in TestSchema, as: :record)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :hour}, adapter: :postgres, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "today with postgres adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :day}, adapter: :postgres)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this week with postgres adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :week}, adapter: :postgres)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this month with postgres adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :month}, adapter: :postgres)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this quarter with postgres adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :quarter}, adapter: :postgres)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this year with postgres adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :year}, adapter: :postgres)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    # MySQL current period tests
    test "this hour with mysql adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :hour}, adapter: :mysql)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this hour with mysql adapter and binding" do
      query = from(t in TestSchema, as: :record)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :hour}, adapter: :mysql, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "today with mysql adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :day}, adapter: :mysql)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "today with mysql adapter and binding" do
      query = from(t in TestSchema, as: :record)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :day}, adapter: :mysql, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this week with mysql adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :week}, adapter: :mysql)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this week with mysql adapter and binding" do
      query = from(t in TestSchema, as: :record)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :week}, adapter: :mysql, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this month with mysql adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :month}, adapter: :mysql)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this month with mysql adapter and binding" do
      query = from(t in TestSchema, as: :record)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :month}, adapter: :mysql, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this quarter with mysql adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :quarter}, adapter: :mysql)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this quarter with mysql adapter and binding" do
      query = from(t in TestSchema, as: :record)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :quarter}, adapter: :mysql, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this year with mysql adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :year}, adapter: :mysql)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this year with mysql adapter and binding" do
      query = from(t in TestSchema, as: :record)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :year}, adapter: :mysql, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    # SQLite current period tests
    test "this hour with sqlite adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :hour}, adapter: :sqlite)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this hour with sqlite adapter and binding" do
      query = from(t in TestSchema, as: :record)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :hour}, adapter: :sqlite, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "today with sqlite adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :day}, adapter: :sqlite)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this week with sqlite adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :week}, adapter: :sqlite)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this month with sqlite adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :month}, adapter: :sqlite)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this quarter with sqlite adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :quarter}, adapter: :sqlite)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this year with sqlite adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :year}, adapter: :sqlite)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    # MSSQL current period tests
    test "this hour with mssql adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :hour}, adapter: :mssql)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this hour with mssql adapter and binding" do
      query = from(t in TestSchema, as: :record)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :hour}, adapter: :mssql, binding: :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "today with mssql adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :day}, adapter: :mssql)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this week with mssql adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :week}, adapter: :mssql)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this month with mssql adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :month}, adapter: :mssql)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this quarter with mssql adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :quarter}, adapter: :mssql)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "this year with mssql adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :year}, adapter: :mssql)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "falls back to postgres for unknown adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_current_period,
        %{unit: :day}, adapter: :unknown)

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end

  describe "standard comparison operators" do
    test "delegates to Integer adapter" do
      query = from(t in TestSchema)
      value = ~U[2024-01-01 00:00:00Z]

      result = DateTimeEcto.apply_operator(query, :created_at, :_eq, value, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "delegates _gt to Integer adapter" do
      query = from(t in TestSchema)
      value = ~U[2024-01-01 00:00:00Z]

      result = DateTimeEcto.apply_operator(query, :created_at, :_gt, value, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "delegates _lt to Integer adapter" do
      query = from(t in TestSchema)
      value = ~U[2024-01-01 00:00:00Z]

      result = DateTimeEcto.apply_operator(query, :created_at, :_lt, value, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "delegates _gte to Integer adapter" do
      query = from(t in TestSchema)
      value = ~U[2024-01-01 00:00:00Z]

      result = DateTimeEcto.apply_operator(query, :created_at, :_gte, value, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "delegates _lte to Integer adapter" do
      query = from(t in TestSchema)
      value = ~U[2024-01-01 00:00:00Z]

      result = DateTimeEcto.apply_operator(query, :created_at, :_lte, value, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "delegates _is_null to Integer adapter" do
      query = from(t in TestSchema)

      result = DateTimeEcto.apply_operator(query, :created_at, :_is_null, true, [])

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end
end
