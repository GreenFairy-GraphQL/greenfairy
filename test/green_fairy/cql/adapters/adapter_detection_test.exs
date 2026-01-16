defmodule GreenFairy.CQL.AdapterDetectionTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.Adapter

  describe "detect_adapter/2" do
    test "returns configured adapter from application env" do
      # Save original config
      original = Application.get_env(:green_fairy, :cql_adapter)

      try do
        Application.put_env(:green_fairy, :cql_adapter, GreenFairy.CQL.Adapters.MySQL)
        assert Adapter.detect_adapter(SomeRepo) == GreenFairy.CQL.Adapters.MySQL
      after
        if original do
          Application.put_env(:green_fairy, :cql_adapter, original)
        else
          Application.delete_env(:green_fairy, :cql_adapter)
        end
      end
    end

    test "returns default option when repo doesn't exist" do
      # Clear config
      original = Application.get_env(:green_fairy, :cql_adapter)
      Application.delete_env(:green_fairy, :cql_adapter)

      try do
        result = Adapter.detect_adapter(NonExistentRepo, default: GreenFairy.CQL.Adapters.SQLite)
        assert result == GreenFairy.CQL.Adapters.SQLite
      after
        if original, do: Application.put_env(:green_fairy, :cql_adapter, original)
      end
    end

    test "falls back to generic Ecto adapter when repo doesn't exist and no default" do
      original = Application.get_env(:green_fairy, :cql_adapter)
      Application.delete_env(:green_fairy, :cql_adapter)

      try do
        result = Adapter.detect_adapter(NonExistentRepo)
        assert result == GreenFairy.CQL.Adapters.Ecto
      after
        if original, do: Application.put_env(:green_fairy, :cql_adapter, original)
      end
    end
  end

  describe "generic Ecto adapter" do
    alias GreenFairy.CQL.Adapters.Ecto, as: EctoAdapter

    test "supports only basic sort directions" do
      assert EctoAdapter.sort_directions() == [:asc, :desc]
    end

    test "does not support geo ordering" do
      refute EctoAdapter.supports_geo_ordering?()
    end

    test "does not support priority ordering" do
      refute EctoAdapter.supports_priority_ordering?()
    end

    test "capabilities indicate generic fallback" do
      caps = EctoAdapter.capabilities()
      assert caps.generic_fallback == true
      assert caps.native_arrays == false
      assert caps.supports_json_operators == false
    end

    test "supported_operators returns conservative set for scalars" do
      ops = EctoAdapter.supported_operators(:scalar, :string)

      assert :_eq in ops
      assert :_neq in ops
      assert :_gt in ops
      assert :_like in ops
      # Should NOT include database-specific operators
      refute :_ilike in ops
    end

    test "supported_operators returns minimal set for arrays" do
      ops = EctoAdapter.supported_operators(:array, :string)

      # Only null check for generic adapter
      assert :_is_null in ops
      refute :_includes in ops
    end

    test "supported_operators returns empty for json" do
      ops = EctoAdapter.supported_operators(:json, :map)
      assert ops == []
    end
  end

  describe "ClickHouse adapter" do
    alias GreenFairy.CQL.Adapters.ClickHouse

    test "supports NULLS FIRST/LAST sort directions" do
      directions = ClickHouse.sort_directions()

      assert :asc in directions
      assert :desc in directions
      assert :asc_nulls_first in directions
      assert :desc_nulls_last in directions
    end

    test "does not support geo ordering" do
      refute ClickHouse.supports_geo_ordering?()
    end

    test "supports priority ordering" do
      assert ClickHouse.supports_priority_ordering?()
    end

    test "capabilities indicate native arrays" do
      caps = ClickHouse.capabilities()
      assert caps.native_arrays == true
      assert caps.column_oriented == true
    end

    test "supported_operators includes ilike for scalars" do
      ops = ClickHouse.supported_operators(:scalar, :string)

      assert :_eq in ops
      assert :_ilike in ops
      assert :_nilike in ops
    end

    test "supported_operators includes all array operations" do
      ops = ClickHouse.supported_operators(:array, :string)

      assert :_includes in ops
      assert :_excludes in ops
      assert :_includes_all in ops
      assert :_includes_any in ops
      assert :_is_empty in ops
    end
  end
end
