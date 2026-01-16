# CQL (Filterable Queries)

CQL (Composite Query Language) is an extension that automatically generates filter inputs for your GraphQL types based on their backing Ecto schemas.

## Overview

Instead of manually defining filter input types and writing filter logic, CQL:

- Detects your Ecto schema fields and their types
- Generates appropriate operators for each field type
- Creates `CqlFilter{Type}Input` types with logical combinators (`_and`, `_or`, `_not`)
- Creates `CqlOp{Type}Input` types for each field type's operators
- Integrates with your authorization rules

## Generated Schema Pattern

CQL follows the GigSmart schema pattern where each type gets:

1. **Filter Input Type** - `CqlFilter{Type}Input` with:
   - `_and: [CqlFilter{Type}Input]` - Logical AND combinator
   - `_or: [CqlFilter{Type}Input]` - Logical OR combinator
   - `_not: CqlFilter{Type}Input` - Logical NOT combinator
   - Field-specific operator references (e.g., `name: CqlOpStringInput`)

2. **Operator Input Types** - Shared types like:
   - `CqlOpIdInput` - ID field operators (eq, neq, in, is_nil)
   - `CqlOpStringInput` - String operators (eq, neq, contains, starts_with, ends_with, in, is_nil)
   - `CqlOpIntegerInput` - Integer operators (eq, neq, gt, gte, lt, lte, in, is_nil)
   - `CqlOpBooleanInput` - Boolean operators (eq, is_nil)
   - `CqlOpDatetimeInput` - DateTime operators
   - And more...

Example generated schema for a User type:

```graphql
input CqlFilterUserInput {
  _and: [CqlFilterUserInput]
  _or: [CqlFilterUserInput]
  _not: CqlFilterUserInput
  id: CqlOpIdInput
  name: CqlOpStringInput
  email: CqlOpStringInput
  age: CqlOpIntegerInput
}

input CqlOpStringInput {
  eq: String
  neq: String
  contains: String
  starts_with: String
  ends_with: String
  in: [String]
  is_nil: Boolean
}
```

## Basic Usage

CQL is automatically enabled for all types with a backing struct:

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  type "User", struct: MyApp.User do
    field :id, non_null(:id)
    field :name, :string
    field :email, :string
    field :age, :integer
    field :active, :boolean
    field :inserted_at, :datetime
  end
end
```

This automatically generates a `CqlFilterUserInput` type with appropriate operators for each field.

## Generated Operators

CQL generates operators based on Ecto field types:

| Ecto Type | Generated Operators |
|-----------|---------------------|
| `:string` | `eq`, `neq`, `in`, `contains`, `starts_with`, `ends_with`, `is_nil` |
| `:integer` | `eq`, `neq`, `in`, `gt`, `gte`, `lt`, `lte`, `is_nil` |
| `:boolean` | `eq`, `is_nil` |
| `:id` | `eq`, `neq`, `in` |
| `:naive_datetime`, `:utc_datetime`, `:date` | `eq`, `neq`, `gt`, `gte`, `lt`, `lte`, `is_nil` |
| `Ecto.Enum` | `eq`, `neq`, `in` |

## Custom Filters

Add filters for computed fields or fields not in the Ecto schema:

```elixir
type "User", struct: MyApp.User do
  use CQL

  field :id, non_null(:id)
  field :first_name, :string
  field :last_name, :string
  field :full_name, :string  # Computed field

  # Define custom filter for the computed field
  custom_filter :full_name, [:eq, :contains], fn query, op, value ->
    import Ecto.Query

    case op do
      :eq ->
        from u in query,
          where: fragment("concat(?, ' ', ?)", u.first_name, u.last_name) == ^value

      :contains ->
        from u in query,
          where: ilike(fragment("concat(?, ' ', ?)", u.first_name, u.last_name), ^"%#{value}%")
    end
  end
end
```

### Type Shorthand

Use a type shorthand to get all operators for that type:

```elixir
# Instead of listing operators manually
custom_filter :computed_score, :integer, fn query, op, value ->
  # Gets all integer operators: eq, neq, in, gt, gte, lt, lte, is_nil
  # ... apply filter
end
```

## Authorization Integration

CQL respects your type's authorization rules. Users can only filter on fields they're authorized to see:

```elixir
type "User", struct: MyApp.User do
  use CQL

  authorize fn user, ctx ->
    if ctx[:current_user]?.admin do
      :all
    else
      [:id, :name, :email]  # Non-admins can't see/filter salary
    end
  end

  field :id, non_null(:id)
  field :name, :string
  field :email, :string
  field :salary, :integer  # Only admins can filter on this
end
```

### Validating Filters

Use `__cql_validate_filter__/3` to check if a user can apply certain filters:

```elixir
def list_users(_, %{filter: filter}, %{context: ctx}) do
  case UserType.__cql_validate_filter__(filter, nil, ctx) do
    :ok ->
      # Filter is valid, apply it
      MyApp.Users.list(filter)

    {:error, {:unauthorized_fields, fields}} ->
      {:error, "Cannot filter on: #{inspect(fields)}"}
  end
end
```

### Getting Authorized Fields

Query which fields a user can filter on:

```elixir
# Get all filterable fields for this user
fields = UserType.__cql_authorized_fields__(object, ctx)
# => [:id, :name, :email]

