defmodule Absinthe.Object.Dataloader.PartitionFields do
  @moduledoc """
  Optional virtual fields for advanced partitioned query features.

  **Most users don't need this module.** The partition system works
  transparently without schema modifications. These virtual fields
  are only needed for advanced use cases like:

  - Windowed queries with row numbers
  - Custom post-processing that needs partition metadata

  ## When You DON'T Need This

  For standard nested association filtering:

      # This works without any schema changes
      users(where: {organization: {name: {_eq: "Acme"}}}) {
        id
        name
      }

  The `partition_id_` is added dynamically via `select_merge` at query
  time - no virtual field definition needed.

  ## When You DO Need This

  Only if you're using:

  1. **Windowed queries** - PostgreSQL window functions for partitioned
     pagination (e.g., "first 5 posts per user")

  2. **Custom loaders** - That need to access partition metadata after
     the query completes

  ## Usage

  Add to your Ecto schema:

      defmodule MyApp.Post do
        use Ecto.Schema
        import Absinthe.Object.Dataloader.PartitionFields

        schema "posts" do
          field :title, :string
          field :body, :string
          belongs_to :user, MyApp.User

          # Add virtual partition fields
          partition_fields()

          timestamps()
        end
      end

  This adds two virtual fields:
  - `partition_id_` - Groups results by parent record
  - `partition_row_` - Row number within partition (for windowed queries)
  """

  @doc """
  Adds virtual partition fields to an Ecto schema.

  These fields are NOT persisted to the database. They are populated
  at query time via `select_merge` and used internally for result
  grouping and windowed pagination.
  """
  defmacro partition_fields do
    quote do
      field(:partition_id_, :binary_id, virtual: true)
      field(:partition_row_, :integer, virtual: true)
    end
  end
end
