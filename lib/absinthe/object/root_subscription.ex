defmodule Absinthe.Object.RootSubscription do
  @moduledoc """
  Define root subscription fields in a dedicated module.

  ## Usage

      defmodule MyApp.GraphQL.Subscription do
        use Absinthe.Object.RootSubscription

        root_subscription_fields do
          field :user_created, :user do
            config fn _, _ ->
              {:ok, topic: "users"}
            end
          end

          field :user_updated, :user do
            arg :user_id, :id

            config fn args, _ ->
              {:ok, topic: args[:user_id] || "*"}
            end
          end
        end
      end

  Then reference in your schema:

      defmodule MyApp.GraphQL.Schema do
        use Absinthe.Object.Schema,
          discover: [MyApp.GraphQL],
          subscription: MyApp.GraphQL.Subscription
      end

  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Absinthe.Schema.Notation

      import Absinthe.Object.RootSubscription, only: [root_subscription_fields: 1]

      @before_compile Absinthe.Object.RootSubscription
    end
  end

  @doc """
  Define subscription fields for this root subscription module.
  """
  defmacro root_subscription_fields(do: block) do
    quote do
      @absinthe_object_has_root_subscription_fields true

      # Define the object that holds all subscription fields
      object :absinthe_object_root_subscription_fields do
        unquote(block)
      end
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    has_fields = Module.get_attribute(env.module, :absinthe_object_has_root_subscription_fields)

    if !has_fields do
      raise CompileError,
        file: env.file,
        line: env.line,
        description: "RootSubscription module must define fields using root_subscription_fields/1"
    end

    quote do
      @doc false
      def __absinthe_object_definition__ do
        %{kind: :root_subscription}
      end

      @doc false
      def __absinthe_object_kind__ do
        :root_subscription
      end

      @doc false
      def __absinthe_object_subscription_fields_identifier__ do
        :absinthe_object_root_subscription_fields
      end
    end
  end
end
