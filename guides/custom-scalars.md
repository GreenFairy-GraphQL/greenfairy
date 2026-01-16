# Custom Scalars

This guide covers creating custom GraphQL scalar types in GreenFairy, including CQL filter integration with database-specific adapters.

## Basic Custom Scalar

Define a simple scalar with parse and serialize functions:

```elixir
defmodule MyApp.GraphQL.Scalars.DateTime do
  use GreenFairy.Scalar

  scalar "DateTime" do
    description "ISO 8601 datetime string"

    parse fn
      %Absinthe.Blueprint.Input.String{value: value} ->
        case DateTime.from_iso8601(value) do
          {:ok, datetime, _} -> {:ok, datetime}
          _ -> :error
        end
      _ -> :error
    end

    serialize fn datetime ->
      DateTime.to_iso8601(datetime)
    end
  end
end
```

## Scalar with CQL Operators

Add filtering support to your scalar:

```elixir
defmodule MyApp.GraphQL.Scalars.Money do
  use GreenFairy.Scalar

  scalar "Money" do
    description "Monetary value in cents"

    parse fn
      %Absinthe.Blueprint.Input.Integer{value: value} -> {:ok, value}
      %Absinthe.Blueprint.Input.String{value: value} ->
        case Integer.parse(value) do
          {int, ""} -> {:ok, int}
          _ -> :error
        end
      _ -> :error
    end

    serialize fn cents -> cents end

    # Define available CQL operators
    operators [:_eq, :_neq, :_gt, :_gte, :_lt, :_lte, :_in, :_nin, :_is_null]
  end
end
```

This generates a `CqlOpMoneyInput` type automatically.

## Advanced: Database-Specific Scalars

For scalars that need different behavior per database, implement the `GreenFairy.CQL.Scalar` behaviour:

```elixir
defmodule MyApp.CQL.Scalars.Point do
  @moduledoc """
  Geographic point scalar with database-specific spatial operators.
  """

  @behaviour GreenFairy.CQL.Scalar

  @impl true
  def operator_input(:postgres) do
    {[:_eq, :_neq, :_is_null, :_st_dwithin, :_st_within_bounding_box],
     :point, "Point operators with PostGIS support"}
  end

  def operator_input(:mysql) do
    {[:_eq, :_neq, :_is_null, :_st_distance_sphere],
     :point, "Point operators with MySQL spatial functions"}
  end

  def operator_input(_adapter) do
    {[:_eq, :_neq, :_is_null],
     :point, "Basic point operators"}
  end

  @impl true
  def apply_operator(query, field, operator, value, :postgres, opts) do
    __MODULE__.Postgres.apply_operator(query, field, operator, value, opts)
  end

  def apply_operator(query, field, operator, value, :mysql, opts) do
    __MODULE__.MySQL.apply_operator(query, field, operator, value, opts)
  end

  def apply_operator(query, field, operator, value, _adapter, opts) do
    __MODULE__.Generic.apply_operator(query, field, operator, value, opts)
  end

  @impl true
  def operator_type_identifier(_adapter), do: :cql_op_point_input
end
```

### PostgreSQL Adapter

```elixir
defmodule MyApp.CQL.Scalars.Point.Postgres do
  import Ecto.Query

  def operator_input do
    {[:_eq, :_neq, :_is_null, :_st_dwithin, :_st_within_bounding_box],
     :point, "Point operators with PostGIS support"}
  end

  def apply_operator(query, field, :_eq, value, opts) do
    binding = Keyword.get(opts, :binding)
    if binding do
      where(query, [{^binding, x}], field(x, ^field) == ^value)
    else
      where(query, [q], field(q, ^field) == ^value)
    end
  end

  def apply_operator(query, field, :_st_dwithin, %{point: point, distance: distance}, opts) do
    binding = Keyword.get(opts, :binding)
    if binding do
      where(query, [{^binding, x}],
        fragment("ST_DWithin(?::geography, ?::geography, ?)",
          field(x, ^field), ^point, ^distance))
    else
      where(query, [q],
        fragment("ST_DWithin(?::geography, ?::geography, ?)",
          field(q, ^field), ^point, ^distance))
    end
  end

  def apply_operator(query, field, :_st_within_bounding_box, %{sw: sw, ne: ne}, opts) do
    binding = Keyword.get(opts, :binding)
    if binding do
      where(query, [{^binding, x}],
        fragment("? && ST_MakeEnvelope(?, ?, ?, ?, 4326)",
          field(x, ^field), ^sw.lng, ^sw.lat, ^ne.lng, ^ne.lat))
    else
      where(query, [q],
        fragment("? && ST_MakeEnvelope(?, ?, ?, ?, 4326)",
          field(q, ^field), ^sw.lng, ^sw.lat, ^ne.lng, ^ne.lat))
    end
  end

  # ... other operators
end
```

