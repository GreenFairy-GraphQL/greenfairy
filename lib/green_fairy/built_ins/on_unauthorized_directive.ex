defmodule GreenFairy.BuiltIns.OnUnauthorizedDirective do
  @moduledoc """
  The @onUnauthorized directive allows clients to control how unauthorized field access is handled.

  ## Usage

  ```graphql
  query GetUser {
    user(id: "123") {
      id
      name
      email @onUnauthorized(behavior: NIL)  # Return nil if unauthorized
      ssn @onUnauthorized(behavior: ERROR)  # Return error if unauthorized
    }
  }
  ```

  ## Behavior

  - `ERROR` (default) - Return an GraphQL error when the field is unauthorized
  - `NIL` - Return `null` when the field is unauthorized, allowing the query to continue

  ## Backend Control

  The backend can set a default behavior at the type or field level:

  ```elixir
  type "User", struct: MyApp.User, on_unauthorized: :return_nil do
    authorize fn user, ctx ->
      if ctx[:current_user]?.admin, do: :all, else: [:id, :name]
    end

    field :id, :id
    field :name, :string
    field :email, :string  # Will return nil if unauthorized (type default)
    field :ssn, :string, on_unauthorized: :error  # Override: will error
  end
  ```

  ## Priority

  Client directive overrides backend configuration:
  1. Client `@onUnauthorized(behavior: ...)` directive (highest priority)
  2. Field-level `on_unauthorized:` option
  3. Type-level `on_unauthorized:` option
  4. Global default (`:error`)

  This allows the backend to control defaults while giving clients flexibility to
  handle unauthorized fields based on their UI needs.
  """

  use Absinthe.Schema.Notation

  directive :on_unauthorized do
    @desc """
    Controls how unauthorized field access is handled.

    - ERROR: Return a GraphQL error (default)
    - NIL: Return null to allow the query to continue
    """

    arg :behavior, non_null(:unauthorized_behavior), description: "How to handle unauthorized access"

    on [:field]

    expand fn
      %{behavior: behavior}, node ->
        # Store the client's requested behavior in the node's meta
        put_in(node.meta[:on_unauthorized], behavior)
    end
  end

  @doc false
  def __absinthe_directive__(:on_unauthorized) do
    %Absinthe.Type.Directive{
      name: "onUnauthorized",
      identifier: :on_unauthorized,
      description: "Controls how unauthorized field access is handled.",
      locations: [:field],
      args: %{
        behavior: %Absinthe.Type.Argument{
          name: "behavior",
          identifier: :behavior,
          type: %Absinthe.Type.NonNull{of_type: :unauthorized_behavior},
          description: "How to handle unauthorized access"
        }
      },
      expand: fn
        %{behavior: behavior}, node ->
          put_in(node.meta[:on_unauthorized], behavior)
      end
    }
  end
end
