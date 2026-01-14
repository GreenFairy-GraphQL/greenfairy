defmodule Absinthe.Object.Dataloader.Partition do
  @moduledoc """
  Struct for managing partitioned dataloader queries.

  Partitioning allows efficient batching of nested association queries by:
  1. Building a join chain from target back to owner
  2. Adding a `partition_id_` field to results for grouping
  3. Enabling existence subqueries for nested filtering

  ## How It Works

  When loading associations with filters, instead of N+1 queries:

      # N+1 approach (bad)
      for user <- users do
        Repo.all(from o in Organization, where: o.id == ^user.organization_id)
      end

  We use a single partitioned query:

      # Partitioned approach (good)
      from o in Organization,
        where: o.id in ^organization_ids,
        select_merge: %{partition_id_: o.id}

  Results are then grouped by `partition_id_` to map back to parents.

  ## Transparent Operation

  This works transparently with standard Ecto associations - no schema
  modifications are required. The partition key is extracted from
  association metadata (`owner_key`).

  ## Fields

  - `:query` - The base Ecto query
  - `:owner` - The parent schema module (e.g., MyApp.User)
  - `:queryable` - The target schema module (e.g., MyApp.Organization)
  - `:field` - The association field name (e.g., :organization)
  - `:repo` - The Ecto repo module
  - `:sort` - List of `{direction, dynamic}` sort clauses
  - `:connection_args` - Pagination arguments (limit, offset)
  - `:windowed` - Use PostgreSQL window functions for partitioned pagination
  - `:custom_inject` - Function to modify query before execution
  - `:post_process` - Function to transform results after execution
  """

  @enforce_keys [:query, :owner, :queryable, :field]
  defstruct [
    :query,
    :owner,
    :queryable,
    :field,
    :custom_inject,
    :post_process,
    repo: nil,
    sort: [],
    connection_args: %{},
    windowed: false,
    partition_sort_direction: :asc
  ]

  @type connection_args :: %{
          optional(:limit) => non_neg_integer(),
          optional(:offset) => non_neg_integer(),
          optional(:first) => non_neg_integer(),
          optional(:last) => non_neg_integer(),
          optional(:after) => String.t(),
          optional(:before) => String.t()
        }

  @type t :: %__MODULE__{
          query: Ecto.Queryable.t(),
          owner: module(),
          queryable: module(),
          field: atom(),
          repo: module() | nil,
          sort: [{atom(), Ecto.Query.dynamic_expr()}],
          connection_args: connection_args(),
          windowed: boolean(),
          partition_sort_direction: :asc | :desc,
          custom_inject: (Ecto.Query.t(), atom(), atom() -> Ecto.Query.t()) | nil,
          post_process: (list() -> list()) | nil
        }

  @doc """
  Creates a new Partition struct.

  ## Options

  - `:query` - Required. The base Ecto query.
  - `:owner` - Required. The parent schema module.
  - `:queryable` - Required. The target schema module.
  - `:field` - Required. The association field name.
  - `:repo` - The Ecto repo module.
  - `:sort` - Sort clauses as `[{direction, dynamic}]`.
  - `:connection_args` - Pagination arguments.
  - `:windowed` - Use window functions (default: false).
  - `:custom_inject` - Query transformation function.
  - `:post_process` - Result transformation function.
  """
  def new(opts) do
    struct!(__MODULE__, opts)
  end

  @doc """
  Gets the owner key for this partition's association.

  The owner key is the foreign key field on the owner schema that
  references the related schema.
  """
  def owner_key(%__MODULE__{owner: owner, field: field}) do
    case owner.__schema__(:association, field) do
      %{owner_key: key} -> key
      _ -> raise "Association #{field} not found on #{inspect(owner)}"
    end
  end

  @doc """
  Gets the related key for this partition's association.

  The related key is the primary key field on the related schema
  that the owner references.
  """
  def related_key(%__MODULE__{owner: owner, field: field}) do
    case owner.__schema__(:association, field) do
      %{related_key: key} -> key
      %{related: related} -> hd(related.__schema__(:primary_key))
      _ -> raise "Association #{field} not found on #{inspect(owner)}"
    end
  end

  @doc """
  Gets the cardinality of this partition's association.
  """
  def cardinality(%__MODULE__{owner: owner, field: field}) do
    case owner.__schema__(:association, field) do
      %{cardinality: c} -> c
      _ -> :one
    end
  end
end
