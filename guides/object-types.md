# Object Types

Object types are the fundamental building blocks of a GraphQL schema. They represent
entities in your domain with fields that can be queried.

## Basic Usage

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  type "User", struct: MyApp.User do
    @desc "A user in the system"

    field :id, non_null(:id)
    field :email, non_null(:string)
    field :name, :string
    field :bio, :string
  end
end
```

This generates:

```graphql
"""
A user in the system
"""
type User {
  id: ID!
  email: String!
  name: String
  bio: String
}
```

## Options

The `type` macro accepts these options:

| Option | Description |
|--------|-------------|
| `:struct` | Backing Elixir struct (enables CQL and auto resolve_type) |
| `:description` | Type description (can also use `@desc`) |
| `:on_unauthorized` | Default behavior for unauthorized fields (`:error` or `:return_nil`) |

```elixir
type "User", struct: MyApp.User, on_unauthorized: :return_nil do
  # fields...
end
```

## Fields

### Simple Fields

Fields map directly to struct/map keys:

```elixir
type "User", struct: MyApp.User do
  field :id, non_null(:id)
  field :email, non_null(:string)
  field :name, :string
  field :age, :integer
  field :is_active, :boolean
  field :joined_at, :datetime
end
```

### Field Descriptions

```elixir
type "User", struct: MyApp.User do
  @desc "Unique identifier"
  field :id, non_null(:id)

  @desc "Primary email address"
  field :email, non_null(:string)

  field :name, :string, description: "Display name"
end
```

### Computed Fields

Use `resolve` for fields not directly on the struct:

```elixir
type "User", struct: MyApp.User do
  field :id, non_null(:id)
  field :first_name, :string
  field :last_name, :string

  field :full_name, :string do
    resolve fn user, _, _ ->
      {:ok, "#{user.first_name} #{user.last_name}"}
    end
  end

  field :initials, :string do
    resolve fn user, _, _ ->
      initials = "#{String.first(user.first_name)}#{String.first(user.last_name)}"
      {:ok, String.upcase(initials)}
    end
  end
end
```

### Fields with Arguments

```elixir
type "User", struct: MyApp.User do
  field :avatar_url, :string do
    arg :size, :integer, default_value: 100

    resolve fn user, %{size: size}, _ ->
      {:ok, "#{user.avatar_base_url}?s=#{size}"}
    end
  end

  field :posts, list_of(:post) do
    arg :limit, :integer, default_value: 10
    arg :status, :post_status

    resolve fn user, args, _ ->
      {:ok, MyApp.Posts.list_for_user(user.id, args)}
    end
  end
end
```

## Batch Loading

Use `loader` for efficient batch loading (prevents N+1 queries):

```elixir
type "User", struct: MyApp.User do
  field :organization, :organization do
    loader fn users, _args, _ctx ->
      org_ids = Enum.map(users, & &1.organization_id) |> Enum.uniq()
      orgs = MyApp.Organizations.get_many(org_ids)
      orgs_by_id = Map.new(orgs, &{&1.id, &1})

      Map.new(users, fn user ->
        {user, Map.get(orgs_by_id, user.organization_id)}
      end)
    end
  end

  field :recent_activity, list_of(:activity) do
    arg :limit, :integer, default_value: 5

    loader fn users, args, _ctx ->
      user_ids = Enum.map(users, & &1.id)
      activities = MyApp.Activity.recent_for_users(user_ids, args.limit)

      Enum.group_by(activities, & &1.user_id)
      |> then(fn grouped ->
        Map.new(users, fn user ->
          {user, Map.get(grouped, user.id, [])}
        end)
      end)
    end
  end
end
```

The loader function receives:
1. List of parent objects (all users being resolved)
2. Arguments
3. Context

Returns a map of `parent -> resolved_value`.

**Note:** A field cannot have both `resolve` and `loader` - they are mutually exclusive.

## Associations

Use `assoc` for Ecto associations with automatic DataLoader integration:

```elixir
type "User", struct: MyApp.User do
  field :id, non_null(:id)

  # Automatically uses DataLoader
  assoc :organization
  assoc :posts
  assoc :comments

  # With options
  assoc :active_posts, as: :posts, where: [status: :published]
end
```

See the [Relationships Guide](relationships.html) for details.

## Connections (Pagination)

Use `connection` for Relay-style pagination:

```elixir
type "User", struct: MyApp.User do
  field :id, non_null(:id)

  connection :posts, node_type: :post do
    arg :status, :post_status

    resolve fn user, args, _ ->
      MyApp.Posts.paginate_for_user(user.id, args)
    end
  end
end
```

See the [Connections Guide](connections.html) for details.

## Implementing Interfaces

```elixir
type "User", struct: MyApp.User do
  implements MyApp.GraphQL.Interfaces.Node
  implements MyApp.GraphQL.Interfaces.Timestamped

  field :id, non_null(:id)
  field :inserted_at, non_null(:datetime)
  field :updated_at, non_null(:datetime)
  # ... other fields
