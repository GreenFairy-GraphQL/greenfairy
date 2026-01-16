defmodule GreenFairy.TypeRegistry do
  @moduledoc """
  Registry for mapping GraphQL type identifiers to their implementing modules.

  This registry is used for graph-based type discovery, allowing the schema
  to follow type references from field definitions.

  ## Usage

  Types automatically register themselves during compilation:

      defmodule MyApp.GraphQL.Types.User do
        use GreenFairy.Type

        type "User", struct: MyApp.Accounts.User do
          field :id, non_null(:id)
          field :posts, list_of(:post)  # References :post type
        end
      end

  The schema can then look up the Post module via:

      TypeRegistry.lookup_module(:post)
      # => MyApp.GraphQL.Types.Post

  """

  @table_name :green_fairy_type_registry

  @doc """
  Initializes the registry table.

  This is called automatically during compilation.
  """
  def init do
    unless table_exists?() do
      :ets.new(@table_name, [:set, :public, :named_table])
    end

    :ok
  end

  @doc """
  Registers a type identifier => module mapping.

  Called automatically from each type's `__before_compile__` callback.

  ## Examples

      TypeRegistry.register(:user, MyApp.GraphQL.Types.User)

  """
  def register(identifier, module) when is_atom(identifier) and is_atom(module) do
    init()
    :ets.insert(@table_name, {identifier, module})
    :ok
  end

  @doc """
  Looks up the module for a given type identifier.

  Returns the module atom or nil if not found.

  ## Examples

      TypeRegistry.lookup_module(:user)
      # => MyApp.GraphQL.Types.User

      TypeRegistry.lookup_module(:unknown)
      # => nil

  """
  def lookup_module(identifier) when is_atom(identifier) do
    if table_exists?() do
      case :ets.lookup(@table_name, identifier) do
        [{^identifier, module}] -> module
        [] -> nil
      end
    else
      nil
    end
  end

  @doc """
  Returns all registered type identifier => module mappings.

  ## Examples

      TypeRegistry.all()
      # => [user: MyApp.GraphQL.Types.User, post: MyApp.GraphQL.Types.Post, ...]

  """
  def all do
    if table_exists?() do
      :ets.tab2list(@table_name)
    else
      []
    end
  end

  @doc """
  Clears all registrations.

  Primarily used in tests.
  """
  def clear do
    if table_exists?() do
      :ets.delete_all_objects(@table_name)
    end

    :ok
  end

  defp table_exists? do
    :ets.whereis(@table_name) != :undefined
  end

  @doc """
  Checks if a type identifier refers to a GreenFairy enum.

  Returns true if the identifier is registered and the module
  has `__green_fairy_kind__/0` returning `:enum`.

  ## Examples

      TypeRegistry.is_enum?(:order_status)
      # => true (if OrderStatus is defined with GreenFairy.Enum)

      TypeRegistry.is_enum?(:user)
      # => false (User is an object type, not an enum)

      TypeRegistry.is_enum?(:string)
      # => false (built-in scalar, not registered)

  """
  def is_enum?(identifier) when is_atom(identifier) do
    case lookup_module(identifier) do
      nil ->
        false

      module ->
        Code.ensure_loaded?(module) and
          function_exported?(module, :__green_fairy_kind__, 0) and
          module.__green_fairy_kind__() == :enum
    end
  end

  @doc """
  Returns all registered enum identifiers.

  Useful for generating enum-specific operator inputs during schema compilation.

  ## Examples

      TypeRegistry.all_enums()
      # => [:order_status, :user_role, :visibility]

  """
  def all_enums do
    all()
    |> Enum.filter(fn {identifier, _module} -> is_enum?(identifier) end)
    |> Enum.map(fn {identifier, _module} -> identifier end)
  end
end