# Get operators for a specific field
ops = UserType.__cql_authorized_operators_for__(:name, object, ctx)
# => [:eq, :neq, :in, :contains, :starts_with, :ends_with, :is_nil]
```

## Custom Scalar Operators

Define CQL operators on custom scalar types. This example uses the
[`geo`](https://hex.pm/packages/geo) library for geographic data with PostGIS:

```elixir
defmodule MyApp.GraphQL.Scalars.Point do
  use GreenFairy.Scalar

  @moduledoc "GraphQL scalar for Geo.Point from the geo library"

  scalar "Point" do
    description "A geographic point (longitude, latitude)"

    parse fn
      %Absinthe.Blueprint.Input.Object{fields: fields}, _ ->
        lng = get_field(fields, "lng")
        lat = get_field(fields, "lat")
        {:ok, %Geo.Point{coordinates: {lng, lat}, srid: 4326}}
      _, _ ->
        :error
    end

    serialize fn %Geo.Point{coordinates: {lng, lat}} ->
      %{lng: lng, lat: lat}
    end

    # Define operators available for filtering
    operators [:eq, :near, :within_distance]

    # PostGIS-compatible filter using ST_DWithin
    filter :near, fn field, %Geo.Point{} = point, opts ->
      distance_meters = opts[:distance] || 1000
      {:fragment, "ST_DWithin(?::geography, ?::geography, ?)", field, point, distance_meters}
    end

    filter :within_distance, fn field, %{point: point, distance: distance} ->
      {:fragment, "ST_DWithin(?::geography, ?::geography, ?)", field, point, distance}
    end
  end

  defp get_field(fields, name) do
    Enum.find_value(fields, fn %{name: n, input_value: %{value: v}} ->
      if n == name, do: v
    end)
  end
end
```

Then use the scalar in your type:

```elixir
type "Location", struct: MyApp.Location do
  use CQL

  field :id, non_null(:id)
  field :name, :string
  field :coordinates, :point  # Uses Geo.Point with custom operators
end
```

## API Reference

### Type Functions

| Function | Description |
|----------|-------------|
| `__cql_config__/0` | Returns the CQL configuration for this type |
| `__cql_filterable_fields__/0` | Returns all fields that can be filtered |
| `__cql_operators_for__/1` | Returns operators for a specific field |
| `__cql_authorized_fields__/2` | Returns filterable fields for a user |
| `__cql_authorized_operators_for__/3` | Returns operators a user can use on a field |
| `__cql_validate_filter__/3` | Validates a filter against authorization |
| `__cql_apply_custom_filter__/4` | Applies a custom filter function |

### Configuration

The `__cql_config__/0` function returns:

```elixir
%{
  adapter: GreenFairy.Adapters.Ecto,  # Detected adapter
  adapter_fields: [:id, :name, :email],     # Fields from adapter
  adapter_field_types: %{                   # Types for each field
    id: :id,
    name: :string,
    email: :string
  },
  custom_filters: %{                        # Custom filter definitions
    full_name: {[:eq, :contains], fn query, op, value -> ... end}
  }
}
```

## Adapters

CQL uses adapters to detect field information. The built-in Ecto adapter:

- Detects Ecto schemas via `__schema__/1`
- Extracts field types from the schema
- Maps Ecto types to CQL operators

Custom adapters can be created by implementing the `GreenFairy.Adapter` behaviour:

```elixir
defmodule MyApp.CustomAdapter do
  use GreenFairy.Adapter

  @impl true
  def handles?(module), do: # check if this adapter handles the module

  @impl true
  def queryable_fields(module), do: # return list of field atoms

  @impl true
  def field_type(module, field), do: # return the field type

  @impl true
  def operators_for_type(type), do: # return operators for this type
end
```

Then specify it in your schema configuration:

```elixir
# config/config.exs
config :green_fairy, :cql_adapter, MyApp.CustomAdapter
```

## Schema Integration

CQL types are automatically generated when using `GreenFairy.Schema`:

```elixir
defmodule MyApp.Schema do
  use GreenFairy.Schema,
    query: MyApp.GraphQL.Queries,
    mutation: MyApp.GraphQL.Mutations,
    repo: MyApp.Repo
end
```

Filter and order inputs are automatically generated for all types with a backing struct. Use them in your queries:

```elixir
defmodule MyApp.GraphQL.Queries do
  use GreenFairy.Query

  queries do
    field :users, list_of(:user) do
      arg :where, :cql_filter_user_input
      arg :order_by, list_of(:cql_order_user_input)
      resolve &MyApp.Resolvers.list_users/3
    end
  end
end
```

The schema automatically generates:
- Filter input types (`CqlFilterUserInput`, `CqlFilterPostInput`, etc.)
- Operator input types (`CqlOpStringInput`, `CqlOpIntegerInput`, etc.)
- Order input types (`CqlOrderUserInput`, etc.)

## Programmatic Access

Each CQL-enabled type exposes functions for programmatic access:

| Function | Description |
|----------|-------------|
| `__cql_filter_input_identifier__/0` | Returns the filter input type identifier |
| `__cql_filter_fields__/0` | Returns fields with their types for filter generation |
| `__cql_generate_filter_input__/0` | Generates the filter input AST |

## Best Practices

1. **Use authorization** - Always define authorization when exposing sensitive fields
2. **Validate in resolvers** - Call `__cql_validate_filter__/3` before applying filters
3. **Custom filters for computed fields** - Use `custom_filter` for anything not in the schema
4. **Type shorthands** - Use type names (`:string`, `:integer`) for consistent operators
5. **Document operators** - Help API consumers know what filters are available
