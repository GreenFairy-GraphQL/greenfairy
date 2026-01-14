defmodule Absinthe.Object.Relay.Field do
  @moduledoc """
  Field helpers for Relay-compliant types.

  This module provides macros for defining Relay-specific fields like
  global IDs and node resolvers.

  ## Usage

  Import this module in your type definitions:

      defmodule MyApp.GraphQL.Types.User do
        use Absinthe.Object.Type
        import Absinthe.Object.Relay.Field

        type "User", struct: MyApp.User do
          implements Absinthe.Object.BuiltIns.Node

          # Automatically generates globally unique ID
          global_id :id

          field :email, :string
        end
      end

  """

  alias Absinthe.Object.Relay.GlobalId

  @doc """
  Defines a globally unique ID field for Relay.

  This generates an `:id` field that returns a Base64-encoded global ID
  containing the type name and local ID.

  ## Options

  - `:source` - The source field to use for the local ID (default: `:id`)
  - `:type_name` - Override the type name used in encoding (default: uses the GraphQL type name)

  ## Examples

      # Uses the struct's :id field
      global_id :id

      # Uses a different source field
      global_id :id, source: :uuid

      # Override the type name
      global_id :id, type_name: "User"

  """
  defmacro global_id(field_name, opts \\ []) do
    source = Keyword.get(opts, :source, :id)

    quote do
      @__global_id_source__ unquote(source)
      @__global_id_opts__ unquote(opts)

      field unquote(field_name), non_null(:id) do
        resolve fn parent, _, resolution ->
          source_field = unquote(source)
          local_id = Map.get(parent, source_field)

          # Get type name from the current type's definition
          type_name =
            unquote(opts)[:type_name] ||
              Absinthe.Object.Relay.Field.get_type_name(
                __MODULE__,
                resolution
              )

          {:ok, GlobalId.encode(type_name, local_id)}
        end
      end
    end
  end

  @doc """
  Defines a custom node resolver for this type.

  When the `node(id: ID!)` query is used, this resolver will be called
  to fetch the object by its local ID.

  ## Examples

      node_resolver fn id, ctx ->
        MyApp.Accounts.get_user(id)
      end

  """
  defmacro node_resolver(resolver_fn) do
    quote do
      @__node_resolver__ unquote(resolver_fn)

      def __node_resolver__ do
        @__node_resolver__
      end
    end
  end

  @doc """
  Gets the type name for global ID encoding.

  This is called at runtime to determine the type name to use
  when encoding global IDs.
  """
  def get_type_name(module, resolution) do
    cond do
      # Try to get from module's type definition
      function_exported?(module, :__absinthe_object_type_name__, 0) ->
        module.__absinthe_object_type_name__()

      # Fall back to resolution context
      resolution && resolution.definition ->
        resolution.definition.schema_node.identifier
        |> Atom.to_string()
        |> Macro.camelize()

      true ->
        module
        |> Module.split()
        |> List.last()
    end
  end
end
