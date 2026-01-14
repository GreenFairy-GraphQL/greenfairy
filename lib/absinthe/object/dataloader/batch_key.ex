defmodule Absinthe.Object.Dataloader.BatchKey do
  @moduledoc """
  Batch key for partitioned dataloader queries.

  The batch key identifies a unique batch of records to load, including
  the partition key for efficient result grouping.

  ## Fields

  - `:field` - The association field name being loaded
  - `:args` - Arguments passed to the loader (filters, etc.)
  - `:queryable` - The parent schema module
  - `:partition_key` - The foreign key field for grouping results
  - `:cardinality` - :one or :many
  - `:type` - Query type (:partitioned, :count, :exists, :direct)
  - `:repo` - The Ecto repo module

  ## How It Works

  When loading associations, the batch key groups requests by:
  1. Same field and arguments
  2. Same parent queryable
  3. Same partition key (for result mapping)

  This ensures all parents requesting the same association are batched
  into a single query, with results mapped back via partition_key.

  ## Transparent Operation

  The partition_key is automatically extracted from Ecto association
  metadata - no schema modifications required.
  """

  @enforce_keys [
    :field,
    :args,
    :queryable,
    :partition_key,
    :cardinality,
    :type,
    :repo
  ]

  defstruct @enforce_keys ++ [force_custom_batch: false]

  @type query_type :: :partitioned | :count | :exists | :direct

  @type t :: %__MODULE__{
          field: atom(),
          args: map(),
          queryable: module(),
          partition_key: atom(),
          cardinality: :one | :many,
          type: query_type(),
          repo: module(),
          force_custom_batch: boolean()
        }

  @doc """
  Creates a BatchKey from a parent struct and loader key.

  Automatically extracts the partition_key from the association metadata.

  ## Parameters

  - `parent` - The parent struct (e.g., %User{})
  - `field` - The association field name
  - `args` - Arguments for the loader
  - `opts` - Options including :repo, :type, :force_custom_batch
  """
  def new(parent, field, args, opts \\ []) do
    parent_mod = parent.__struct__
    repo = Keyword.fetch!(opts, :repo)
    type = Keyword.get(opts, :type, :partitioned)
    force_custom_batch = Keyword.get(opts, :force_custom_batch, false)

    {partition_key, cardinality} = extract_association_info(parent_mod, field)

    %__MODULE__{
      field: field,
      args: args,
      queryable: parent_mod,
      partition_key: partition_key,
      cardinality: cardinality,
      type: type,
      repo: repo,
      force_custom_batch: force_custom_batch
    }
  end

  @doc """
  Extracts the partition key value from a parent struct.

  This is the value used to group results back to this specific parent.
  """
  def partition_value(%__MODULE__{partition_key: key}, parent) do
    Map.get(parent, key)
  end

  @doc """
  Extracts association metadata for a field on a module.

  Returns `{owner_key, cardinality}`.
  """
  def extract_association_info(module, field) do
    case module.__schema__(:association, field) do
      nil ->
        raise ArgumentError,
              "Association #{field} not found on #{inspect(module)}"

      %{owner_key: owner_key, cardinality: cardinality} ->
        {owner_key, cardinality}

      %{cardinality: cardinality} = assoc ->
        # For belongs_to, owner_key is typically :id
        owner_key = Map.get(assoc, :owner_key, :id)
        {owner_key, cardinality}
    end
  end
end
