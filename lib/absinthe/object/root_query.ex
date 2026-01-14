defmodule Absinthe.Object.RootQuery do
  @moduledoc """
  Define root query fields in a dedicated module.

  ## Usage

      defmodule MyApp.GraphQL.Query do
        use Absinthe.Object.RootQuery

        root_query_fields do
          field :user, :user do
            arg :id, non_null(:id)
            resolve &MyApp.Resolvers.User.get/3
          end

          field :users, list_of(:user) do
            resolve &MyApp.Resolvers.User.list/3
          end
        end
      end

  Then reference in your schema:

      defmodule MyApp.GraphQL.Schema do
        use Absinthe.Object.Schema,
          discover: [MyApp.GraphQL],
          query: MyApp.GraphQL.Query
      end

  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Absinthe.Schema.Notation

      import Absinthe.Object.RootQuery, only: [root_query_fields: 1]

      @before_compile Absinthe.Object.RootQuery
    end
  end

  @doc """
  Define query fields for this root query module.
  """
  defmacro root_query_fields(do: block) do
    quote do
      @absinthe_object_has_root_query_fields true

      # Define the object that holds all query fields
      object :absinthe_object_root_query_fields do
        unquote(block)
      end
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    has_fields = Module.get_attribute(env.module, :absinthe_object_has_root_query_fields)

    if !has_fields do
      raise CompileError,
        file: env.file,
        line: env.line,
        description: "RootQuery module must define fields using root_query_fields/1"
    end

    quote do
      @doc false
      def __absinthe_object_definition__ do
        %{kind: :root_query}
      end

      @doc false
      def __absinthe_object_kind__ do
        :root_query
      end

      @doc false
      def __absinthe_object_query_fields_identifier__ do
        :absinthe_object_root_query_fields
      end
    end
  end
end
