defmodule GreenFairy.CQL.QueryBuilder do
  @moduledoc """
  Public API for applying CQL filters and ordering to Ecto queries.

  This module provides the high-level interface used by GraphQL resolvers
  to apply CQL filter and order specifications to database queries.

  ## Usage

  Typically called from connection resolvers:

      def list_users(args, _info) do
        User
        |> QueryBuilder.apply_where(args[:where], MyApp.UserType)
        |> QueryBuilder.apply_order_by(args[:order_by], MyApp.UserType)
        |> Repo.all()
      end

  ## How It Works

  QueryBuilder acts as a facade that:
  1. Retrieves CQL configuration from the type module
  2. Determines the appropriate adapter for the database
  3. Delegates to QueryCompiler for filter compilation
  4. Delegates to OrderBuilder for ordering (when implemented)

  The adapter system ensures that database-specific operators and features
  are handled correctly.
  """

  alias GreenFairy.CQL.QueryCompiler

  @doc """
  Applies a CQL filter to an Ecto query.

  ## Parameters

  - `query` - The base Ecto query to filter
  - `filter` - The CQL filter input map (can be nil)
  - `type_module` - The GraphQL type module with CQL configuration
  - `opts` - Additional options (optional)

  ## Returns

  `{:ok, filtered_query}` or `{:error, message}` on validation failure.

  ## Example

      iex> filter = %{name: %{_eq: "Alice"}, age: %{_gte: 18}}
      iex> QueryBuilder.apply_where(User, filter, MyApp.UserType)
      {:ok, #Ecto.Query<...>}
  """
  def apply_where(query, filter, type_module, opts \\ [])
  def apply_where(query, nil, _type_module, _opts), do: {:ok, query}
  def apply_where(query, filter, _type_module, _opts) when filter == %{}, do: {:ok, query}

  def apply_where(query, filter, type_module, opts) do
    config = type_module.__cql_config__()
    adapter = type_module.__cql_adapter__()

    compile_opts =
      opts
      |> Keyword.put(:adapter, adapter)
      |> Keyword.put_new(:parent_alias, :parent)

    QueryCompiler.compile(query, filter, config.struct, compile_opts)
  end

  @doc """
  Applies a CQL filter, raising on validation errors.
  """
  def apply_where!(query, filter, type_module, opts \\ []) do
    case apply_where(query, filter, type_module, opts) do
      {:ok, result} -> result
      {:error, message} -> raise ArgumentError, message
    end
  end

  @doc """
  Applies CQL ordering to an Ecto query.

  ## Parameters

  - `query` - The base Ecto query to order
  - `order_specs` - List of order specifications or single order spec
  - `type_module` - The GraphQL type module with CQL configuration
  - `opts` - Additional options (optional)

  ## Returns

  The ordered query.

  ## Example

      iex> order = [%{field: :name, direction: :asc}]
      iex> QueryBuilder.apply_order_by(User, order, MyApp.UserType)
      #Ecto.Query<...>
  """
  def apply_order_by(query, order_specs, _type_module, _opts \\ [])
  def apply_order_by(query, nil, _type_module, _opts), do: query
  def apply_order_by(query, [], _type_module, _opts), do: query

  def apply_order_by(query, order_specs, type_module, opts) do
    alias GreenFairy.CQL.OrderBuilder

    config = type_module.__cql_config__()
    OrderBuilder.apply_order(query, order_specs, config.struct, opts)
  end
end
