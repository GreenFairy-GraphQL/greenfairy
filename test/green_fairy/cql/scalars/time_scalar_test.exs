defmodule GreenFairy.CQL.Scalars.TimeScalarTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.Scalars.Time

  describe "Time scalar" do
    test "operator_input returns correct operators" do
      {operators, type, _desc} = Time.operator_input(:postgres)

      assert :_eq in operators
      assert :_ne in operators
      assert :_neq in operators
      assert :_gt in operators
      assert :_gte in operators
      assert :_lt in operators
      assert :_lte in operators
      assert :_in in operators
      assert :_nin in operators
      assert :_is_null in operators
      assert type == :time
    end

    test "operator_type_identifier returns correct identifier" do
      assert Time.operator_type_identifier(:postgres) == :cql_op_time_input
      assert Time.operator_type_identifier(:mysql) == :cql_op_time_input
      assert Time.operator_type_identifier(:elasticsearch) == :cql_op_time_input
    end

    test "apply_operator delegates to Integer" do
      import Ecto.Query

      defmodule TimeTestSchema do
        use Ecto.Schema

        schema "events" do
          field :start_time, :time
        end
      end

      query = from(t in TimeTestSchema)
      time_val = ~T[14:30:00]

      result = Time.apply_operator(query, :start_time, :_eq, time_val, :postgres, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "apply_operator with _gt operator" do
      import Ecto.Query

      defmodule TimeTestSchema2 do
        use Ecto.Schema

        schema "events" do
          field :start_time, :time
        end
      end

      query = from(t in TimeTestSchema2)
      time_val = ~T[09:00:00]

      result = Time.apply_operator(query, :start_time, :_gt, time_val, :postgres, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "apply_operator with _in operator" do
      import Ecto.Query

      defmodule TimeTestSchema3 do
        use Ecto.Schema

        schema "events" do
          field :start_time, :time
        end
      end

      query = from(t in TimeTestSchema3)
      time_vals = [~T[09:00:00], ~T[12:00:00], ~T[15:00:00]]

      result = Time.apply_operator(query, :start_time, :_in, time_vals, :postgres, [])
      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end
end
