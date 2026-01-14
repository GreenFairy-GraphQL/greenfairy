defmodule Absinthe.Object.Deferred.Registry do
  @moduledoc """
  Runtime registry for deferred type definitions.

  Types register themselves when their modules are loaded. The schema compiler
  queries this registry to assemble all types without compile-time dependencies.

  ## How it works

  1. Each type module calls `register(__MODULE__)` at load time
  2. Registry stores the module reference (not the definition - avoids keeping large data in ETS)
  3. Schema compiler calls `all_types/0` to get registered modules
  4. Schema compiler calls `module.__absinthe_object_definition__()` at schema compile time

  This means:
  - Type modules have NO compile-time dependencies on each other
  - Only the schema module depends on type modules
  - Changing a type recompiles only that type + schema
  """

  @table __MODULE__
  @lock_table Module.concat(__MODULE__, Lock)

  @doc "Registers a type module with the registry."
  @spec register(module(), atom()) :: :ok
  def register(module, kind) when is_atom(module) and is_atom(kind) do
    ensure_tables()
    :ets.insert(@table, {{kind, module}, true})
    :ok
  end

  @doc "Returns all registered type modules."
  @spec all_modules() :: [module()]
  def all_modules do
    ensure_tables()

    @table
    |> :ets.tab2list()
    |> Enum.map(fn {{_kind, module}, _} -> module end)
  end

  @doc "Returns all registered type modules of a specific kind."
  @spec modules_of_kind(atom()) :: [module()]
  def modules_of_kind(kind) do
    ensure_tables()

    @table
    |> :ets.match({{kind, :"$1"}, :_})
    |> List.flatten()
  end

  @doc "Returns all type definitions, loading them from registered modules."
  @spec all_definitions() :: [struct()]
  def all_definitions do
    all_modules()
    |> Enum.map(& &1.__absinthe_object_definition__())
  end

  @doc "Returns definitions of a specific kind."
  @spec definitions_of_kind(atom()) :: [struct()]
  def definitions_of_kind(kind) do
    modules_of_kind(kind)
    |> Enum.map(& &1.__absinthe_object_definition__())
  end

  @doc "Clears all registrations. Useful for testing."
  @spec clear() :: :ok
  def clear do
    ensure_tables()
    :ets.delete_all_objects(@table)
    :ok
  end

  @doc "Checks if a module is registered."
  @spec registered?(module()) :: boolean()
  def registered?(module) do
    ensure_tables()
    :ets.member(@table, {:_, module})
  end

  # Ensure ETS tables exist, creating them if needed
  defp ensure_tables do
    if :ets.whereis(@lock_table) == :undefined do
      try do
        :ets.new(@lock_table, [:named_table, :public, :set])
      rescue
        ArgumentError -> :ok
      end
    end

    with_lock(fn ->
      if :ets.whereis(@table) == :undefined do
        try do
          :ets.new(@table, [:named_table, :public, :set])
        rescue
          ArgumentError -> :ok
        end
      end
    end)
  end

  defp with_lock(fun) do
    key = :init_lock
    ref = make_ref()

    case :ets.insert_new(@lock_table, {key, ref}) do
      true ->
        try do
          fun.()
        after
          :ets.delete(@lock_table, key)
        end

      false ->
        Process.sleep(1)
        with_lock(fun)
    end
  end
end
