# Authorization

GreenFairy provides a simple, type-owned authorization system. Each type controls which fields are visible based on the object data and the request context.

## Design Philosophy

Unlike complex permission systems that require separate policy classes or middleware chains, GreenFairy keeps authorization where it belongs - with the type that owns the data. This approach:

- **Keeps related logic together** - The type knows its fields, so it should know who can see them
- **Stays flexible** - Your context is your domain, put whatever you need in it
- **Scales naturally** - Simple cases stay simple, complex cases have the tools they need

## Basic Authorization

Define an `authorize` callback inside your type to control field visibility:

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  type "User", struct: MyApp.User do
    authorize fn user, ctx ->
      cond do
        # Admins see everything
        ctx[:current_user]?.admin -> :all

        # Users see their own data
        ctx[:current_user]?.id == user.id -> [:id, :name, :email, :phone]

        # Everyone else sees public fields
        true -> [:id, :name]
      end
    end

    field :id, non_null(:id)
    field :name, :string
    field :email, :string
    field :phone, :string
    field :ssn, :string
    field :password_hash, :string
  end
end
```

## Return Values

The authorize callback must return one of:

| Return Value | Meaning |
|--------------|---------|
| `:all` | All fields are visible |
| `:none` | Object is completely hidden (returns `nil`) |
| `[:field1, :field2]` | Only the listed fields are visible |

## Authorization with Path Info

Sometimes you need to know *how* an object was accessed. The 3-arity version of the authorize callback receives an `AuthorizationInfo` struct:

```elixir
type "Post", struct: MyApp.Post do
  authorize fn post, ctx, info ->
    # info contains:
    # - path: [:query, :user, :posts] - the path through the graph
    # - field: :posts - the current field name
    # - parent: %User{...} - the immediate parent object
    # - parents: [%User{...}] - all parent objects

    # Example: Allow full access when accessing through author's profile
    parent_is_author = case info.parent do
      %{id: id} -> id == post.author_id
      _ -> false
    end

    cond do
      ctx[:current_user]?.admin -> :all
      parent_is_author -> :all
      ctx[:current_user]?.id == post.author_id -> [:id, :title, :content]
      true -> [:id, :title]
    end
  end

  field :id, non_null(:id)
  field :title, :string
  field :content, :string
  field :secret_notes, :string
end
```

### AuthorizationInfo Fields

| Field | Type | Description |
|-------|------|-------------|
| `path` | `[atom]` | The path through the graph to this object |
| `field` | `atom` | The field name that resolved to this object |
| `parent` | `any` | The immediate parent object (or `nil` for root) |
| `parents` | `[any]` | All parent objects in order |

## Input Authorization

Control which fields users can submit in input types:

```elixir
defmodule MyApp.GraphQL.Inputs.UpdateUserInput do
  use GreenFairy.Input

  input "UpdateUserInput" do
    authorize fn _input, ctx ->
      if ctx[:current_user]?.admin do
        :all
      else
        [:name, :email, :avatar_url]  # Regular users can only update these
      end
    end

    field :name, :string
    field :email, :string
    field :avatar_url, :string
    field :role, :user_role       # Admin only
    field :verified, :boolean     # Admin only
    field :permissions, :json     # Admin only
  end
end
```

### Using Input Authorization in Resolvers

Use `__filter_input__/2` to validate input in your resolver:

```elixir
def update_user(_, %{id: id, input: input}, %{context: ctx}) do
  case UpdateUserInput.__filter_input__(input, ctx) do
    {:ok, validated_input} ->
      # Input is safe to use
      MyApp.Users.update_user(id, validated_input)

    {:error, {:unauthorized_fields, fields}} ->
      {:error, "Cannot update restricted fields: #{inspect(fields)}"}
  end
