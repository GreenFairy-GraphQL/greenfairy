defmodule Absinthe.Object.Extensions.Auth do
  @moduledoc """
  Authentication and authorization extension for Absinthe.Object types.

  Provides declarative macros for capability-based field authorization
  and authentication checks.

  ## Quick Start

  Use the `authorize` callback on your type for field-level authorization:

      defmodule MyApp.GraphQL.Types.User do
        use Absinthe.Object.Type

        type "User", struct: MyApp.User do
          authorize fn user, ctx ->
            cond do
              ctx[:current_user]?.admin -> :all
              ctx[:current_user]?.id == user.id -> :all
              true -> [:id, :name]
            end
          end

          field :id, non_null(:id)
          field :name, :string
          field :email, :string
          field :ssn, :string
        end
      end

  ## Simple Capability Checks

  For simple per-field capability checks, use this extension:

      defmodule MyApp.GraphQL.Types.User do
        use Absinthe.Object.Type

        type "User", struct: MyApp.User do
          use Absinthe.Object.Extensions.Auth

          field :id, non_null(:id)
          field :name, :string

          # Require admin capability
          field :secret_key, :string do
            require_capability :admin
          end

          # Require any of these capabilities
          field :audit_log, list_of(:string) do
            require_capability [:admin, :auditor]
          end

          # Just require authentication
          field :email, :string do
            require_authenticated()
          end
        end
      end

  ## Configuration

  The extension accepts these options:

  - `:capability_key` - Key to access capabilities in user (default: :capabilities)
  - `:user_key` - Key to access user in context (default: :current_user)

  ## Context Setup

  Your GraphQL context should include the current user:

      %{current_user: %{id: "123", capabilities: [:admin, :user]}}

  """

  use Absinthe.Object.Extension

  @impl true
  def using(opts) do
    capability_key = Keyword.get(opts, :capability_key, :capabilities)
    user_key = Keyword.get(opts, :user_key, :current_user)

    quote do
      import Absinthe.Object.Extensions.Auth.Macros

      Module.register_attribute(__MODULE__, :auth_extension_config, accumulate: false)

      @auth_extension_config %{
        capability_key: unquote(capability_key),
        user_key: unquote(user_key)
      }
    end
  end

  @impl true
  def before_compile(env, _config) do
    auth_config = Module.get_attribute(env.module, :auth_extension_config)

    quote do
      @doc false
      def __auth_config__, do: unquote(Macro.escape(auth_config))
    end
  end

  # ============================================================================
  # Macros
  # ============================================================================

  defmodule Macros do
    @moduledoc false

    @doc """
    Requires one or more capabilities to access this field.

    ## Examples

        field :secret, :string do
          require_capability :admin
        end

        field :audit, :string do
          require_capability [:admin, :auditor]
        end

        field :data, :string do
          require_capability :admin, message: "Admins only"
        end

    """
    defmacro require_capability(capabilities, opts \\ []) do
      message = Keyword.get(opts, :message, "Insufficient permissions")
      capabilities = List.wrap(capabilities)

      quote do
        middleware Absinthe.Object.Extensions.Auth.CapabilityMiddleware,
                   {unquote(capabilities), unquote(message), @auth_extension_config}
      end
    end

    @doc """
    Requires the user to be authenticated to access this field.

    ## Examples

        field :profile, :user_profile do
          require_authenticated()
        end

        field :settings, :settings do
          require_authenticated message: "Please log in"
        end

    """
    defmacro require_authenticated(opts \\ []) do
      message = Keyword.get(opts, :message, "Authentication required")

      quote do
        middleware Absinthe.Object.Extensions.Auth.AuthenticatedMiddleware,
                   {unquote(message), @auth_extension_config}
      end
    end
  end

  # ============================================================================
  # Middleware
  # ============================================================================

  defmodule CapabilityMiddleware do
    @moduledoc """
    Middleware that checks if the current user has required capabilities.
    """

    @behaviour Absinthe.Middleware

    @impl true
    def call(%{state: :unresolved} = resolution, {capabilities, message, config}) do
      user_key = config.user_key
      capability_key = config.capability_key

      current_user = resolution.context[user_key]

      if has_capability?(current_user, capabilities, capability_key) do
        resolution
      else
        Absinthe.Resolution.put_result(resolution, {:error, message})
      end
    end

    def call(resolution, _config), do: resolution

    defp has_capability?(nil, _capabilities, _key), do: false

    defp has_capability?(user, capabilities, key) do
      user_capabilities = get_capabilities(user, key)

      Enum.any?(capabilities, fn cap ->
        cap in user_capabilities
      end)
    end

    defp get_capabilities(user, key) do
      case Map.get(user, key, []) do
        fun when is_function(fun, 0) -> fun.()
        caps when is_list(caps) -> caps
        cap when is_atom(cap) -> [cap]
        _ -> []
      end
    end
  end

  defmodule AuthenticatedMiddleware do
    @moduledoc """
    Middleware that checks if a user is authenticated.
    """

    @behaviour Absinthe.Middleware

    @impl true
    def call(%{state: :unresolved} = resolution, {message, config}) do
      user_key = config.user_key
      current_user = resolution.context[user_key]

      if current_user do
        resolution
      else
        Absinthe.Resolution.put_result(resolution, {:error, message})
      end
    end

    def call(resolution, _config), do: resolution
  end
end
