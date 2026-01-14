defmodule Absinthe.Object.Deferred.Definition do
  @moduledoc """
  Data structures for storing GraphQL type definitions.

  These definitions are pure data with no compile-time dependencies.
  Type references are stored as module atoms, resolved only at schema compilation.
  """

  defmodule Field do
    @moduledoc "Represents a GraphQL field definition."
    defstruct [
      :name,
      :type,
      :description,
      :null,
      :resolve,
      :args,
      :deprecation_reason
    ]

    @type t :: %__MODULE__{
            name: atom(),
            type: type_ref(),
            description: String.t() | nil,
            null: boolean(),
            resolve: term() | nil,
            args: [Arg.t()] | nil,
            deprecation_reason: String.t() | nil
          }

    @type type_ref ::
            atom()
            | {:non_null, type_ref()}
            | {:list, type_ref()}
            | {:module, module()}
  end

  defmodule Arg do
    @moduledoc "Represents a GraphQL argument definition."
    defstruct [:name, :type, :default_value, :description]

    @type t :: %__MODULE__{
            name: atom(),
            type: Field.type_ref(),
            default_value: term(),
            description: String.t() | nil
          }
  end

  defmodule Object do
    @moduledoc "Represents a GraphQL object type definition."
    defstruct [
      :name,
      :identifier,
      :module,
      :struct,
      :description,
      :interfaces,
      :fields,
      :connections
    ]

    @type t :: %__MODULE__{
            name: String.t(),
            identifier: atom(),
            module: module(),
            struct: module() | nil,
            description: String.t() | nil,
            interfaces: [module()],
            fields: [Field.t()],
            connections: [Connection.t()]
          }
  end

  defmodule Interface do
    @moduledoc "Represents a GraphQL interface definition."
    defstruct [
      :name,
      :identifier,
      :module,
      :description,
      :fields,
      :resolve_type
    ]

    @type t :: %__MODULE__{
            name: String.t(),
            identifier: atom(),
            module: module(),
            description: String.t() | nil,
            fields: [Field.t()],
            resolve_type: term() | nil
          }
  end

  defmodule Connection do
    @moduledoc "Represents a Relay connection definition."
    defstruct [
      :field_name,
      :node_type,
      :edge_fields,
      :connection_fields
    ]

    @type t :: %__MODULE__{
            field_name: atom(),
            node_type: module() | atom(),
            edge_fields: [Field.t()],
            connection_fields: [Field.t()]
          }
  end

  defmodule Input do
    @moduledoc "Represents a GraphQL input object definition."
    defstruct [:name, :identifier, :module, :description, :fields]

    @type t :: %__MODULE__{
            name: String.t(),
            identifier: atom(),
            module: module(),
            description: String.t() | nil,
            fields: [Field.t()]
          }
  end

  defmodule Enum do
    @moduledoc "Represents a GraphQL enum definition."
    defstruct [:name, :identifier, :module, :description, :values]

    @type t :: %__MODULE__{
            name: String.t(),
            identifier: atom(),
            module: module(),
            description: String.t() | nil,
            values: [{atom(), Keyword.t()}]
          }
  end

  defmodule Union do
    @moduledoc "Represents a GraphQL union definition."
    defstruct [:name, :identifier, :module, :description, :types, :resolve_type]

    @type t :: %__MODULE__{
            name: String.t(),
            identifier: atom(),
            module: module(),
            description: String.t() | nil,
            types: [module()],
            resolve_type: term() | nil
          }
  end

  defmodule Scalar do
    @moduledoc "Represents a GraphQL scalar definition."
    defstruct [:name, :identifier, :module, :description, :parse, :serialize]

    @type t :: %__MODULE__{
            name: String.t(),
            identifier: atom(),
            module: module(),
            description: String.t() | nil,
            parse: (term() -> {:ok, term()} | :error),
            serialize: (term() -> term())
          }
  end
end
