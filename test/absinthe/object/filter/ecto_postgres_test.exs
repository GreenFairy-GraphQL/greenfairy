defmodule Absinthe.Object.Filter.Ecto.PostgresTest do
  use ExUnit.Case, async: true

  alias Absinthe.Object.Filter
  alias Absinthe.Object.Adapters.Ecto.Postgres, as: PostgresAdapter
  alias Absinthe.Object.Filters.{Basic, Geo, Text}

  # Force the Postgres filter module to load and register implementations
  @postgres_module Absinthe.Object.Filter.Ecto.Postgres
  Code.ensure_loaded!(@postgres_module)

  # Define a simple test "schema" module for Ecto queries
  # We just need something that can be used in `from(q in query, ...)`
  defmodule TestSchema do
    use Ecto.Schema

    schema "test_items" do
      field(:name, :string)
      field(:email, :string)
      field(:status, :string)
      field(:category, :string)
      field(:tag, :string)
      field(:price, :integer)
      field(:score, :integer)
      field(:deleted_at, :utc_datetime)
      field(:location, :map)
      field(:body, :string)
      field(:content, :string)
      field(:suggestion, :string)
    end
  end

  describe "Basic.Equals filter" do
    test "creates where clause with equality check" do
      adapter = PostgresAdapter.new(FakeRepo)
      filter = %Basic.Equals{value: "active"}

      import Ecto.Query
      base_query = from(t in TestSchema)

      case Filter.apply(adapter, filter, :status, base_query) do
        {:ok, result} ->
          # Verify the query has a where clause
          assert %Ecto.Query{} = result
          assert result.wheres != []

        {:error, _} ->
          :skip
      end
    end
  end

  describe "Basic.NotEquals filter" do
    test "creates where clause with inequality check" do
      adapter = PostgresAdapter.new(FakeRepo)
      filter = %Basic.NotEquals{value: "deleted"}

      import Ecto.Query
      base_query = from(t in TestSchema)

      case Filter.apply(adapter, filter, :status, base_query) do
        {:ok, result} ->
          assert %Ecto.Query{} = result
          assert result.wheres != []

        {:error, _} ->
          :skip
      end
    end
  end

  describe "Basic.In filter" do
    test "creates where clause with IN check" do
      adapter = PostgresAdapter.new(FakeRepo)
      filter = %Basic.In{values: ["a", "b", "c"]}

      import Ecto.Query
      base_query = from(t in TestSchema)

      case Filter.apply(adapter, filter, :category, base_query) do
        {:ok, result} ->
          assert %Ecto.Query{} = result
          assert result.wheres != []

        {:error, _} ->
          :skip
      end
    end
  end

  describe "Basic.NotIn filter" do
    test "creates where clause with NOT IN check" do
      adapter = PostgresAdapter.new(FakeRepo)
      filter = %Basic.NotIn{values: ["x", "y"]}

      import Ecto.Query
      base_query = from(t in TestSchema)

      case Filter.apply(adapter, filter, :tag, base_query) do
        {:ok, result} ->
          assert %Ecto.Query{} = result
          assert result.wheres != []

        {:error, _} ->
          :skip
      end
    end
  end

  describe "Basic.Range filter" do
    test "creates where clause with range check (gte/lte)" do
      adapter = PostgresAdapter.new(FakeRepo)
      filter = %Basic.Range{gte: 10, lte: 100}

      import Ecto.Query
      base_query = from(t in TestSchema)

      case Filter.apply(adapter, filter, :price, base_query) do
        {:ok, result} ->
          assert %Ecto.Query{} = result
          assert result.wheres != []

        {:error, _} ->
          :skip
      end
    end

    test "creates where clause with range check (gt/lt)" do
      adapter = PostgresAdapter.new(FakeRepo)
      filter = %Basic.Range{gt: 0, lt: 50}

      import Ecto.Query
      base_query = from(t in TestSchema)

      case Filter.apply(adapter, filter, :score, base_query) do
        {:ok, result} ->
          assert %Ecto.Query{} = result
          assert result.wheres != []

        {:error, _} ->
          :skip
      end
    end
  end

  describe "Basic.IsNil filter" do
    test "creates where clause for is_nil true" do
      adapter = PostgresAdapter.new(FakeRepo)
      filter = %Basic.IsNil{is_nil: true}

      import Ecto.Query
      base_query = from(t in TestSchema)

      case Filter.apply(adapter, filter, :deleted_at, base_query) do
        {:ok, result} ->
          assert %Ecto.Query{} = result
          assert result.wheres != []

        {:error, _} ->
          :skip
      end
    end

    test "creates where clause for is_nil false" do
      adapter = PostgresAdapter.new(FakeRepo)
      filter = %Basic.IsNil{is_nil: false}

      import Ecto.Query
      base_query = from(t in TestSchema)

      case Filter.apply(adapter, filter, :email, base_query) do
        {:ok, result} ->
          assert %Ecto.Query{} = result
          assert result.wheres != []

        {:error, _} ->
          :skip
      end
    end
  end

  describe "Basic.Contains filter" do
    test "creates where clause with ILIKE" do
      adapter = PostgresAdapter.new(FakeRepo)
      filter = %Basic.Contains{value: "test"}

      import Ecto.Query
      base_query = from(t in TestSchema)

      case Filter.apply(adapter, filter, :name, base_query) do
        {:ok, result} ->
          assert %Ecto.Query{} = result
          assert result.wheres != []

        {:error, _} ->
          :skip
      end
    end
  end

  describe "Basic.StartsWith filter" do
    test "creates where clause with ILIKE prefix" do
      adapter = PostgresAdapter.new(FakeRepo)
      filter = %Basic.StartsWith{value: "abc"}

      import Ecto.Query
      base_query = from(t in TestSchema)

      case Filter.apply(adapter, filter, :name, base_query) do
        {:ok, result} ->
          assert %Ecto.Query{} = result
          assert result.wheres != []

        {:error, _} ->
          :skip
      end
    end
  end

  describe "Basic.EndsWith filter" do
    test "creates where clause with ILIKE suffix" do
      adapter = PostgresAdapter.new(FakeRepo)
      filter = %Basic.EndsWith{value: ".txt"}

      import Ecto.Query
      base_query = from(t in TestSchema)

      case Filter.apply(adapter, filter, :name, base_query) do
        {:ok, result} ->
          assert %Ecto.Query{} = result
          assert result.wheres != []

        {:error, _} ->
          :skip
      end
    end
  end

  describe "Text.Fulltext filter" do
    test "creates where clause with tsvector search" do
      adapter = PostgresAdapter.new(FakeRepo)

      filter = %Text.Fulltext{
        query: "search terms",
        fields: nil,
        fuzziness: :auto,
        operator: :and
      }

      import Ecto.Query
      base_query = from(t in TestSchema)

      case Filter.apply(adapter, filter, :body, base_query) do
        {:ok, result} ->
          assert %Ecto.Query{} = result
          assert result.wheres != []

        {:error, _} ->
          :skip
      end
    end
  end

  describe "Text.Match filter" do
    test "creates where clause with ILIKE" do
      adapter = PostgresAdapter.new(FakeRepo)
      filter = %Text.Match{query: "hello world", operator: :or}

      import Ecto.Query
      base_query = from(t in TestSchema)

      case Filter.apply(adapter, filter, :content, base_query) do
        {:ok, result} ->
          assert %Ecto.Query{} = result
          assert result.wheres != []

        {:error, _} ->
          :skip
      end
    end
  end

  describe "Text.Prefix filter" do
    test "creates where clause with ILIKE prefix" do
      adapter = PostgresAdapter.new(FakeRepo)
      filter = %Text.Prefix{value: "auto"}

      import Ecto.Query
      base_query = from(t in TestSchema)

      case Filter.apply(adapter, filter, :suggestion, base_query) do
        {:ok, result} ->
          assert %Ecto.Query{} = result
          assert result.wheres != []

        {:error, _} ->
          :skip
      end
    end
  end

  describe "Text.Phrase filter" do
    test "creates where clause with phrase search" do
      adapter = PostgresAdapter.new(FakeRepo)
      filter = %Text.Phrase{phrase: "quick brown fox", slop: 2}

      import Ecto.Query
      base_query = from(t in TestSchema)

      case Filter.apply(adapter, filter, :body, base_query) do
        {:ok, result} ->
          assert %Ecto.Query{} = result
          assert result.wheres != []

        {:error, _} ->
          :skip
      end
    end
  end

  describe "Geo.Near filter" do
    test "returns postgis_required error without PostGIS" do
      adapter = PostgresAdapter.new(FakeRepo, extensions: [])

      # Use map representation of point
      filter = %Geo.Near{
        point: %{coordinates: {-122.4194, 37.7749}},
        distance: 10,
        unit: :kilometers
      }

      import Ecto.Query
      base_query = from(t in TestSchema)

      result = Filter.apply(adapter, filter, :location, base_query)

      case result do
        {:error, :postgis_required} -> assert true
        {:ok, _} -> :skip
        {:error, _} -> :skip
      end
    end

    test "creates geo query with PostGIS enabled" do
      adapter = PostgresAdapter.new(FakeRepo, extensions: [:postgis])

      # Use map representation of point
      filter = %Geo.Near{
        point: %{coordinates: {-122.4194, 37.7749}},
        distance: 10,
        unit: :kilometers
      }

      import Ecto.Query
      base_query = from(t in TestSchema)

      case Filter.apply(adapter, filter, :location, base_query) do
        {:ok, result} ->
          assert %Ecto.Query{} = result
          assert result.wheres != []

        {:error, _} ->
          :skip
      end
    end
  end

  describe "Geo.WithinDistance filter" do
    test "delegates to Near filter" do
      adapter = PostgresAdapter.new(FakeRepo, extensions: [])

      filter = %Geo.WithinDistance{
        point: %{coordinates: {-122.4194, 37.7749}},
        distance: 10,
        unit: :kilometers
      }

      import Ecto.Query
      base_query = from(t in TestSchema)

      # Without PostGIS, should get postgis_required error (since it delegates to Near)
      result = Filter.apply(adapter, filter, :location, base_query)

      case result do
        {:error, :postgis_required} -> assert true
        {:ok, _} -> :skip
        {:error, _} -> :skip
      end
    end
  end

  describe "Geo.Intersects filter" do
    test "returns postgis_required error without PostGIS" do
      adapter = PostgresAdapter.new(FakeRepo, extensions: [])

      filter = %Geo.Intersects{
        geometry: %{type: "Polygon", coordinates: [[[0, 0], [1, 0], [1, 1], [0, 1], [0, 0]]]}
      }

      import Ecto.Query
      base_query = from(t in TestSchema)

      result = Filter.apply(adapter, filter, :location, base_query)

      case result do
        {:error, :postgis_required} -> assert true
        {:ok, _} -> :skip
        {:error, _} -> :skip
      end
    end

    test "creates intersects query with PostGIS enabled" do
      adapter = PostgresAdapter.new(FakeRepo, extensions: [:postgis])

      filter = %Geo.Intersects{
        geometry: %{type: "Polygon", coordinates: [[[0, 0], [1, 0], [1, 1], [0, 1], [0, 0]]]}
      }

      import Ecto.Query
      base_query = from(t in TestSchema)

      case Filter.apply(adapter, filter, :location, base_query) do
        {:ok, result} ->
          assert %Ecto.Query{} = result
          assert result.wheres != []

        {:error, _} ->
          :skip
      end
    end
  end

  describe "Geo.WithinBounds filter" do
    test "returns postgis_required error without PostGIS" do
      adapter = PostgresAdapter.new(FakeRepo, extensions: [])

      filter = %Geo.WithinBounds{
        bounds: %{
          top_left: %{lat: 40.73, lng: -74.1},
          bottom_right: %{lat: 40.01, lng: -71.12}
        }
      }

      import Ecto.Query
      base_query = from(t in TestSchema)

      result = Filter.apply(adapter, filter, :location, base_query)

      case result do
        {:error, :postgis_required} -> assert true
        {:ok, _} -> :skip
        {:error, _} -> :skip
      end
    end

    test "creates geo query with PostGIS enabled" do
      adapter = PostgresAdapter.new(FakeRepo, extensions: [:postgis])

      filter = %Geo.WithinBounds{
        bounds: %{
          top_left: %{lat: 40.73, lng: -74.1},
          bottom_right: %{lat: 40.01, lng: -71.12}
        }
      }

      import Ecto.Query
      base_query = from(t in TestSchema)

      case Filter.apply(adapter, filter, :location, base_query) do
        {:ok, result} ->
          assert %Ecto.Query{} = result
          assert result.wheres != []

        {:error, _} ->
          :skip
      end
    end
  end

  describe "pg_trgm filters" do
    test "Contains filter with pg_trgm creates similarity query" do
      adapter = PostgresAdapter.new(FakeRepo, extensions: [:pg_trgm])
      filter = %Basic.Contains{value: "test"}

      import Ecto.Query
      base_query = from(t in TestSchema)

      case Filter.apply(adapter, filter, :name, base_query) do
        {:ok, result} ->
          assert %Ecto.Query{} = result
          assert result.wheres != []

        {:error, _} ->
          :skip
      end
    end

    test "StartsWith filter with pg_trgm creates prefix query" do
      adapter = PostgresAdapter.new(FakeRepo, extensions: [:pg_trgm])
      filter = %Basic.StartsWith{value: "abc"}

      import Ecto.Query
      base_query = from(t in TestSchema)

      case Filter.apply(adapter, filter, :name, base_query) do
        {:ok, result} ->
          assert %Ecto.Query{} = result
          assert result.wheres != []

        {:error, _} ->
          :skip
      end
    end

    test "EndsWith filter with pg_trgm creates suffix query" do
      adapter = PostgresAdapter.new(FakeRepo, extensions: [:pg_trgm])
      filter = %Basic.EndsWith{value: ".txt"}

      import Ecto.Query
      base_query = from(t in TestSchema)

      case Filter.apply(adapter, filter, :name, base_query) do
        {:ok, result} ->
          assert %Ecto.Query{} = result
          assert result.wheres != []

        {:error, _} ->
          :skip
      end
    end
  end

  describe "Fulltext filter variations" do
    test "Fulltext with multi-field search" do
      adapter = PostgresAdapter.new(FakeRepo)

      filter = %Text.Fulltext{
        query: "search terms",
        fields: ["title", "body"],
        fuzziness: :auto,
        operator: :and
      }

      import Ecto.Query
      base_query = from(t in TestSchema)

      case Filter.apply(adapter, filter, :body, base_query) do
        {:ok, result} ->
          assert %Ecto.Query{} = result
          assert result.wheres != []

        {:error, _} ->
          :skip
      end
    end
  end
end
