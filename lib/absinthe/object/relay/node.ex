defmodule Absinthe.Object.Relay.Node do
  @moduledoc """
  Relay Node interface and query field support.

  This module provides the standard Relay `node` query field that allows
  fetching any object by its global ID.

  ## Schema Integration

  Add the node query to your schema:

      defmodule MyApp.GraphQL.Schema do
        use Absinthe.Object.Schema, discover: [MyApp.GraphQL]
        use Absinthe.Object.Relay.Node

        # This adds the node(id: ID!) query field
      end

  ## Type Registration

  Types that implement the Node interface must register themselves:

      defmodule MyApp.GraphQL.Types.User do
        use Absinthe.Object.Type

        type "User", struct: MyApp.User do
          implements Absinthe.Object.BuiltIns.Node, node: true

          global_id :id
          field :email, :string
        end
      end

  ## Custom Node Resolution

  By default, nodes are resolved using your adapter's `get_by_id` function.
  You can customize resolution per-type:

      type "User", struct: MyApp.User do
        implements Absinthe.Object.BuiltIns.Node, node: true

        node_resolver fn id, _ctx ->
          MyApp.Accounts.get_user(id)
        end

        global_id :id
        field :email, :string
      end

  """

  alias Absinthe.Object.Relay.GlobalId

  @doc """
  Macro to add Relay node query support to a schema.

  This adds:
  - `node(id: ID!)` query field
  - `nodes(ids: [ID!]!)` query field for batch fetching

  ## Options

  - `:repo` - The Ecto repo to use for fetching (if using Ecto adapter)

  """
  defmacro __using__(opts \\ []) do
    quote do
      @__relay_node_opts__ unquote(opts)

      @before_compile Absinthe.Object.Relay.Node
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      import Absinthe.Schema.Notation

      # Add node query field
      object :relay_node_queries do
        @desc "Fetches an object given its global ID"
        field :node, :node do
          arg :id, non_null(:id)

          resolve fn _, %{id: global_id}, resolution ->
            Absinthe.Object.Relay.Node.resolve_node(
              global_id,
              resolution,
              @__relay_node_opts__
            )
          end
        end

        @desc "Fetches objects given their global IDs"
        field :nodes, list_of(:node) do
          arg :ids, non_null(list_of(non_null(:id)))

          resolve fn _, %{ids: global_ids}, resolution ->
            results =
              Enum.map(global_ids, fn global_id ->
                case Absinthe.Object.Relay.Node.resolve_node(
                       global_id,
                       resolution,
                       @__relay_node_opts__
                     ) do
                  {:ok, result} -> result
                  {:error, _} -> nil
                end
              end)

            {:ok, results}
          end
        end
      end

      # Import the node queries into the root query
      def __absinthe_relay_node_queries__, do: :relay_node_queries
    end
  end

  @doc """
  Resolves a node from its global ID.

  This function:
  1. Decodes the global ID to get type name and local ID
  2. Finds the type module for the type name
  3. Calls the type's node resolver or uses the default adapter resolution

  """
  def resolve_node(global_id, resolution, opts \\ []) do
    with {:ok, {type_name, local_id}} <- GlobalId.decode_id(global_id),
         {:ok, type_module} <- find_type_module(type_name, resolution.schema),
         {:ok, result} <- fetch_node(type_module, local_id, resolution.context, opts) do
      {:ok, result}
    else
      {:error, :invalid_global_id} ->
        {:error, "Invalid global ID format"}

      {:error, :type_not_found} ->
        {:error, "Unknown type in global ID"}

      {:error, :not_found} ->
        {:ok, nil}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Find the type module for a given type name
  defp find_type_module(type_name, schema) do
    # Convert type name to identifier (e.g., "User" -> :user)
    identifier = type_name_to_identifier(type_name)

    # Look up the type in the schema
    case Absinthe.Schema.lookup_type(schema, identifier) do
      nil ->
        {:error, :type_not_found}

      type ->
        # Get the source module if available
        case get_type_module(type) do
          nil -> {:error, :type_not_found}
          module -> {:ok, module}
        end
    end
  end

  # Convert "UserProfile" to :user_profile
  defp type_name_to_identifier(type_name) do
    type_name
    |> String.replace(~r/([A-Z])/, "_\\1")
    |> String.trim_leading("_")
    |> String.downcase()
    |> String.to_atom()
  end

  # Get the source module from a type definition
  defp get_type_module(%{__private__: private}) do
    Keyword.get(private, :__absinthe_object_module__)
  end

  defp get_type_module(_), do: nil

  # Fetch the node using the type's resolver or default adapter
  defp fetch_node(type_module, local_id, context, opts) do
    cond do
      # Check for custom node resolver
      function_exported?(type_module, :__node_resolver__, 0) ->
        resolver = type_module.__node_resolver__()
        resolver.(local_id, context)

      # Check for struct and use adapter
      function_exported?(type_module, :__absinthe_object_struct__, 0) ->
        struct = type_module.__absinthe_object_struct__()
        fetch_with_adapter(struct, local_id, context, opts)

      true ->
        {:error, :no_resolver}
    end
  end

  # Fetch using the Ecto adapter pattern
  defp fetch_with_adapter(struct, local_id, context, opts) do
    repo = opts[:repo] || context[:repo]

    if repo do
      case repo.get(struct, local_id) do
        nil -> {:error, :not_found}
        result -> {:ok, result}
      end
    else
      {:error, :no_repo}
    end
  end
end
