defmodule Absinthe.Object.Deferred.Schema do
  @moduledoc """
  Schema module for deferred type compilation.

  This is the only module that creates compile-time dependencies on type modules.
  Changing any type module will cause ONLY the schema to recompile, not other types.

  ## Usage

      defmodule MyApp.GraphQL.Schema do
        use Absinthe.Object.Deferred.Schema

        # Explicitly list type modules (deferred resolution)
        import_types_from [
          MyApp.GraphQL.Types.User,
          MyApp.GraphQL.Types.Post,
          MyApp.GraphQL.Interfaces.Node
        ]

        query do
          field :user, :user do
            arg :id, non_null(:id)
            resolve &MyApp.Resolvers.get_user/3
          end
        end
      end

  ## How It Works

  1. Type modules use `Absinthe.Object.Deferred.Type` or `.Interface`
  2. They store definitions as data with module atom references
  3. At schema compile time, this module:
     - Loads all type definitions
     - Resolves module references to identifiers
     - Generates a types module with Absinthe notation
     - Imports that module into the schema
  4. Only the schema depends on type modules at compile time
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Absinthe.Schema
      use Absinthe.Schema.Notation

      import Absinthe.Object.Deferred.Schema, only: [import_types_from: 1]

      # Import built-ins
      import_types(Absinthe.Object.BuiltIns.PageInfo)
    end
  end

  @doc """
  Imports specific type modules with deferred resolution.

  Creates a generated types module containing all the Absinthe type definitions,
  then imports it into the schema. Type modules have NO dependencies on each other.
  """
  defmacro import_types_from(modules_ast) do
    env = __CALLER__
    schema_module = env.module

    # Expand each module alias to get actual module atoms
    modules =
      case modules_ast do
        {_, _, _} = ast ->
          Macro.expand(ast, env)

        list when is_list(list) ->
          Enum.map(list, fn mod_ast -> Macro.expand(mod_ast, env) end)
      end

    # Generate a unique types module name
    types_module = Module.concat(schema_module, GeneratedTypes)

    # Build the types module body (everything inside defmodule)
    types_module_body = Absinthe.Object.Deferred.Compiler.compile_types_module_body(modules)

    # Create the module at compile time using Module.create
    Module.create(
      types_module,
      quote do
        use Absinthe.Schema.Notation
        unquote(types_module_body)
      end,
      Macro.Env.location(env)
    )

    # Now import the compiled module
    quote do
      import_types(unquote(types_module))
    end
  end
end
