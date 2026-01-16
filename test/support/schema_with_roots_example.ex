defmodule GreenFairy.Test.SchemaWithRootsExample do
  use GreenFairy.Schema,
    query: GreenFairy.Test.RootQueryExample,
    mutation: GreenFairy.Test.RootMutationExample
end
