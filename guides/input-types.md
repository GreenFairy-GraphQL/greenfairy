# Input Types

Input types define the structure of complex arguments, typically used in mutations.
Unlike object types, input types can only contain scalar fields and other input types.

## Basic Usage

```elixir
defmodule MyApp.GraphQL.Inputs.CreateUserInput do
  use GreenFairy.Input

  input "CreateUserInput" do
    field :email, non_null(:string)
    field :name, :string
    field :password, non_null(:string)
  end
end
```

This generates:

```graphql
input CreateUserInput {
  email: String!
  name: String
  password: String!
}
```

## Using Input Types

Reference inputs in mutations or queries:

```elixir
defmodule MyApp.GraphQL.Mutations.UserMutations do
  use GreenFairy.Mutation

  mutations do
    field :create_user, :user do
      arg :input, non_null(:create_user_input)

      resolve fn _, %{input: input}, ctx ->
        MyApp.Accounts.create_user(input, ctx)
      end
    end
  end
end
```

GraphQL query:

```graphql
mutation {
  createUser(input: {
    email: "user@example.com"
    name: "John Doe"
    password: "secret123"
  }) {
    id
    email
  }
}
```

## Field Options

### Default Values

```elixir
input "CreatePostInput" do
  field :title, non_null(:string)
  field :body, :string
  field :status, :post_status, default_value: :draft
  field :published, :boolean, default_value: false
  field :tags, list_of(:string), default_value: []
end
```

### Descriptions

```elixir
input "CreateUserInput" do
  @desc "User's email address (must be unique)"
  field :email, non_null(:string)

  @desc "Display name shown to other users"
  field :name, :string

  field :role, :user_role, description: "Initial role assignment"
end
```

## Nested Input Types

Input types can reference other input types:

```elixir
defmodule MyApp.GraphQL.Inputs.AddressInput do
  use GreenFairy.Input

  input "AddressInput" do
    field :street, non_null(:string)
    field :city, non_null(:string)
    field :state, :string
    field :postal_code, non_null(:string)
    field :country, non_null(:string), default_value: "US"
  end
end

defmodule MyApp.GraphQL.Inputs.CreateOrganizationInput do
  use GreenFairy.Input

  input "CreateOrganizationInput" do
    field :name, non_null(:string)
    field :billing_address, non_null(:address_input)
    field :shipping_address, :address_input
  end
end
```

## Input Authorization

Control which fields different users can submit:

```elixir
defmodule MyApp.GraphQL.Inputs.UpdateUserInput do
  use GreenFairy.Input

  input "UpdateUserInput" do
    authorize fn _input, ctx ->
      current_user = ctx[:current_user]

      cond do
        current_user && current_user.admin -> :all
        current_user -> [:name, :email, :avatar_url]
        true -> :none
      end
    end

    field :name, :string
    field :email, :string
    field :avatar_url, :string
    field :role, :user_role         # Admin only
    field :verified, :boolean       # Admin only
    field :permissions, list_of(:string)  # Admin only
  end
end
```

### Validating in Resolvers

Use `__filter_input__/2` to validate and filter unauthorized fields:

```elixir
field :update_user, :user do
  arg :id, non_null(:id)
  arg :input, non_null(:update_user_input)

  resolve fn _, %{id: id, input: raw_input}, ctx ->
    case UpdateUserInput.__filter_input__(raw_input, ctx) do
      {:ok, filtered_input} ->
        # filtered_input only contains authorized fields
        MyApp.Accounts.update_user(id, filtered_input)

      {:error, {:unauthorized_fields, fields}} ->
        {:error, "Cannot update fields: #{Enum.join(fields, ", ")}"}
    end
  end
end
```

### Strict vs Lenient Mode

By default, unauthorized fields are silently removed. For strict validation:

```elixir
input "UpdateUserInput" do
  authorize fn _input, ctx, opts ->
    # opts[:strict] can be passed from resolver
    if ctx[:current_user]?.admin do
      :all
    else
      [:name, :email]
    end
  end

  # ...
end

# In resolver - strict mode raises on unauthorized fields
case UpdateUserInput.__filter_input__(input, ctx, strict: true) do
  {:ok, filtered} -> # proceed
  {:error, {:unauthorized_fields, fields}} -> # handle error
end
```

## Common Patterns

### Create vs Update Inputs

Separate inputs for create (required fields) and update (optional fields):

