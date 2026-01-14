defmodule Absinthe.Object.BuiltIns.Timestampable do
  @moduledoc """
  Built-in Timestampable interface for types with timestamps.

  Provides standard timestamp fields that match Ecto's `timestamps()` macro.

  ## Usage

      defmodule MyApp.GraphQL.Types.Post do
        use Absinthe.Object.Type

        type "Post", struct: MyApp.Post do
          implements Absinthe.Object.BuiltIns.Timestampable

          field :inserted_at, non_null(:datetime)
          field :updated_at, non_null(:datetime)
          field :title, :string
          field :body, :string
        end
      end

  Note: You'll need to define a :datetime scalar for this to work.
  """

  use Absinthe.Object.Interface

  interface "Timestampable" do
    @desc "When the record was created (ISO8601 string or custom datetime scalar)"
    field :inserted_at, non_null(:string)

    @desc "When the record was last updated (ISO8601 string or custom datetime scalar)"
    field :updated_at, non_null(:string)

    resolve_type fn
      _, _ -> nil
    end
  end
end