### MySQL Adapter

```elixir
defmodule MyApp.CQL.Scalars.Point.MySQL do
  import Ecto.Query

  def operator_input do
    {[:_eq, :_neq, :_is_null, :_st_distance_sphere],
     :point, "Point operators with MySQL spatial"}
  end

  def apply_operator(query, field, :_st_distance_sphere, %{point: point, distance: distance}, opts) do
    binding = Keyword.get(opts, :binding)
    if binding do
      where(query, [{^binding, x}],
        fragment("ST_Distance_Sphere(?, POINT(?, ?)) <= ?",
          field(x, ^field), ^point.lng, ^point.lat, ^distance))
    else
      where(query, [q],
        fragment("ST_Distance_Sphere(?, POINT(?, ?)) <= ?",
          field(q, ^field), ^point.lng, ^point.lat, ^distance))
    end
  end

  # ... other operators
end
```

### Generic Fallback

```elixir
defmodule MyApp.CQL.Scalars.Point.Generic do
  import Ecto.Query

  def operator_input do
    {[:_eq, :_neq, :_is_null], :point, "Basic point operators"}
  end

  def apply_operator(query, field, :_eq, value, opts) do
    binding = Keyword.get(opts, :binding)
    if binding do
      where(query, [{^binding, x}], field(x, ^field) == ^value)
    else
      where(query, [q], field(q, ^field) == ^value)
    end
  end

  def apply_operator(query, field, :_neq, value, opts) do
    binding = Keyword.get(opts, :binding)
    if binding do
      where(query, [{^binding, x}], field(x, ^field) != ^value)
    else
      where(query, [q], field(q, ^field) != ^value)
    end
  end

  def apply_operator(query, field, :_is_null, true, opts) do
    binding = Keyword.get(opts, :binding)
    if binding do
      where(query, [{^binding, x}], is_nil(field(x, ^field)))
    else
      where(query, [q], is_nil(field(q, ^field)))
    end
  end

  def apply_operator(query, field, :_is_null, false, opts) do
    binding = Keyword.get(opts, :binding)
    if binding do
      where(query, [{^binding, x}], not is_nil(field(x, ^field)))
    else
      where(query, [q], not is_nil(field(q, ^field)))
    end
  end
end
```

## Registering Custom Scalars

Custom scalars are auto-discovered when imported into your schema. For CQL scalars with adapters, register them in your config:

```elixir
# config/config.exs
config :green_fairy, :cql_scalars,
  point: MyApp.CQL.Scalars.Point,
  money: MyApp.CQL.Scalars.Money
```

## Built-in CQL Scalars

GreenFairy includes CQL scalars for common types:

| Type | Module | Operators |
|------|--------|-----------|
| String | `GreenFairy.CQL.Scalars.String` | `_eq`, `_neq`, `_in`, `_like`, `_ilike`, `_contains`, etc. |
| Integer | `GreenFairy.CQL.Scalars.Integer` | `_eq`, `_neq`, `_gt`, `_gte`, `_lt`, `_lte`, `_in`, etc. |
| Float | `GreenFairy.CQL.Scalars.Float` | `_eq`, `_neq`, `_gt`, `_gte`, `_lt`, `_lte`, `_in`, etc. |
| Boolean | `GreenFairy.CQL.Scalars.Boolean` | `_eq`, `_neq`, `_is_null` |
| ID | `GreenFairy.CQL.Scalars.ID` | `_eq`, `_neq`, `_in`, `_nin`, `_is_null` |
| DateTime | `GreenFairy.CQL.Scalars.DateTime` | `_eq`, `_gt`, `_lt`, `_between`, `_period`, `_current_period` |
| Date | `GreenFairy.CQL.Scalars.Date` | `_eq`, `_gt`, `_lt`, `_between` |
| Time | `GreenFairy.CQL.Scalars.Time` | `_eq`, `_gt`, `_lt` |
| Decimal | `GreenFairy.CQL.Scalars.Decimal` | `_eq`, `_neq`, `_gt`, `_gte`, `_lt`, `_lte` |
| Coordinates | `GreenFairy.CQL.Scalars.Coordinates` | `_eq`, `_st_dwithin`, `_st_within_bounding_box` |

