defmodule GreenFairy.CQL.Scalars.ArrayString do
  @moduledoc """
  CQL scalar for string array fields.

  ## Operators

  - `:_includes` - Array contains value
  - `:_excludes` - Array does not contain value
  - `:_includes_all` - Array contains all values
  - `:_excludes_all` - Array contains none of the values
  - `:_includes_any` - Array contains any of the values
  - `:_excludes_any` - Array does not contain all values
  - `:_is_empty` - Array is empty
  - `:_is_null` - Array is null

  ## Adapter Variations

  - **PostgreSQL**: Native array operators (@>, &&)
  - **MySQL**: JSON_CONTAINS, JSON_OVERLAPS
  - **SQLite**: Limited JSON1 support
  - **MSSQL**: OPENJSON with EXISTS
  - **Exlasticsearch**: Native multi-value fields
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
  # Fallback for unknown adapters - minimal support
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
  def operator_type_identifier(_adapter), do: :cql_op_string_array_input
end
