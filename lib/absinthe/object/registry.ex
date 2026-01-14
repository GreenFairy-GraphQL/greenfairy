defmodule Absinthe.Object.Registry do
  @moduledoc """
  Runtime registry for type implementations.

  This module maintains a mapping of structs to type identifiers,
  enabling auto-generated `resolve_type` functions for interfaces.

  Types automatically register themselves when they use `implements`
  with a `struct:` option.

  Uses `:persistent_term` for storage to persist across processes.
  """

  @registry_key {__MODULE__, :registry}
  @lock_table :absinthe_object_registry_lock

  @doc """
  Registers a struct module as implementing a type.

  Uses ETS-based locking to handle concurrent registration
  during parallel compilation.

  ## Examples

      Absinthe.Object.Registry.register(MyApp.User, :user, MyApp.GraphQL.Interfaces.Node)

  """
  def register(struct_module, type_identifier, interface_module) do
    key = {struct_module, interface_module}

    with_lock(fn ->
      current = get_registry()
      updated = Map.put(current, key, type_identifier)
      :persistent_term.put(@registry_key, updated)
      :ok
    end)
  end

  # Use ETS table with insert_new for atomic locking
  defp with_lock(fun) do
    ensure_lock_table()
    acquire_lock()

    try do
      fun.()
    after
      release_lock()
    end
  end

  defp ensure_lock_table do
    # Create the lock table if it doesn't exist
    # This is idempotent - if table exists, will raise but we catch it
    try do
      :ets.new(@lock_table, [:named_table, :public, :set])
    catch
      # Table already exists
      :error, :badarg -> :ok
    end
  end

  defp acquire_lock do
    # Try to insert a lock entry - insert_new is atomic
    # If insert returns true, we got the lock
    # If insert returns false, someone else has it - wait and retry
    if :ets.insert_new(@lock_table, {:lock, self()}) do
      :ok
    else
      Process.sleep(1)
      acquire_lock()
    end
  end

  defp release_lock do
    :ets.delete(@lock_table, :lock)
  catch
    :error, :badarg -> :ok
  end

  @doc """
  Looks up the type identifier for a struct implementing an interface.

  ## Examples

      Absinthe.Object.Registry.resolve_type(%MyApp.User{}, MyApp.GraphQL.Interfaces.Node)
      #=> :user

  """
  def resolve_type(%{__struct__: struct_module}, interface_module) do
    key = {struct_module, interface_module}
    Map.get(get_registry(), key)
  end

  def resolve_type(_, _), do: nil

  @doc """
  Gets all registered implementations for an interface.

  ## Examples

      Absinthe.Object.Registry.implementations(MyApp.GraphQL.Interfaces.Node)
      #=> [{MyApp.User, :user}, {MyApp.Post, :post}]

  """
  def implementations(interface_module) do
    get_registry()
    |> Enum.filter(fn {{_struct, iface}, _identifier} -> iface == interface_module end)
    |> Enum.map(fn {{struct, _iface}, identifier} -> {struct, identifier} end)
  end

  @doc """
  Gets all registrations.
  """
  def all do
    get_registry()
  end

  @doc """
  Clears all registrations. Useful for testing.
  """
  def clear do
    :persistent_term.put(@registry_key, %{})
    :ok
  end

  # Get the registry map, initializing if needed
  defp get_registry do
    try do
      :persistent_term.get(@registry_key)
    rescue
      ArgumentError -> %{}
    end
  end
end