### Array Scalars

| Type | Module | Operators |
|------|--------|-----------|
| `[String]` | `GreenFairy.CQL.Scalars.ArrayString` | `_includes`, `_excludes`, `_includes_all`, `_includes_any`, `_is_empty` |
| `[Integer]` | `GreenFairy.CQL.Scalars.ArrayInteger` | `_includes`, `_excludes`, `_includes_all`, `_includes_any`, `_is_empty` |
| `[ID]` | `GreenFairy.CQL.Scalars.ArrayId` | `_includes`, `_excludes`, `_includes_any`, `_is_empty` |

## The CQL.Scalar Behaviour

```elixir
@callback operator_input(adapter :: atom()) ::
  {operators :: [atom()], type :: atom(), description :: String.t()}

@callback apply_operator(
  query :: Ecto.Query.t(),
  field :: atom(),
  operator :: atom(),
  value :: any(),
  adapter :: atom(),
  opts :: keyword()
) :: Ecto.Query.t()

@callback operator_type_identifier(adapter :: atom()) :: atom()
```

### Callbacks Explained

**`operator_input/1`**
Returns the operators available for this adapter, the underlying type, and a description.

**`apply_operator/6`**
Applies an operator to an Ecto query. Must handle all operators declared in `operator_input/1`.

**`operator_type_identifier/1`**
Returns the GraphQL input type identifier (e.g., `:cql_op_point_input`).

## Example: JSON Scalar

```elixir
defmodule MyApp.CQL.Scalars.JSON do
  @behaviour GreenFairy.CQL.Scalar

  @impl true
  def operator_input(:postgres) do
    {[:_eq, :_neq, :_is_null, :_contains, :_contained_by, :_has_key, :_has_keys_all, :_has_keys_any],
     :json, "JSON operators with PostgreSQL JSONB support"}
  end

  def operator_input(_adapter) do
    {[:_eq, :_neq, :_is_null],
     :json, "Basic JSON operators"}
  end

  @impl true
  def apply_operator(query, field, :_contains, value, :postgres, opts) do
    binding = Keyword.get(opts, :binding)
    json = Jason.encode!(value)
    if binding do
      where(query, [{^binding, x}],
        fragment("? @> ?::jsonb", field(x, ^field), ^json))
    else
      where(query, [q],
        fragment("? @> ?::jsonb", field(q, ^field), ^json))
    end
  end

  def apply_operator(query, field, :_has_key, key, :postgres, opts) do
    binding = Keyword.get(opts, :binding)
    if binding do
      where(query, [{^binding, x}],
        fragment("? \\? ?", field(x, ^field), ^key))
    else
      where(query, [q],
        fragment("? \\? ?", field(q, ^field), ^key))
    end
  end

  # ... other operators

  @impl true
  def operator_type_identifier(_adapter), do: :cql_op_json_input
end
```

## Testing Custom Scalars

```elixir
defmodule MyApp.CQL.Scalars.PointTest do
  use ExUnit.Case, async: true
  import Ecto.Query

  alias MyApp.CQL.Scalars.Point

  describe "operator_input/1" do
    test "postgres returns spatial operators" do
      {ops, _type, _desc} = Point.operator_input(:postgres)
      assert :_st_dwithin in ops
      assert :_st_within_bounding_box in ops
    end

    test "mysql returns distance sphere operator" do
      {ops, _type, _desc} = Point.operator_input(:mysql)
      assert :_st_distance_sphere in ops
      refute :_st_dwithin in ops
    end

    test "generic returns basic operators only" do
      {ops, _type, _desc} = Point.operator_input(:sqlite)
      assert :_eq in ops
      refute :_st_dwithin in ops
    end
  end

  describe "apply_operator/6" do
    test "applies _st_dwithin for postgres" do
      query = from(l in "locations")

      result = Point.apply_operator(
        query, :coordinates, :_st_dwithin,
        %{point: %{lat: 37.7749, lng: -122.4194}, distance: 1000},
        :postgres, []
      )

      assert %Ecto.Query{} = result
      assert result.wheres != []
    end
  end
end
```

## Next Steps

- [CQL Guide](cql.html) - Full CQL documentation
- [CQL Adapter System](cql-adapters.html) - Multi-database support
- [CQL Advanced Features](cql-advanced.html) - Full-text search, geo queries
