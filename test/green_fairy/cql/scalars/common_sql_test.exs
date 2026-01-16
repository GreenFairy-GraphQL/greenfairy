defmodule GreenFairy.CQL.Scalars.CommonSQLTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.Scalars.CommonSQL

  defmodule TestSchema do
    use Ecto.Schema

    schema "test_records" do
      field :name, :string
      field :age, :integer
      field :score, :float
    end
  end

  import Ecto.Query

  describe "apply_eq/4" do
    test "with regular value and no binding" do
      query = from(t in TestSchema)

      result = CommonSQL.apply_eq(query, :name, "test", nil)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "with regular value and binding" do
      query = from(t in TestSchema, as: :record)

      result = CommonSQL.apply_eq(query, :name, "test", :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "with nil value and no binding uses is_nil" do
      query = from(t in TestSchema)

      result = CommonSQL.apply_eq(query, :name, nil, nil)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "with nil value and binding uses is_nil" do
      query = from(t in TestSchema, as: :record)

      result = CommonSQL.apply_eq(query, :name, nil, :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end

  describe "apply_neq/4" do
    test "with regular value and no binding" do
      query = from(t in TestSchema)

      result = CommonSQL.apply_neq(query, :name, "test", nil)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "with regular value and binding" do
      query = from(t in TestSchema, as: :record)

      result = CommonSQL.apply_neq(query, :name, "test", :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "with nil value and no binding uses not is_nil" do
      query = from(t in TestSchema)

      result = CommonSQL.apply_neq(query, :name, nil, nil)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "with nil value and binding uses not is_nil" do
      query = from(t in TestSchema, as: :record)

      result = CommonSQL.apply_neq(query, :name, nil, :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end

  describe "apply_gt/4" do
    test "without binding" do
      query = from(t in TestSchema)

      result = CommonSQL.apply_gt(query, :age, 18, nil)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "with binding" do
      query = from(t in TestSchema, as: :record)

      result = CommonSQL.apply_gt(query, :age, 18, :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end

  describe "apply_gte/4" do
    test "without binding" do
      query = from(t in TestSchema)

      result = CommonSQL.apply_gte(query, :age, 18, nil)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "with binding" do
      query = from(t in TestSchema, as: :record)

      result = CommonSQL.apply_gte(query, :age, 18, :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end

  describe "apply_lt/4" do
    test "without binding" do
      query = from(t in TestSchema)

      result = CommonSQL.apply_lt(query, :age, 65, nil)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "with binding" do
      query = from(t in TestSchema, as: :record)

      result = CommonSQL.apply_lt(query, :age, 65, :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end

  describe "apply_lte/4" do
    test "without binding" do
      query = from(t in TestSchema)

      result = CommonSQL.apply_lte(query, :age, 65, nil)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "with binding" do
      query = from(t in TestSchema, as: :record)

      result = CommonSQL.apply_lte(query, :age, 65, :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end

  describe "apply_in/4" do
    test "without binding" do
      query = from(t in TestSchema)

      result = CommonSQL.apply_in(query, :age, [18, 21, 25], nil)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "with binding" do
      query = from(t in TestSchema, as: :record)

      result = CommonSQL.apply_in(query, :age, [18, 21, 25], :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end

  describe "apply_nin/4" do
    test "without binding" do
      query = from(t in TestSchema)

      result = CommonSQL.apply_nin(query, :age, [0, -1], nil)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "with binding" do
      query = from(t in TestSchema, as: :record)

      result = CommonSQL.apply_nin(query, :age, [0, -1], :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end

  describe "apply_is_null/4" do
    test "true without binding" do
      query = from(t in TestSchema)

      result = CommonSQL.apply_is_null(query, :name, true, nil)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "true with binding" do
      query = from(t in TestSchema, as: :record)

      result = CommonSQL.apply_is_null(query, :name, true, :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "false without binding" do
      query = from(t in TestSchema)

      result = CommonSQL.apply_is_null(query, :name, false, nil)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "false with binding" do
      query = from(t in TestSchema, as: :record)

      result = CommonSQL.apply_is_null(query, :name, false, :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end

  describe "apply_like/4" do
    test "without binding" do
      query = from(t in TestSchema)

      result = CommonSQL.apply_like(query, :name, "%test%", nil)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "with binding" do
      query = from(t in TestSchema, as: :record)

      result = CommonSQL.apply_like(query, :name, "%test%", :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end

  describe "apply_nlike/4" do
    test "without binding" do
      query = from(t in TestSchema)

      result = CommonSQL.apply_nlike(query, :name, "%test%", nil)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "with binding" do
      query = from(t in TestSchema, as: :record)

      result = CommonSQL.apply_nlike(query, :name, "%test%", :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end

  describe "apply_starts_with/4" do
    test "without binding" do
      query = from(t in TestSchema)

      result = CommonSQL.apply_starts_with(query, :name, "test", nil)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "with binding" do
      query = from(t in TestSchema, as: :record)

      result = CommonSQL.apply_starts_with(query, :name, "test", :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end

  describe "apply_ends_with/4" do
    test "without binding" do
      query = from(t in TestSchema)

      result = CommonSQL.apply_ends_with(query, :name, "test", nil)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "with binding" do
      query = from(t in TestSchema, as: :record)

      result = CommonSQL.apply_ends_with(query, :name, "test", :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end

  describe "apply_contains/4" do
    test "without binding" do
      query = from(t in TestSchema)

      result = CommonSQL.apply_contains(query, :name, "test", nil)

      assert %Ecto.Query{wheres: [%{}]} = result
    end

    test "with binding" do
      query = from(t in TestSchema, as: :record)

      result = CommonSQL.apply_contains(query, :name, "test", :record)

      assert %Ecto.Query{wheres: [%{}]} = result
    end
  end
end
