defmodule Absinthe.Object.Test.RootMutationExample do
  use Absinthe.Object.RootMutation

  root_mutation_fields do
    field :echo, :string do
      arg :message, non_null(:string)
      resolve fn _, %{message: msg}, _ -> {:ok, msg} end
    end
  end
end
