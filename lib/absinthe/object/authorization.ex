defmodule Absinthe.Object.Authorization do
  @moduledoc """
  Authorization support for Absinthe.Object types and fields.

  ## Type-Level Authorization

      defmodule MyApp.GraphQL.Types.User do
        use Absinthe.Object.Type

        type "User", struct: MyApp.User do
          authorize with: MyApp.Policies.User

          field :email, :string, authorize: :owner_only
          field :name, :string  # No authorization required
        end
      end

  ## Policy Behaviour

  Implement the `Absinthe.Object.Authorization.Policy` behaviour:

      defmodule MyApp.Policies.User do
        @behaviour Absinthe.Object.Authorization.Policy

        @impl true
        def can?(current_user, :view, %User{} = user) do
          true  # Everyone can view users
        end

        def can?(current_user, :owner_only, %User{id: id}) do
          current_user && current_user.id == id
        end

        def can?(_current_user, _action, _resource), do: false
      end

  ## Context Requirements

  Authorization expects `context.current_user` to be set in your GraphQL context:

      def context(ctx) do
        current_user = get_current_user(ctx)
        Map.put(ctx, :current_user, current_user)
      end

  ## Options

  * `authorize: :action_name` - Policy action to check (on field)
  * `authorize with: PolicyModule` - Policy module to use (on type)
  * `default_on_unauthorized: value` - Value to return when unauthorized (default: nil)
  """

  @doc """
  Behaviour for authorization policies.
  """
  @callback can?(current_user :: term(), action :: atom(), resource :: term()) :: boolean()

  @doc """
  Creates authorization middleware for a field.
  """
  def middleware(action, policy_module, opts \\ []) do
    default_value = Keyword.get(opts, :default_on_unauthorized, nil)

    {Absinthe.Object.Authorization.Middleware, {action, policy_module, default_value}}
  end

  @doc """
  Checks if authorization is required for a field config.
  """
  def authorized?(config, resource, context) do
    action = config[:authorize]
    policy = config[:authorize_with]

    cond do
      is_nil(action) ->
        true

      is_nil(policy) ->
        true

      true ->
        current_user = Map.get(context, :current_user)
        policy.can?(current_user, action, resource)
    end
  end
end

defmodule Absinthe.Object.Authorization.Middleware do
  @moduledoc """
  Middleware that enforces field-level authorization.
  """

  @behaviour Absinthe.Middleware

  @impl true
  def call(%{state: :unresolved} = resolution, {action, policy_module, default_value}) do
    current_user = resolution.context[:current_user]
    parent = resolution.source

    if policy_module.can?(current_user, action, parent) do
      resolution
    else
      %{resolution | state: :resolved, value: default_value}
    end
  end

  def call(resolution, _config), do: resolution
end
