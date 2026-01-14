defmodule Absinthe.Object.Relay do
  @moduledoc """
  Relay specification support for Absinthe.Object.

  This module provides full Relay compliance including:

  - **Global Object Identification** - Globally unique IDs and the `node` query
  - **Cursor Connections** - Pagination with edges, cursors, and page info
  - **Mutations** - Input/payload pattern with `clientMutationId`

  ## Quick Start

  ### 1. Enable Relay in your Schema

      defmodule MyApp.GraphQL.Schema do
        use Absinthe.Object.Schema, discover: [MyApp.GraphQL]
        use Absinthe.Object.Relay

        # Optional: Configure the repo for node resolution
        @relay_repo MyApp.Repo
      end

  ### 2. Define Node-implementing Types

      defmodule MyApp.GraphQL.Types.User do
        use Absinthe.Object.Type
        import Absinthe.Object.Relay.Field

        type "User", struct: MyApp.User do
          implements Absinthe.Object.BuiltIns.Node

          # Generates globally unique ID
          global_id :id

          # Optional: Custom node resolver
          node_resolver fn id, _ctx ->
            MyApp.Accounts.get_user(id)
          end

          field :email, :string
          field :name, :string

          # Relay connections work seamlessly
          connection :friends, MyApp.GraphQL.Types.User do
            edge do
              field :since, :datetime
            end
          end
        end
      end

  ### 3. Define Relay Mutations

      defmodule MyApp.GraphQL.Mutations.UserMutations do
        use Absinthe.Object.Mutation
        import Absinthe.Object.Relay.Mutation

        mutations do
          relay_mutation :create_user do
            input do
              field :email, non_null(:string)
              field :name, :string
            end

            output do
              field :user, :user
            end

            resolve fn input, _ctx ->
              case MyApp.Accounts.create_user(input) do
                {:ok, user} -> {:ok, %{user: user}}
                {:error, _} -> {:error, "Failed to create user"}
              end
            end
          end
        end
      end

  ## Features

  ### Global IDs

  The `global_id` macro generates a field that returns a Base64-encoded
  ID containing both the type name and local ID:

      global_id :id                    # Uses struct's :id field
      global_id :id, source: :uuid     # Uses a different field
      global_id :id, type_name: "User" # Override type name

  Decode global IDs with `Absinthe.Object.Relay.GlobalId`:

      GlobalId.decode("VXNlcjoxMjM=")
      #=> {:ok, {"User", "123"}}

  ### Node Query

  The `node` query fetches any object by its global ID:

      query {
        node(id: "VXNlcjoxMjM=") {
          id
          ... on User {
            email
          }
        }
      }

  ### Connections

  Use the `connection` macro for Relay-compliant pagination:

      connection :posts, MyApp.GraphQL.Types.Post

  This generates:
  - `PostsConnection` type with `edges` and `pageInfo`
  - `PostsEdge` type with `node` and `cursor`
  - Standard pagination arguments (`first`, `after`, `last`, `before`)

  ### Mutations

  Use `relay_mutation` for Relay-compliant mutations with `clientMutationId`:

      relay_mutation :update_user do
        input do
          field :id, non_null(:id)
          field :name, :string
        end

        output do
          field :user, :user
        end

        resolve fn input, ctx -> ... end
      end

  ## Modules

  - `Absinthe.Object.Relay.GlobalId` - Global ID encoding/decoding
  - `Absinthe.Object.Relay.Node` - Node query field
  - `Absinthe.Object.Relay.Field` - Field helpers (`global_id`, `node_resolver`)
  - `Absinthe.Object.Relay.Mutation` - Mutation helpers (`relay_mutation`)
  - `Absinthe.Object.Field.Connection` - Connection pagination

  ## See Also

  - [Relay Specification](https://relay.dev/docs/guides/graphql-server-specification/)
  - [Global Object Identification](https://relay.dev/graphql/objectidentification.htm)
  - [Cursor Connections](https://relay.dev/graphql/connections.htm)
  - [Mutations](https://relay.dev/graphql/mutations.htm)
  """

  @doc """
  Enables full Relay support in your schema.

  This macro adds:
  - `node(id: ID!)` query field
  - `nodes(ids: [ID!]!)` query field
  - Node interface resolution

  ## Options

  - `:repo` - Ecto repo for default node resolution

  ## Example

      defmodule MyApp.Schema do
        use Absinthe.Object.Schema, discover: [MyApp.GraphQL]
        use Absinthe.Object.Relay, repo: MyApp.Repo
      end

  """
  defmacro __using__(opts \\ []) do
    quote do
      use Absinthe.Object.Relay.Node, unquote(opts)

      # Re-export commonly used modules for convenience
      @doc false
      def __relay_enabled__, do: true
    end
  end

  # Delegate to submodules
  defdelegate encode_id(type, local_id), to: __MODULE__.GlobalId, as: :encode
  defdelegate decode_id(global_id), to: __MODULE__.GlobalId, as: :decode
  defdelegate decode_id!(global_id), to: __MODULE__.GlobalId, as: :decode!
end
