defmodule Absinthe.Object.Filter do
  @moduledoc """
  Multi-dispatch for applying semantic filters across different adapters.

  This module provides dispatch for filter operations based on the
  combination of adapter type and filter type. This allows scalars to define
  semantic filter intent while adapters provide the implementation.

  ## Design

  1. **Scalars** return semantic filter structs (e.g., `%Geo.Near{}`)
  2. **Registry** maps `{adapter_module, filter_module}` to implementation functions
  3. **Implementations** translate semantic intent to adapter-specific queries

  ## Example

      # Scalar returns semantic intent
      filter :near, fn point, opts ->
        %Absinthe.Object.Filters.Geo.Near{
          point: point,
          distance: opts[:distance] || 1000
        }
      end

      # Implementation module registers handlers
      defmodule MyApp.Filters.Postgres do
        use Absinthe.Object.Filter.Impl,
          adapter: Absinthe.Object.Adapters.Ecto.Postgres

        filter_impl Geo.Near do
          def apply(_adapter, %{point: point, distance: dist}, field, query) do
            import Ecto.Query
            {:ok, from(q in query,
              where: fragment("ST_DWithin(?::geography, ?::geography, ?)",
                field(q, ^field), ^point, ^dist))}
          end
        end
      end

  """

  @doc """
  Applies a semantic filter to a query.

  ## Arguments

  - `adapter` - The adapter struct (e.g., `%Ecto.Postgres{}`)
  - `filter` - The semantic filter struct (e.g., `%Geo.Near{}`)
  - `field` - The field name being filtered
  - `query` - The query being built

  ## Returns

  - `{:ok, updated_query}` - Filter applied successfully
  - `{:error, reason}` - Filter could not be applied

  """
  def apply(adapter, filter, field, query) do
    adapter_module = adapter.__struct__
    filter_module = filter.__struct__

    case get_implementation(adapter_module, filter_module) do
      nil ->
        {:error, {:no_filter_implementation, adapter_module, filter_module}}

      impl_module ->
        impl_module.apply(adapter, filter, field, query)
    end
  end

  @doc """
  Convenience function to apply a filter with error handling.
  """
  def apply!(adapter, filter, field, query) do
    case apply(adapter, filter, field, query) do
      {:ok, result} -> result
      {:error, reason} -> raise "Filter error: #{inspect(reason)}"
    end
  end

  # Registry for filter implementations
  # Key: {adapter_module, filter_module}
  # Value: implementation module
  @doc false
  def register_implementation(adapter_module, filter_module, impl_module) do
    key = {adapter_module, filter_module}
    current = :persistent_term.get({__MODULE__, :implementations}, %{})
    :persistent_term.put({__MODULE__, :implementations}, Map.put(current, key, impl_module))
    :ok
  end

  @doc false
  def get_implementation(adapter_module, filter_module) do
    implementations = :persistent_term.get({__MODULE__, :implementations}, %{})
    Map.get(implementations, {adapter_module, filter_module})
  end

  @doc """
  Returns all registered implementations.
  """
  def registered_implementations do
    :persistent_term.get({__MODULE__, :implementations}, %{})
  end
end
