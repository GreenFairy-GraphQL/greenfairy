defmodule Absinthe.Object.Test.SchemaWithRootsExample do
  use Absinthe.Object.Schema,
    discover: [],
    query: Absinthe.Object.Test.RootQueryExample,
    mutation: Absinthe.Object.Test.RootMutationExample
end