end
```

## Policy Module Support

You can also use policy modules for authorization:

```elixir
defmodule MyApp.Policies.UserPolicy do
  def can?(nil, _action, _resource), do: false
  def can?(%{admin: true}, :view, _resource), do: true
  def can?(%{id: user_id}, :view, %{id: user_id}), do: true
  def can?(_, _, _), do: false
end

type "User", struct: MyApp.User do
  authorize with: MyApp.Policies.UserPolicy

  # ...fields
end
```

The policy's `can?/3` function receives `(current_user, :view, object)`. Return `true` for `:all` fields or `false` for `:none`.

## Types Without Authorization

Types without an `authorize` callback allow all fields to be visible:

```elixir
type "PublicProfile", struct: MyApp.PublicProfile do
  # No authorize callback = all fields visible to everyone

  field :id, non_null(:id)
  field :username, :string
  field :bio, :string
end
```

## Unauthorized Behavior

By default, accessing an unauthorized field returns a GraphQL error. You can change this behavior at the type, field, or query level.

### Type-Level Default

Set a default behavior for all fields in a type:

```elixir
type "User", struct: MyApp.User, on_unauthorized: :return_nil do
  authorize fn user, ctx ->
    if ctx[:current_user]?.admin, do: :all, else: [:id, :name]
  end

  field :id, non_null(:id)
  field :name, :string
  field :email, :string    # Returns nil if unauthorized
  field :salary, :integer  # Returns nil if unauthorized
end
```

### Field-Level Override

Override the type default for specific fields:

```elixir
type "User", struct: MyApp.User, on_unauthorized: :return_nil do
  authorize fn user, ctx ->
    if ctx[:current_user]?.admin, do: :all, else: [:id, :name]
  end

  field :id, non_null(:id)
  field :name, :string
  field :email, :string                          # Uses type default (nil)
  field :ssn, :string, on_unauthorized: :error   # Override: returns error
end
```

### Client Directive (`@onUnauthorized`)

Clients can control behavior per-field in their queries, overriding backend defaults:

```graphql
query GetUser {
  user(id: "123") {
    id
    name
    email @onUnauthorized(behavior: NIL)    # Return null if unauthorized
    ssn @onUnauthorized(behavior: ERROR)    # Return error if unauthorized
  }
}
```

This is useful when:
- A UI component can gracefully handle missing data
- Different screens need different error handling for the same field
- You want to fetch "best effort" data without failing the whole query

### Priority Chain

When determining how to handle unauthorized access:

1. **Client directive** `@onUnauthorized(behavior: ...)` (highest priority)
2. **Field-level** `on_unauthorized:` option
3. **Type-level** `on_unauthorized:` option
4. **Global default** `:error`

### Behavior Values

| Value | Effect |
|-------|--------|
| `:error` | Return a GraphQL error (default) |
| `:return_nil` | Return `null`, query continues |

## Best Practices

1. **Keep it simple** - Start with basic field lists, add complexity only when needed
2. **Use context wisely** - Put authentication info in context during plug/middleware
3. **Test thoroughly** - Authorization is critical; test all permission scenarios
4. **Document expectations** - Comment which roles can access which fields
5. **Fail closed** - When in doubt, hide fields rather than expose them
6. **Consider UX** - Use `on_unauthorized: :return_nil` for optional data that shouldn't break the UI

## Integration with CQL

Authorization integrates seamlessly with CQL. Users can only filter on fields they're authorized to see:

```elixir
type "User", struct: MyApp.User do
  authorize fn user, ctx ->
    if ctx[:current_user]?.admin, do: :all, else: [:id, :name]
  end

  field :id, non_null(:id)
  field :name, :string
  field :email, :string    # Can't filter on this unless admin
  field :salary, :integer  # Can't filter on this unless admin
end
```

CQL filtering is automatically enabled for all types with a backing struct. See the [CQL Guide](cql.html) for more details.

## Next Steps

- [Relationships](relationships.html) - Define associations between types
- [Connections](connections.html) - Relay-style pagination
- [CQL Guide](cql.html) - Automatic filtering and ordering
