defmodule Absinthe.Object.Deferred.Type do
  @moduledoc """
  Deferred GraphQL object type definition.

  This version stores type definitions as pure data with NO compile-time
  dependencies on other type modules. All module references are stored as
  atoms and resolved only when the schema is compiled.

  ## Usage

      defmodule MyApp.GraphQL.Types.User do
        use Absinthe.Object.Deferred.Type

        @desc "A user in the system"
        object "User", struct: MyApp.User do
          field :id, non_null(:id)
          field :email, non_null(:string)
          field :name, :string

          # References are just module atoms - NO compile-time dependency!
          has_many :posts, MyApp.GraphQL.Types.Post
          belongs_to :organization, MyApp.GraphQL.Types.Organization

          implements MyApp.GraphQL.Interfaces.Node
        end
      end

  Changing `MyApp.GraphQL.Types.Post` will NOT cause this module to recompile.
  The reference is resolved when the schema module compiles.
  """

  alias Absinthe.Object.Deferred.Definition

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Absinthe.Object.Deferred.Type, only: [object: 2, object: 3]

      Module.register_attribute(__MODULE__, :desc, accumulate: false)
      Module.register_attribute(__MODULE__, :deferred_object_def, accumulate: false)
      Module.register_attribute(__MODULE__, :deferred_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :deferred_interfaces, accumulate: true)
      Module.register_attribute(__MODULE__, :deferred_connections, accumulate: true)

      @before_compile Absinthe.Object.Deferred.Type
    end
  end

  @doc """
  Defines a GraphQL object type.

  ## Options

  - `:struct` - The backing Elixir struct (used for resolve_type)
  - `:description` - Type description (can also use @desc)
  """
  defmacro object(name, opts \\ [], do: block) do
    quote do
      @deferred_object_def %{
        name: unquote(name),
        struct: unquote(opts[:struct]),
        description: @desc || unquote(opts[:description])
      }

      @desc nil

      import Absinthe.Object.Deferred.Type,
        only: [
          field: 2,
          field: 3,
          has_many: 2,
          has_many: 3,
          has_one: 2,
          has_one: 3,
          belongs_to: 2,
          belongs_to: 3,
          implements: 1,
          connection: 2,
          connection: 3
        ]

      unquote(block)
    end
  end

  @doc "Defines a field on the object."
  defmacro field(name, type, opts \\ []) do
    quote do
      @deferred_fields %Definition.Field{
        name: unquote(name),
        type: unquote(Macro.escape(type)),
        description: @desc || unquote(opts[:description]),
        null: Keyword.get(unquote(opts), :null, true),
        args: unquote(Macro.escape(opts[:args])),
        deprecation_reason: unquote(opts[:deprecation_reason])
      }

      @desc nil
    end
  end

  @doc "Defines a has_many relationship. Module reference stored as atom - no compile dependency."
  defmacro has_many(name, type_module, opts \\ []) do
    quote do
      @deferred_fields %Definition.Field{
        name: unquote(name),
        type: {:list, {:module, unquote(type_module)}},
        description: @desc || unquote(opts[:description]),
        null: Keyword.get(unquote(opts), :null, true),
        resolve: {:dataloader, unquote(type_module), unquote(name), unquote(opts)}
      }

      @desc nil
    end
  end

  @doc "Defines a has_one relationship. Module reference stored as atom - no compile dependency."
  defmacro has_one(name, type_module, opts \\ []) do
    quote do
      @deferred_fields %Definition.Field{
        name: unquote(name),
        type: {:module, unquote(type_module)},
        description: @desc || unquote(opts[:description]),
        null: Keyword.get(unquote(opts), :null, true),
        resolve: {:dataloader, unquote(type_module), unquote(name), unquote(opts)}
      }

      @desc nil
    end
  end

  @doc "Defines a belongs_to relationship. Module reference stored as atom - no compile dependency."
  defmacro belongs_to(name, type_module, opts \\ []) do
    quote do
      @deferred_fields %Definition.Field{
        name: unquote(name),
        type: {:module, unquote(type_module)},
        description: @desc || unquote(opts[:description]),
        null: Keyword.get(unquote(opts), :null, true),
        resolve: {:dataloader, unquote(type_module), unquote(name), unquote(opts)}
      }

      @desc nil
    end
  end

  @doc "Declares interface implementation. Module reference stored as atom - no compile dependency."
  defmacro implements(interface_module) do
    quote do
      @deferred_interfaces unquote(interface_module)
    end
  end

  @doc "Defines a Relay connection field."
  defmacro connection(name, node_type, opts \\ []) do
    quote do
      @deferred_connections %Definition.Connection{
        field_name: unquote(name),
        node_type: unquote(node_type),
        edge_fields: unquote(Macro.escape(opts[:edge_fields] || [])),
        connection_fields: unquote(Macro.escape(opts[:connection_fields] || []))
      }
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    object_def = Module.get_attribute(env.module, :deferred_object_def)
    fields = Module.get_attribute(env.module, :deferred_fields) || []
    interfaces = Module.get_attribute(env.module, :deferred_interfaces) || []
    connections = Module.get_attribute(env.module, :deferred_connections) || []

    identifier = Absinthe.Object.Naming.to_identifier(object_def[:name])

    definition = %Definition.Object{
      name: object_def[:name],
      identifier: identifier,
      module: env.module,
      struct: object_def[:struct],
      description: object_def[:description],
      interfaces: Enum.reverse(interfaces),
      fields: Enum.reverse(fields),
      connections: Enum.reverse(connections)
    }

    quote do
      @doc false
      def __absinthe_object_definition__ do
        unquote(Macro.escape(definition))
      end

      @doc false
      def __absinthe_object_kind__, do: :object

      @doc false
      def __absinthe_object_identifier__, do: unquote(identifier)

      @doc false
      def __absinthe_object_struct__, do: unquote(object_def[:struct])
    end
  end
end