```elixir
defmodule MyApp.GraphQL.Inputs.CreateUserInput do
  use GreenFairy.Input

  input "CreateUserInput" do
    field :email, non_null(:string)
    field :password, non_null(:string)
    field :name, :string
  end
end

defmodule MyApp.GraphQL.Inputs.UpdateUserInput do
  use GreenFairy.Input

  input "UpdateUserInput" do
    # All fields optional for partial updates
    field :email, :string
    field :name, :string
    field :avatar_url, :string
  end
end
```

### Relay Mutation Inputs

For Relay-compliant mutations, include `clientMutationId`:

```elixir
defmodule MyApp.GraphQL.Inputs.CreatePostInput do
  use GreenFairy.Input

  input "CreatePostInput" do
    field :client_mutation_id, :string
    field :title, non_null(:string)
    field :body, :string
    field :author_id, non_null(:id)
  end
end
```

Or use the `relay_mutation` macro which handles this automatically.
See the [Relay Guide](relay.html).

### Filter Inputs

For query filtering (separate from CQL auto-generated filters):

```elixir
defmodule MyApp.GraphQL.Inputs.UserFilterInput do
  use GreenFairy.Input

  input "UserFilterInput" do
    field :search, :string
    field :role, :user_role
    field :status, :user_status
    field :created_after, :datetime
    field :created_before, :datetime
    field :has_verified_email, :boolean
  end
end
```

### Batch Operation Inputs

```elixir
defmodule MyApp.GraphQL.Inputs.BulkUpdateInput do
  use GreenFairy.Input

  input "BulkUserUpdateInput" do
    field :ids, non_null(list_of(non_null(:id)))
    field :status, :user_status
    field :role, :user_role
  end
end
```

## Validation

Input validation is typically done in your resolver or context module:

```elixir
field :create_user, :user do
  arg :input, non_null(:create_user_input)

  resolve fn _, %{input: input}, _ctx ->
    # Use Ecto changesets for validation
    case MyApp.Accounts.create_user(input) do
      {:ok, user} ->
        {:ok, user}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, format_changeset_errors(changeset)}
    end
  end
end

defp format_changeset_errors(changeset) do
  Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end)
end
```

## Complete Example

```elixir
defmodule MyApp.GraphQL.Inputs.CreateOrderInput do
  use GreenFairy.Input

  input "CreateOrderInput" do
    @desc "Input for creating a new order"

    authorize fn _input, ctx ->
      if ctx[:current_user] do
        :all
      else
        :none
      end
    end

    @desc "Customer placing the order"
    field :customer_id, non_null(:id)

    @desc "Items to include in the order"
    field :items, non_null(list_of(non_null(:order_item_input)))

    @desc "Shipping address"
    field :shipping_address, non_null(:address_input)

    @desc "Billing address (defaults to shipping if not provided)"
    field :billing_address, :address_input

    @desc "Discount code to apply"
    field :discount_code, :string

    @desc "Special instructions for delivery"
    field :notes, :string

    @desc "Requested delivery date"
    field :requested_delivery_date, :date
  end
end

defmodule MyApp.GraphQL.Inputs.OrderItemInput do
  use GreenFairy.Input

  input "OrderItemInput" do
    field :product_id, non_null(:id)
    field :quantity, non_null(:integer), default_value: 1
    field :customizations, :json
  end
end
```

## Module Functions

Every input module exports:

| Function | Description |
|----------|-------------|
| `__green_fairy_kind__/0` | Returns `:input` |
| `__green_fairy_identifier__/0` | Returns the type identifier |
| `__green_fairy_definition__/0` | Returns the full definition map |
| `__filter_input__/2` | Filters input based on authorization |
| `__filter_input__/3` | Filters with options (e.g., `strict: true`) |

## Naming Conventions

| GraphQL Name | Elixir Identifier | Module Suggestion |
|--------------|-------------------|-------------------|
| `CreateUserInput` | `:create_user_input` | `MyApp.GraphQL.Inputs.CreateUserInput` |
| `UpdatePostInput` | `:update_post_input` | `MyApp.GraphQL.Inputs.UpdatePostInput` |
| `AddressInput` | `:address_input` | `MyApp.GraphQL.Inputs.AddressInput` |

## Input vs Object Types

| Feature | Input Types | Object Types |
|---------|-------------|--------------|
| Used for | Arguments | Query results |
| Can have resolvers | No | Yes |
| Can reference objects | No | Yes |
| Can reference inputs | Yes | No (use args) |
| Can have connections | No | Yes |
| Can implement interfaces | No | Yes |

## Next Steps

- [Object Types](object-types.html) - Query result types
- [Mutations](operations.html) - Using inputs in mutations
- [Authorization](authorization.html) - Input field authorization
- [Relay](relay.html) - Relay mutation conventions
