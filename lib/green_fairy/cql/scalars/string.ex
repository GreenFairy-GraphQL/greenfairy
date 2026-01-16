defmodule GreenFairy.CQL.Scalars.String do
  @moduledoc """
  CQL scalar for string fields.

  Provides string comparison and pattern matching operators,
  delegating to adapter-specific implementations.

  ## Operators

  - `:_eq` / `:_neq` - Equality/inequality
  - `:_gt` / `:_gte` / `:_lt` / `:_lte` - Comparison
  - `:_in` / `:_nin` - List membership
  - `:_like` / `:_nlike` - Pattern matching (case-sensitive)
  - `:_ilike` / `:_nilike` - Pattern matching (case-insensitive)
  - `:_starts_with` / `:_istarts_with` - Prefix matching
  - `:_ends_with` / `:_iends_with` - Suffix matching
  - `:_contains` / `:_icontains` - Substring matching
  - `:_is_null` - Null check

  ## Adapter Variations

  - **PostgreSQL**: Native `ILIKE` support
  - **MySQL/SQLite/MSSQL**: Emulate `ILIKE` with `LOWER() LIKE LOWER()`
  - **Exlasticsearch**: Full-text search operators (`:_match`, `:_fuzzy`)
  """

  @behaviour GreenFairy.CQL.Scalar

  @impl true
  def operator_input(:postgres), do: __MODULE__.Postgres.operator_input()
  def operator_input(:mysql), do: __MODULE__.MySQL.operator_input()
  def operator_input(:sqlite), do: __MODULE__.SQLite.operator_input()
  def operator_input(:mssql), do: __MODULE__.MSSQL.operator_input()
  def operator_input(:clickhouse), do: __MODULE__.ClickHouse.operator_input()
  def operator_input(:elasticsearch), do: __MODULE__.Exlasticsearch.operator_input()
  def operator_input(:ecto), do: __MODULE__.Ecto.operator_input()
  # Fallback for unknown adapters
  def operator_input(_), do: __MODULE__.Ecto.operator_input()

  @impl true
  def apply_operator(query, field, operator, value, :postgres, opts) do
    __MODULE__.Postgres.apply_operator(query, field, operator, value, opts)
  end

  def apply_operator(query, field, operator, value, :mysql, opts) do
    __MODULE__.MySQL.apply_operator(query, field, operator, value, opts)
  end

  def apply_operator(query, field, operator, value, :sqlite, opts) do
    __MODULE__.SQLite.apply_operator(query, field, operator, value, opts)
  end

  def apply_operator(query, field, operator, value, :mssql, opts) do
    __MODULE__.MSSQL.apply_operator(query, field, operator, value, opts)
  end

  def apply_operator(query, field, operator, value, :clickhouse, opts) do
    __MODULE__.ClickHouse.apply_operator(query, field, operator, value, opts)
  end

  def apply_operator(query, field, operator, value, :elasticsearch, opts) do
    __MODULE__.Exlasticsearch.apply_operator(query, field, operator, value, opts)
  end

  def apply_operator(query, field, operator, value, :ecto, opts) do
    __MODULE__.Ecto.apply_operator(query, field, operator, value, opts)
  end

  # Fallback for unknown adapters
  def apply_operator(query, field, operator, value, _unknown, opts) do
    __MODULE__.Ecto.apply_operator(query, field, operator, value, opts)
  end

  @impl true
  def operator_type_identifier(_adapter), do: :cql_op_string_input
end
