defmodule SocialNetwork.GraphQLCase do
  @moduledoc """
  This module defines the setup for tests requiring
  GraphQL query execution.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias SocialNetwork.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import SocialNetwork.DataCase
      import SocialNetwork.GraphQLCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(SocialNetwork.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end

  @doc """
  Execute a GraphQL query against the schema.
  """
  def run_query(query, variables \\ %{}, context \\ %{}) do
    Absinthe.run(
      query,
      SocialNetworkWeb.GraphQL.Schema,
      variables: variables,
      context: context
    )
  end

  @doc """
  Execute a GraphQL query as an authenticated user.
  """
  def run_query_as(query, user, variables \\ %{}) do
    run_query(query, variables, %{current_user: user})
  end

  @doc """
  Extract data from a successful GraphQL response.
  """
  def get_data({:ok, %{data: data}}), do: data
  def get_data({:ok, result}), do: result

  @doc """
  Extract errors from a GraphQL response.
  """
  def get_errors({:ok, %{errors: errors}}), do: errors
  def get_errors(_), do: nil
end