end
```

## Authorization

Control field visibility based on the current user:

```elixir
type "User", struct: MyApp.User do
  authorize fn user, ctx ->
    current_user = ctx[:current_user]

    cond do
      # Admins see everything
      current_user && current_user.admin -> :all

      # Users see everything about themselves
      current_user && current_user.id == user.id -> :all

      # Others see limited fields
      true -> [:id, :name, :avatar_url]
    end
  end

  field :id, non_null(:id)
  field :name, :string
  field :avatar_url, :string
  field :email, :string          # Hidden from others
  field :phone, :string          # Hidden from others
  field :ssn, :string            # Hidden from others
end
```

### Path-Aware Authorization

Access the query path for context-sensitive authorization:

```elixir
type "Comment", struct: MyApp.Comment do
  authorize fn comment, ctx, info ->
    # info.path = [:query, :post, :comments]
    # info.parent = %Post{...}
    # info.parents = [%Post{...}]

    post = info.parent

    if post.public do
      :all
    else
      [:id, :body]  # Hide author info on private posts
    end
  end

  field :id, non_null(:id)
  field :body, :string
  field :author, :user
end
```

### Field-Level Unauthorized Behavior

```elixir
type "User", struct: MyApp.User, on_unauthorized: :return_nil do
  # Type default: return nil for unauthorized fields

  field :id, non_null(:id)
  field :name, :string
  field :email, :string
  field :ssn, :string, on_unauthorized: :error  # Override: raise error
end
```

See the [Authorization Guide](authorization.html) for details.

## CQL (Automatic Filtering)

Types with a `:struct` option automatically get CQL support:

```elixir
type "User", struct: MyApp.User do
  field :id, non_null(:id)
  field :name, :string
  field :email, :string
  field :status, :user_status
  field :age, :integer
end
```

This generates `CqlFilterUserInput` and `CqlOrderUserInput` types automatically.

### Custom Filters

Add custom filters for computed fields:

```elixir
type "User", struct: MyApp.User do
  field :id, non_null(:id)
  field :first_name, :string
  field :last_name, :string

  # Custom filter for computed field
  custom_filter :full_name, [:_eq, :_ilike], fn query, op, value ->
    import Ecto.Query

    case op do
      :_eq ->
        from(u in query,
          where: fragment("concat(?, ' ', ?)", u.first_name, u.last_name) == ^value
        )

      :_ilike ->
        from(u in query,
          where: ilike(fragment("concat(?, ' ', ?)", u.first_name, u.last_name), ^"%#{value}%")
        )
    end
  end
end
```

See the [CQL Guide](cql.html) for details.

## Complete Example

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  type "User", struct: MyApp.User, on_unauthorized: :return_nil do
    @desc "A user account in the system"

    implements MyApp.GraphQL.Interfaces.Node
    implements MyApp.GraphQL.Interfaces.Timestamped

    authorize fn user, ctx ->
      case ctx[:current_user] do
        %{admin: true} -> :all
        %{id: id} when id == user.id -> :all
        _ -> [:id, :name, :avatar_url, :inserted_at]
      end
    end

    # Basic fields
    field :id, non_null(:id)
    field :name, :string
    field :email, non_null(:string)
    field :avatar_url, :string
    field :status, :user_status
    field :inserted_at, non_null(:datetime)
    field :updated_at, non_null(:datetime)

    # Computed field
    field :display_name, non_null(:string) do
      resolve fn user, _, _ ->
        {:ok, user.name || user.email}
      end
    end

    # Field with arguments
    field :avatar, :string do
      arg :size, :integer, default_value: 100

      resolve fn user, %{size: size}, _ ->
        {:ok, "#{user.avatar_url}?s=#{size}"}
      end
    end

    # Association
    assoc :organization

    # Connection
    connection :posts, node_type: :post do
      arg :status, :post_status

      resolve fn user, args, _ ->
        MyApp.Posts.paginate_for_user(user.id, args)
      end
    end

    # Batch-loaded field
    field :unread_notifications_count, :integer do
      loader fn users, _args, _ctx ->
        user_ids = Enum.map(users, & &1.id)
        counts = MyApp.Notifications.unread_counts(user_ids)

        Map.new(users, fn user ->
          {user, Map.get(counts, user.id, 0)}
        end)
      end
    end
  end
end
```

## Module Functions

Every type module exports:

| Function | Description |
|----------|-------------|
| `__green_fairy_kind__/0` | Returns `:object` |
| `__green_fairy_identifier__/0` | Returns the type identifier (e.g., `:user`) |
| `__green_fairy_struct__/0` | Returns the backing struct module |
| `__green_fairy_definition__/0` | Returns the full definition map |
| `__authorize__/3` | Authorization callback |
| `__cql_filter_input_identifier__/0` | CQL filter input type |
| `__cql_order_input_identifier__/0` | CQL order input type |

## Naming Conventions

| GraphQL Name | Elixir Identifier | Module Suggestion |
|--------------|-------------------|-------------------|
| `User` | `:user` | `MyApp.GraphQL.Types.User` |
| `BlogPost` | `:blog_post` | `MyApp.GraphQL.Types.BlogPost` |
| `APIKey` | `:api_key` | `MyApp.GraphQL.Types.APIKey` |

## Next Steps

- [Relationships](relationships.html) - Associations and DataLoader
- [Connections](connections.html) - Relay-style pagination
- [Authorization](authorization.html) - Field-level access control
- [CQL](cql.html) - Automatic filtering and sorting
