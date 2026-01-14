defmodule Absinthe.Object.Operations do
  @moduledoc """
  Define query, mutation, and subscription fields in a single module.

  ## Usage

      defmodule MyApp.GraphQL.Operations.Users do
        use Absinthe.Object.Operations

        query_field :user, :user do
          arg :id, non_null(:id)
          resolve &MyApp.Resolvers.User.get/3
        end

        query_field :users, list_of(:user) do
          resolve &MyApp.Resolvers.User.list/3
        end

        mutation_field :create_user, :user do
          arg :input, non_null(:create_user_input)
          resolve &MyApp.Resolvers.User.create/3
        end

        mutation_field :update_user, :user do
          arg :id, non_null(:id)
          arg :input, non_null(:update_user_input)
          resolve &MyApp.Resolvers.User.update/3
        end

        subscription_field :user_updated, :user do
          arg :user_id, :id

          config fn args, _ ->
            {:ok, topic: args[:user_id] || "*"}
          end
        end
      end

  This is equivalent to having separate Query, Mutation, and Subscription
  modules but lets you group related operations together.

  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      # Register attributes first
      Module.register_attribute(__MODULE__, :absinthe_object_query_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :absinthe_object_mutation_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :absinthe_object_subscription_fields, accumulate: true)

      # Register our before_compile FIRST so it runs before Absinthe's
      @before_compile Absinthe.Object.Operations

      # Then use Absinthe.Schema.Notation (which registers its own @before_compile)
      use Absinthe.Schema.Notation

      import Absinthe.Object.Operations,
        only: [
          query_field: 2,
          query_field: 3,
          mutation_field: 2,
          mutation_field: 3,
          subscription_field: 2,
          subscription_field: 3
        ]
    end
  end

  @doc """
  Defines a query field.

  ## Examples

      query_field :user, :user do
        arg :id, non_null(:id)
        resolve &get_user/3
      end

  """
  defmacro query_field(name, type, do: block) do
    quote do
      @absinthe_object_query_fields {unquote(name), unquote(Macro.escape(type)), unquote(Macro.escape(block))}
    end
  end

  defmacro query_field(name, type) do
    quote do
      @absinthe_object_query_fields {unquote(name), unquote(Macro.escape(type)), nil}
    end
  end

  @doc """
  Defines a mutation field.

  ## Examples

      mutation_field :create_user, :user do
        arg :input, non_null(:create_user_input)
        resolve &create_user/3
      end

  """
  defmacro mutation_field(name, type, do: block) do
    quote do
      @absinthe_object_mutation_fields {unquote(name), unquote(Macro.escape(type)), unquote(Macro.escape(block))}
    end
  end

  defmacro mutation_field(name, type) do
    quote do
      @absinthe_object_mutation_fields {unquote(name), unquote(Macro.escape(type)), nil}
    end
  end

  @doc """
  Defines a subscription field.

  ## Examples

      subscription_field :user_updated, :user do
        config fn args, _ ->
          {:ok, topic: args[:user_id] || "*"}
        end
      end

  """
  defmacro subscription_field(name, type, do: block) do
    quote do
      @absinthe_object_subscription_fields {unquote(name), unquote(Macro.escape(type)), unquote(Macro.escape(block))}
    end
  end

  defmacro subscription_field(name, type) do
    quote do
      @absinthe_object_subscription_fields {unquote(name), unquote(Macro.escape(type)), nil}
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    query_fields = Module.get_attribute(env.module, :absinthe_object_query_fields) || []
    mutation_fields = Module.get_attribute(env.module, :absinthe_object_mutation_fields) || []
    subscription_fields = Module.get_attribute(env.module, :absinthe_object_subscription_fields) || []

    query_object = generate_fields_object(:absinthe_object_queries, Enum.reverse(query_fields))
    mutation_object = generate_fields_object(:absinthe_object_mutations, Enum.reverse(mutation_fields))
    subscription_object = generate_fields_object(:absinthe_object_subscriptions, Enum.reverse(subscription_fields))

    has_queries = query_fields != []
    has_mutations = mutation_fields != []
    has_subscriptions = subscription_fields != []

    quote do
      unquote(query_object)
      unquote(mutation_object)
      unquote(subscription_object)

      @doc false
      def __absinthe_object_definition__ do
        %{
          kind: :operations,
          has_queries: unquote(has_queries),
          has_mutations: unquote(has_mutations),
          has_subscriptions: unquote(has_subscriptions)
        }
      end

      @doc false
      def __absinthe_object_kind__ do
        :operations
      end
    end
  end

  defp generate_fields_object(_name, []), do: nil

  defp generate_fields_object(name, fields) do
    field_definitions =
      Enum.map(fields, fn {field_name, type, block} ->
        if block do
          quote do
            field unquote(field_name), unquote(type) do
              unquote(block)
            end
          end
        else
          quote do
            field unquote(field_name), unquote(type)
          end
        end
      end)

    quote do
      object unquote(name) do
        (unquote_splicing(field_definitions))
      end
    end
  end
end
