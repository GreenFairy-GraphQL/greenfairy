defmodule GreenFairy.UnionTest do
  use ExUnit.Case, async: true

  defmodule TestUser do
    defstruct [:id, :email, :name]
  end

  defmodule TestPost do
    defstruct [:id, :title, :body]
  end

  defmodule UserType do
    use Absinthe.Schema.Notation

    object :search_user do
      field :id, non_null(:id)
      field :email, :string
      field :name, :string
    end
  end

  defmodule PostType do
    use Absinthe.Schema.Notation

    object :search_post do
      field :id, non_null(:id)
      field :title, :string
      field :body, :string
    end
  end

  defmodule SearchResult do
    use GreenFairy.Union

    union "SearchResult" do
      types [:search_user, :search_post]

      resolve_type fn
        %TestUser{}, _ -> :search_user
        %TestPost{}, _ -> :search_post
        _, _ -> nil
      end
    end
  end

  defmodule TestSchema do
    use Absinthe.Schema

    import_types UserType
    import_types PostType
    import_types SearchResult

    query do
      field :search, list_of(:search_result) do
        arg :query, non_null(:string)

        resolve fn _, %{query: _query}, _ ->
          {:ok,
           [
             %TestUser{id: "1", email: "user@example.com", name: "John"},
             %TestPost{id: "2", title: "Hello", body: "World"}
           ]}
        end
      end
    end
  end

  describe "union/2 macro" do
    test "defines __green_fairy_definition__/0" do
      definition = SearchResult.__green_fairy_definition__()

      assert definition.kind == :union
      assert definition.name == "SearchResult"
      assert definition.identifier == :search_result
    end

    test "defines __green_fairy_identifier__/0" do
      assert SearchResult.__green_fairy_identifier__() == :search_result
    end

    test "defines __green_fairy_kind__/0" do
      assert SearchResult.__green_fairy_kind__() == :union
    end

    test "defines __green_fairy_referenced_types__/0 with member types" do
      refs = SearchResult.__green_fairy_referenced_types__()
      assert is_list(refs)
      assert :search_user in refs
      assert :search_post in refs
    end

    test "definition has correct name" do
      definition = SearchResult.__green_fairy_definition__()
      assert definition.name == "SearchResult"
    end
  end

  describe "Absinthe integration" do
    test "generates valid Absinthe union type" do
      type = Absinthe.Schema.lookup_type(TestSchema, :search_result)

      assert type != nil
      assert type.name == "SearchResult"
      assert type.identifier == :search_result
    end

    test "union has correct member types" do
      type = Absinthe.Schema.lookup_type(TestSchema, :search_result)

      assert :search_user in type.types
      assert :search_post in type.types
    end

    test "executes query with union type and fragments" do
      query = """
      {
        search(query: "test") {
          ... on SearchUser {
            id
            email
            name
          }
          ... on SearchPost {
            id
            title
            body
          }
        }
      }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, TestSchema)

      results = data["search"]
      assert length(results) == 2

      [user, post] = results
      assert user["id"] == "1"
      assert user["email"] == "user@example.com"
      assert user["name"] == "John"

      assert post["id"] == "2"
      assert post["title"] == "Hello"
      assert post["body"] == "World"
    end
  end
end
