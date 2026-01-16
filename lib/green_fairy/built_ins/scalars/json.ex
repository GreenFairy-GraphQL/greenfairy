defmodule GreenFairy.BuiltIns.Scalars.JSON do
  @moduledoc """
  GraphQL scalar for arbitrary JSON values with full CQL support.

  This scalar handles JSON/JSONB fields in your database, providing both
  GraphQL serialization and powerful filtering operators.

  ## GraphQL Usage

  Fields using this scalar accept and return arbitrary JSON:

      query {
        product(id: "1") {
          metadata  # Returns: {"color": "red", "size": "large"}
        }
      }

      mutation {
        updateProduct(id: "1", input: {
          metadata: {color: "blue", tags: ["sale", "featured"]}
        }) {
          metadata
        }
      }

  ## CQL Filtering

  Filter JSON fields using these operators:

      # Exact match
      products(where: {metadata: {_eq: {color: "red"}}})

      # Contains - JSON contains the given structure
      products(where: {metadata: {_contains: {color: "red"}}})

      # Has key - JSON has a specific key
      products(where: {metadata: {_has_key: "color"}})

      # Has all keys (PostgreSQL)
      products(where: {metadata: {_has_keys: ["color", "size"]}})

      # Has any keys (PostgreSQL)
      products(where: {metadata: {_has_any_keys: ["color", "brand"]}})

  ## Database Support

  | Operator | PostgreSQL | MySQL | SQLite | MSSQL |
  |----------|------------|-------|--------|-------|
  | `_eq` | ✅ | ✅ | ✅ | ✅ |
  | `_neq` | ✅ | ✅ | ✅ | ✅ |
  | `_contains` | ✅ | ✅ | ❌ | ❌ |
  | `_contained_by` | ✅ | ✅ | ❌ | ❌ |
  | `_has_key` | ✅ | ✅ | ✅ | ✅ |
  | `_has_keys` | ✅ | ❌ | ❌ | ❌ |
  | `_has_any_keys` | ✅ | ❌ | ❌ | ❌ |
  | `_is_null` | ✅ | ✅ | ✅ | ✅ |
  """

  use GreenFairy.Scalar
  @behaviour GreenFairy.CQL.Scalar

  import Ecto.Query, only: [where: 3]

  scalar "JSON" do
    description "Arbitrary JSON value"

    parse fn
      %Absinthe.Blueprint.Input.String{value: value}, _ ->
        case Jason.decode(value) do
          {:ok, result} -> {:ok, result}
          _ -> :error
        end

      %Absinthe.Blueprint.Input.Null{}, _ ->
        {:ok, nil}

      # Already-decoded values (objects, lists, etc.)
      value, _ when is_map(value) or is_list(value) ->
        {:ok, value}

      value, _ when is_number(value) or is_boolean(value) ->
        {:ok, value}

      _, _ ->
        :error
    end

    serialize fn
      nil -> nil
      value -> value
    end
  end

  # ============================================================================
  # CQL Scalar Behaviour Implementation
  # ============================================================================

  @impl GreenFairy.CQL.Scalar
  def operator_input(:postgres), do: __MODULE__.Postgres.operator_input()
  def operator_input(:mysql), do: __MODULE__.MySQL.operator_input()
  def operator_input(:sqlite), do: __MODULE__.SQLite.operator_input()
  def operator_input(:mssql), do: __MODULE__.MSSQL.operator_input()
  def operator_input(:elasticsearch), do: __MODULE__.Elasticsearch.operator_input()
  def operator_input(_), do: {[:_eq, :_neq, :_is_null], :json, "Basic JSON operators"}

  @impl GreenFairy.CQL.Scalar
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

  def apply_operator(query, field, operator, value, :elasticsearch, opts) do
    __MODULE__.Elasticsearch.apply_operator(query, field, operator, value, opts)
  end

  def apply_operator(query, _field, _operator, _value, _adapter, _opts), do: query

  @impl GreenFairy.CQL.Scalar
  def operator_type_identifier(_adapter), do: :cql_op_json_input

  # ============================================================================
  # PostgreSQL Implementation - Native JSONB operators
  # ============================================================================

  defmodule Postgres do
    @moduledoc false
    import Ecto.Query, only: [where: 3]

    def operator_input do
      {[
         :_eq,
         :_neq,
         :_contains,
         :_contained_by,
         :_has_key,
         :_has_keys,
         :_has_any_keys,
         :_is_null
       ], :json, "PostgreSQL JSONB operators"}
    end

    def apply_operator(query, field, operator, value, opts) do
      binding = Keyword.get(opts, :binding)

      case operator do
        :_eq -> apply_eq(query, field, value, binding)
        :_neq -> apply_neq(query, field, value, binding)
        :_contains -> apply_contains(query, field, value, binding)
        :_contained_by -> apply_contained_by(query, field, value, binding)
        :_has_key -> apply_has_key(query, field, value, binding)
        :_has_keys -> apply_has_keys(query, field, value, binding)
        :_has_any_keys -> apply_has_any_keys(query, field, value, binding)
        :_is_null -> apply_is_null(query, field, value, binding)
        _ -> query
      end
    end

    defp apply_eq(query, field, value, nil) do
      json = encode(value)
      where(query, [q], fragment("?::jsonb = ?::jsonb", field(q, ^field), ^json))
    end

    defp apply_eq(query, field, value, binding) do
      json = encode(value)
      where(query, [{^binding, a}], fragment("?::jsonb = ?::jsonb", field(a, ^field), ^json))
    end

    defp apply_neq(query, field, value, nil) do
      json = encode(value)
      where(query, [q], fragment("?::jsonb != ?::jsonb", field(q, ^field), ^json))
    end

    defp apply_neq(query, field, value, binding) do
      json = encode(value)
      where(query, [{^binding, a}], fragment("?::jsonb != ?::jsonb", field(a, ^field), ^json))
    end

    defp apply_contains(query, field, value, nil) do
      json = encode(value)
      where(query, [q], fragment("? @> ?::jsonb", field(q, ^field), ^json))
    end

    defp apply_contains(query, field, value, binding) do
      json = encode(value)
      where(query, [{^binding, a}], fragment("? @> ?::jsonb", field(a, ^field), ^json))
    end

    defp apply_contained_by(query, field, value, nil) do
      json = encode(value)
      where(query, [q], fragment("? <@ ?::jsonb", field(q, ^field), ^json))
    end

    defp apply_contained_by(query, field, value, binding) do
      json = encode(value)
      where(query, [{^binding, a}], fragment("? <@ ?::jsonb", field(a, ^field), ^json))
    end

    defp apply_has_key(query, field, key, nil) do
      where(query, [q], fragment("? \\? ?", field(q, ^field), ^key))
    end

    defp apply_has_key(query, field, key, binding) do
      where(query, [{^binding, a}], fragment("? \\? ?", field(a, ^field), ^key))
    end

    defp apply_has_keys(query, field, keys, nil) when is_list(keys) do
      where(query, [q], fragment("? \\?& ?::text[]", field(q, ^field), ^keys))
    end

    defp apply_has_keys(query, field, keys, binding) when is_list(keys) do
      where(query, [{^binding, a}], fragment("? \\?& ?::text[]", field(a, ^field), ^keys))
    end

    defp apply_has_any_keys(query, field, keys, nil) when is_list(keys) do
      where(query, [q], fragment("? \\?| ?::text[]", field(q, ^field), ^keys))
    end

    defp apply_has_any_keys(query, field, keys, binding) when is_list(keys) do
      where(query, [{^binding, a}], fragment("? \\?| ?::text[]", field(a, ^field), ^keys))
    end

    defp apply_is_null(query, field, true, nil), do: where(query, [q], is_nil(field(q, ^field)))
    defp apply_is_null(query, field, false, nil), do: where(query, [q], not is_nil(field(q, ^field)))
    defp apply_is_null(query, field, true, binding), do: where(query, [{^binding, a}], is_nil(field(a, ^field)))
    defp apply_is_null(query, field, false, binding), do: where(query, [{^binding, a}], not is_nil(field(a, ^field)))

    defp encode(value) when is_binary(value), do: value
    defp encode(value), do: Jason.encode!(value)
  end

  # ============================================================================
  # MySQL Implementation - JSON functions
  # ============================================================================

  defmodule MySQL do
    @moduledoc false
    import Ecto.Query, only: [where: 3]

    def operator_input do
      {[
         :_eq,
         :_neq,
         :_contains,
         :_contained_by,
         :_has_key,
         :_is_null
       ], :json, "MySQL JSON operators"}
    end

    def apply_operator(query, field, operator, value, opts) do
      binding = Keyword.get(opts, :binding)

      case operator do
        :_eq -> apply_eq(query, field, value, binding)
        :_neq -> apply_neq(query, field, value, binding)
        :_contains -> apply_contains(query, field, value, binding)
        :_contained_by -> apply_contained_by(query, field, value, binding)
        :_has_key -> apply_has_key(query, field, value, binding)
        :_is_null -> apply_is_null(query, field, value, binding)
        _ -> query
      end
    end

    defp apply_eq(query, field, value, nil) do
      json = encode(value)
      where(query, [q], fragment("JSON_CONTAINS(?, ?, '$') AND JSON_CONTAINS(?, ?, '$')",
        field(q, ^field), ^json, ^json, field(q, ^field)))
    end

    defp apply_eq(query, field, value, binding) do
      json = encode(value)
      where(query, [{^binding, a}], fragment("JSON_CONTAINS(?, ?, '$') AND JSON_CONTAINS(?, ?, '$')",
        field(a, ^field), ^json, ^json, field(a, ^field)))
    end

    defp apply_neq(query, field, value, nil) do
      json = encode(value)
      where(query, [q], fragment("NOT (JSON_CONTAINS(?, ?, '$') AND JSON_CONTAINS(?, ?, '$'))",
        field(q, ^field), ^json, ^json, field(q, ^field)))
    end

    defp apply_neq(query, field, value, binding) do
      json = encode(value)
      where(query, [{^binding, a}], fragment("NOT (JSON_CONTAINS(?, ?, '$') AND JSON_CONTAINS(?, ?, '$'))",
        field(a, ^field), ^json, ^json, field(a, ^field)))
    end

    defp apply_contains(query, field, value, nil) do
      json = encode(value)
      where(query, [q], fragment("JSON_CONTAINS(?, ?)", field(q, ^field), ^json))
    end

    defp apply_contains(query, field, value, binding) do
      json = encode(value)
      where(query, [{^binding, a}], fragment("JSON_CONTAINS(?, ?)", field(a, ^field), ^json))
    end

    defp apply_contained_by(query, field, value, nil) do
      json = encode(value)
      where(query, [q], fragment("JSON_CONTAINS(?, ?)", ^json, field(q, ^field)))
    end

    defp apply_contained_by(query, field, value, binding) do
      json = encode(value)
      where(query, [{^binding, a}], fragment("JSON_CONTAINS(?, ?)", ^json, field(a, ^field)))
    end

    defp apply_has_key(query, field, key, nil) do
      path = "$." <> key
      where(query, [q], fragment("JSON_CONTAINS_PATH(?, 'one', ?)", field(q, ^field), ^path))
    end

    defp apply_has_key(query, field, key, binding) do
      path = "$." <> key
      where(query, [{^binding, a}], fragment("JSON_CONTAINS_PATH(?, 'one', ?)", field(a, ^field), ^path))
    end

    defp apply_is_null(query, field, true, nil), do: where(query, [q], is_nil(field(q, ^field)))
    defp apply_is_null(query, field, false, nil), do: where(query, [q], not is_nil(field(q, ^field)))
    defp apply_is_null(query, field, true, binding), do: where(query, [{^binding, a}], is_nil(field(a, ^field)))
    defp apply_is_null(query, field, false, binding), do: where(query, [{^binding, a}], not is_nil(field(a, ^field)))

    defp encode(value) when is_binary(value), do: value
    defp encode(value), do: Jason.encode!(value)
  end

  # ============================================================================
  # SQLite Implementation - JSON1 extension
  # ============================================================================

  defmodule SQLite do
    @moduledoc false
    import Ecto.Query, only: [where: 3]

    def operator_input do
      {[:_eq, :_neq, :_has_key, :_is_null], :json, "SQLite JSON operators (JSON1 extension)"}
    end

    def apply_operator(query, field, operator, value, opts) do
      binding = Keyword.get(opts, :binding)

      case operator do
        :_eq -> apply_eq(query, field, value, binding)
        :_neq -> apply_neq(query, field, value, binding)
        :_has_key -> apply_has_key(query, field, value, binding)
        :_is_null -> apply_is_null(query, field, value, binding)
        _ -> query
      end
    end

    defp apply_eq(query, field, value, nil) do
      json = encode(value)
      where(query, [q], fragment("json(?) = json(?)", field(q, ^field), ^json))
    end

    defp apply_eq(query, field, value, binding) do
      json = encode(value)
      where(query, [{^binding, a}], fragment("json(?) = json(?)", field(a, ^field), ^json))
    end

    defp apply_neq(query, field, value, nil) do
      json = encode(value)
      where(query, [q], fragment("json(?) != json(?)", field(q, ^field), ^json))
    end

    defp apply_neq(query, field, value, binding) do
      json = encode(value)
      where(query, [{^binding, a}], fragment("json(?) != json(?)", field(a, ^field), ^json))
    end

    defp apply_has_key(query, field, key, nil) do
      path = "$." <> key
      where(query, [q], fragment("json_type(?, ?) IS NOT NULL", field(q, ^field), ^path))
    end

    defp apply_has_key(query, field, key, binding) do
      path = "$." <> key
      where(query, [{^binding, a}], fragment("json_type(?, ?) IS NOT NULL", field(a, ^field), ^path))
    end

    defp apply_is_null(query, field, true, nil), do: where(query, [q], is_nil(field(q, ^field)))
    defp apply_is_null(query, field, false, nil), do: where(query, [q], not is_nil(field(q, ^field)))
    defp apply_is_null(query, field, true, binding), do: where(query, [{^binding, a}], is_nil(field(a, ^field)))
    defp apply_is_null(query, field, false, binding), do: where(query, [{^binding, a}], not is_nil(field(a, ^field)))

    defp encode(value) when is_binary(value), do: value
    defp encode(value), do: Jason.encode!(value)
  end

  # ============================================================================
  # MSSQL Implementation - JSON functions (SQL Server 2016+)
  # ============================================================================

  defmodule MSSQL do
    @moduledoc false
    import Ecto.Query, only: [where: 3]

    def operator_input do
      {[:_eq, :_neq, :_has_key, :_is_null], :json, "MSSQL JSON operators"}
    end

    def apply_operator(query, field, operator, value, opts) do
      binding = Keyword.get(opts, :binding)

      case operator do
        :_eq -> apply_eq(query, field, value, binding)
        :_neq -> apply_neq(query, field, value, binding)
        :_has_key -> apply_has_key(query, field, value, binding)
        :_is_null -> apply_is_null(query, field, value, binding)
        _ -> query
      end
    end

    defp apply_eq(query, field, value, nil) do
      json = encode(value)
      where(query, [q], fragment("CAST(? AS NVARCHAR(MAX)) = ?", field(q, ^field), ^json))
    end

    defp apply_eq(query, field, value, binding) do
      json = encode(value)
      where(query, [{^binding, a}], fragment("CAST(? AS NVARCHAR(MAX)) = ?", field(a, ^field), ^json))
    end

    defp apply_neq(query, field, value, nil) do
      json = encode(value)
      where(query, [q], fragment("CAST(? AS NVARCHAR(MAX)) != ?", field(q, ^field), ^json))
    end

    defp apply_neq(query, field, value, binding) do
      json = encode(value)
      where(query, [{^binding, a}], fragment("CAST(? AS NVARCHAR(MAX)) != ?", field(a, ^field), ^json))
    end

    defp apply_has_key(query, field, key, nil) do
      path = "$." <> key
      where(query, [q], fragment("JSON_VALUE(?, ?) IS NOT NULL OR JSON_QUERY(?, ?) IS NOT NULL",
        field(q, ^field), ^path, field(q, ^field), ^path))
    end

    defp apply_has_key(query, field, key, binding) do
      path = "$." <> key
      where(query, [{^binding, a}], fragment("JSON_VALUE(?, ?) IS NOT NULL OR JSON_QUERY(?, ?) IS NOT NULL",
        field(a, ^field), ^path, field(a, ^field), ^path))
    end

    defp apply_is_null(query, field, true, nil), do: where(query, [q], is_nil(field(q, ^field)))
    defp apply_is_null(query, field, false, nil), do: where(query, [q], not is_nil(field(q, ^field)))
    defp apply_is_null(query, field, true, binding), do: where(query, [{^binding, a}], is_nil(field(a, ^field)))
    defp apply_is_null(query, field, false, binding), do: where(query, [{^binding, a}], not is_nil(field(a, ^field)))

    defp encode(value) when is_binary(value), do: value
    defp encode(value), do: Jason.encode!(value)
  end

  # ============================================================================
  # Elasticsearch Implementation
  # ============================================================================

  defmodule Elasticsearch do
    @moduledoc false

    def operator_input do
      {[:_eq, :_neq, :_contains, :_has_key, :_is_null], :json, "Elasticsearch object operators"}
    end

    def apply_operator(query, field, operator, value, opts) do
      field_path = build_field_path(field, opts)

      case operator do
        :_eq -> add_filter(query, %{term: %{field_path => value}})
        :_neq -> add_filter(query, %{bool: %{must_not: [%{term: %{field_path => value}}]}})
        :_contains -> apply_contains(query, field_path, value)
        :_has_key -> add_filter(query, %{exists: %{field: "#{field_path}.#{value}"}})
        :_is_null when value == true -> add_filter(query, %{bool: %{must_not: [%{exists: %{field: field_path}}]}})
        :_is_null when value == false -> add_filter(query, %{exists: %{field: field_path}})
        _ -> query
      end
    end

    defp build_field_path(field, opts) do
      case Keyword.get(opts, :nested_path) do
        nil -> to_string(field)
        path -> "#{path}.#{field}"
      end
    end

    defp apply_contains(query, field_path, value) when is_map(value) do
      conditions = Enum.map(value, fn {k, v} ->
        %{term: %{"#{field_path}.#{k}" => v}}
      end)

      add_filter(query, %{bool: %{must: conditions}})
    end

    defp apply_contains(query, _field_path, _value), do: query

    defp add_filter(query, filter) when is_map(query) do
      existing = get_in(query, [:bool, :filter]) || []
      put_in(query, [:bool, :filter], existing ++ [filter])
    end

    defp add_filter(query, filter) do
      %{bool: %{filter: [filter], must: [query]}}
    end
  end
end
