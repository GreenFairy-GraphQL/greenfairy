defmodule Absinthe.Object.Filter.Ecto.Postgres do
  @moduledoc """
  Filter implementations for PostgreSQL with PostGIS support.

  This module provides filter implementations for the PostgreSQL adapter,
  including PostGIS spatial functions and pg_trgm text search.

  ## Geo Filters

  Geo filters require the PostGIS extension. If PostGIS is not enabled
  in the adapter, geo filters will return `{:error, :postgis_required}`.

  ## Text Filters

  Full-text search uses PostgreSQL's built-in `tsvector` and `tsquery`.
  Fuzzy matching can use `pg_trgm` if enabled.

  """

  use Absinthe.Object.Filter.Impl,
    adapter: Absinthe.Object.Adapters.Ecto.Postgres

  alias Absinthe.Object.Filters.{Geo, Text, Basic}

  # ===========================================================================
  # Geo Filters
  # ===========================================================================

  filter_impl Geo.Near do
    import Ecto.Query
    alias Absinthe.Object.Adapters.Ecto.Postgres, as: PostgresAdapter

    def apply(%PostgresAdapter{} = adapter, %{point: point, distance: dist, unit: unit}, field, query) do
      if PostgresAdapter.postgis?(adapter) do
        distance_meters = to_meters(dist, unit)

        result =
          from(q in query,
            where:
              fragment(
                "ST_DWithin(?::geography, ?::geography, ?)",
                field(q, ^field),
                ^point,
                ^distance_meters
              )
          )

        {:ok, result}
      else
        {:error, :postgis_required}
      end
    end

    defp to_meters(distance, :meters), do: distance
    defp to_meters(distance, :kilometers), do: distance * 1000
    defp to_meters(distance, :miles), do: distance * 1609.34
  end

  filter_impl Geo.WithinDistance do
    alias Absinthe.Object.Filters.Geo
    alias Absinthe.Object.Adapters.Ecto.Postgres, as: PostgresAdapter

    def apply(%PostgresAdapter{} = adapter, %{point: point, distance: dist, unit: unit}, field, query) do
      # Delegate to Near implementation
      Absinthe.Object.Filter.apply(
        adapter,
        %Geo.Near{point: point, distance: dist, unit: unit},
        field,
        query
      )
    end
  end

  filter_impl Geo.WithinBounds do
    import Ecto.Query
    alias Absinthe.Object.Adapters.Ecto.Postgres, as: PostgresAdapter

    def apply(%PostgresAdapter{} = adapter, %{bounds: bounds}, field, query) do
      if PostgresAdapter.postgis?(adapter) do
        result =
          from(q in query,
            where: fragment("ST_Within(?, ?)", field(q, ^field), ^bounds)
          )

        {:ok, result}
      else
        {:error, :postgis_required}
      end
    end
  end

  filter_impl Geo.Intersects do
    import Ecto.Query
    alias Absinthe.Object.Adapters.Ecto.Postgres, as: PostgresAdapter

    def apply(%PostgresAdapter{} = adapter, %{geometry: geometry}, field, query) do
      if PostgresAdapter.postgis?(adapter) do
        result =
          from(q in query,
            where: fragment("ST_Intersects(?, ?)", field(q, ^field), ^geometry)
          )

        {:ok, result}
      else
        {:error, :postgis_required}
      end
    end
  end

  # ===========================================================================
  # Text Filters
  # ===========================================================================

  filter_impl Text.Fulltext do
    import Ecto.Query

    def apply(_adapter, %{query: search_query, fields: nil}, field, query) do
      result =
        from(q in query,
          where:
            fragment(
              "to_tsvector('english', ?) @@ plainto_tsquery('english', ?)",
              field(q, ^field),
              ^search_query
            )
        )

      {:ok, result}
    end

    def apply(_adapter, %{query: search_query, fields: fields}, _field, query) when is_list(fields) do
      # Multi-field search - build a dynamic tsvector from multiple fields
      # Note: This is simplified - in production you might want to use a generated tsvector column
      result =
        from(q in query,
          where:
            fragment(
              "to_tsvector('english', ?) @@ plainto_tsquery('english', ?)",
              fragment("concat_ws(' ', ?)", ^fields),
              ^search_query
            )
        )

      {:ok, result}
    end
  end

  filter_impl Text.Match do
    import Ecto.Query

    def apply(_adapter, %{query: match_query}, field, query) do
      pattern = "%#{match_query}%"

      result =
        from(q in query,
          where: ilike(field(q, ^field), ^pattern)
        )

      {:ok, result}
    end
  end

  filter_impl Text.Prefix do
    import Ecto.Query

    def apply(_adapter, %{value: prefix}, field, query) do
      pattern = "#{prefix}%"

      result =
        from(q in query,
          where: ilike(field(q, ^field), ^pattern)
        )

      {:ok, result}
    end
  end

  filter_impl Text.Phrase do
    import Ecto.Query

    def apply(_adapter, %{phrase: phrase, slop: slop}, field, query) do
      ts_query =
        if slop > 0 do
          # Use proximity search with slop
          phrase
          |> String.split()
          |> Enum.join(" <#{slop}> ")
        else
          phrase
        end

      result =
        from(q in query,
          where:
            fragment(
              "to_tsvector('english', ?) @@ phraseto_tsquery('english', ?)",
              field(q, ^field),
              ^ts_query
            )
        )

      {:ok, result}
    end
  end

  # ===========================================================================
  # Basic Filters
  # ===========================================================================

  filter_impl Basic.Equals do
    import Ecto.Query

    def apply(_adapter, %{value: value}, field, query) do
      {:ok, from(q in query, where: field(q, ^field) == ^value)}
    end
  end

  filter_impl Basic.NotEquals do
    import Ecto.Query

    def apply(_adapter, %{value: value}, field, query) do
      {:ok, from(q in query, where: field(q, ^field) != ^value)}
    end
  end

  filter_impl Basic.In do
    import Ecto.Query

    def apply(_adapter, %{values: values}, field, query) do
      {:ok, from(q in query, where: field(q, ^field) in ^values)}
    end
  end

  filter_impl Basic.NotIn do
    import Ecto.Query

    def apply(_adapter, %{values: values}, field, query) do
      {:ok, from(q in query, where: field(q, ^field) not in ^values)}
    end
  end

  filter_impl Basic.Range do
    import Ecto.Query

    def apply(_adapter, range, field, query) do
      result =
        query
        |> apply_range_bound(:gt, range.gt || range.min, field)
        |> apply_range_bound(:gte, range.gte, field)
        |> apply_range_bound(:lt, range.lt || range.max, field)
        |> apply_range_bound(:lte, range.lte, field)

      {:ok, result}
    end

    defp apply_range_bound(query, _op, nil, _field), do: query

    defp apply_range_bound(query, :gt, value, field) do
      from(q in query, where: field(q, ^field) > ^value)
    end

    defp apply_range_bound(query, :gte, value, field) do
      from(q in query, where: field(q, ^field) >= ^value)
    end

    defp apply_range_bound(query, :lt, value, field) do
      from(q in query, where: field(q, ^field) < ^value)
    end

    defp apply_range_bound(query, :lte, value, field) do
      from(q in query, where: field(q, ^field) <= ^value)
    end
  end

  filter_impl Basic.IsNil do
    import Ecto.Query

    def apply(_adapter, %{is_nil: true}, field, query) do
      {:ok, from(q in query, where: is_nil(field(q, ^field)))}
    end

    def apply(_adapter, %{is_nil: false}, field, query) do
      {:ok, from(q in query, where: not is_nil(field(q, ^field)))}
    end
  end

  filter_impl Basic.Contains do
    import Ecto.Query

    def apply(_adapter, %{value: value, case_sensitive: true}, field, query) do
      pattern = "%#{value}%"
      {:ok, from(q in query, where: like(field(q, ^field), ^pattern))}
    end

    def apply(_adapter, %{value: value, case_sensitive: false}, field, query) do
      pattern = "%#{value}%"
      {:ok, from(q in query, where: ilike(field(q, ^field), ^pattern))}
    end

    def apply(_adapter, %{value: value}, field, query) do
      # Default to case-insensitive
      pattern = "%#{value}%"
      {:ok, from(q in query, where: ilike(field(q, ^field), ^pattern))}
    end
  end

  filter_impl Basic.StartsWith do
    import Ecto.Query

    def apply(_adapter, %{value: value, case_sensitive: true}, field, query) do
      pattern = "#{value}%"
      {:ok, from(q in query, where: like(field(q, ^field), ^pattern))}
    end

    def apply(_adapter, %{value: value, case_sensitive: false}, field, query) do
      pattern = "#{value}%"
      {:ok, from(q in query, where: ilike(field(q, ^field), ^pattern))}
    end

    def apply(_adapter, %{value: value}, field, query) do
      # Default to case-insensitive
      pattern = "#{value}%"
      {:ok, from(q in query, where: ilike(field(q, ^field), ^pattern))}
    end
  end

  filter_impl Basic.EndsWith do
    import Ecto.Query

    def apply(_adapter, %{value: value, case_sensitive: true}, field, query) do
      pattern = "%#{value}"
      {:ok, from(q in query, where: like(field(q, ^field), ^pattern))}
    end

    def apply(_adapter, %{value: value, case_sensitive: false}, field, query) do
      pattern = "%#{value}"
      {:ok, from(q in query, where: ilike(field(q, ^field), ^pattern))}
    end

    def apply(_adapter, %{value: value}, field, query) do
      # Default to case-insensitive
      pattern = "%#{value}"
      {:ok, from(q in query, where: ilike(field(q, ^field), ^pattern))}
    end
  end
end
