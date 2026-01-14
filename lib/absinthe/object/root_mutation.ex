defmodule Absinthe.Object.RootMutation do
  @moduledoc """
  Define root mutation fields in a dedicated module.

  ## Usage

      defmodule MyApp.GraphQL.Mutation do
        use Absinthe.Object.RootMutation

        root_mutation_fields do
          field :create_user, :user do
            arg :input, non_null(:create_user_input)
            resolve &MyApp.Resolvers.User.create/3
          end

          field :update_user, :user do
            arg :id, non_null(:id)
            arg :input, non_null(:update_user_input)
            resolve &MyApp.Resolvers.User.update/3
          end
        end
      end

  Then reference in your schema:

      defmodule MyApp.GraphQL.Schema do
        use Absinthe.Object.Schema,
          discover: [MyApp.GraphQL],
          mutation: MyApp.GraphQL.Mutation
      end

  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Absinthe.Schema.Notation

      import Absinthe.Object.RootMutation, only: [root_mutation_fields: 1]

      @before_compile Absinthe.Object.RootMutation
    end
  end

  @doc """
  Define mutation fields for this root mutation module.
  """
  defmacro root_mutation_fields(do: block) do
    quote do
      @absinthe_object_has_root_mutation_fields true

      # Define the object that holds all mutation fields
      object :absinthe_object_root_mutation_fields do
        unquote(block)
      end
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    has_fields = Module.get_attribute(env.module, :absinthe_object_has_root_mutation_fields)

    if !has_fields do
      raise CompileError,
        file: env.file,
        line: env.line,
        description: "RootMutation module must define fields using root_mutation_fields/1"
    end

    quote do
      @doc false
      def __absinthe_object_definition__ do
        %{kind: :root_mutation}
      end

      @doc false
      def __absinthe_object_kind__ do
        :root_mutation
      end

      @doc false
      def __absinthe_object_mutation_fields_identifier__ do
        :absinthe_object_root_mutation_fields
      end
    end
  end
end
