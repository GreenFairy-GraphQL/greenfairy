defmodule GreenFairy.AutoResolveTypeTest do
  use ExUnit.Case, async: false

  alias GreenFairy.Registry

  # Ensure modules are loaded and registered before tests run
  # This is needed because other tests may clear the registry
  setup do
    # Re-register the types since other tests may have cleared the registry
    Registry.register(TestUser, :auto_user, AutoNodeInterface)
    Registry.register(TestPost, :auto_post, AutoNodeInterface)
    :ok
  end

  defmodule TestUser do
    defstruct [:id, :email, :name]
  end

  defmodule TestPost do
    defstruct [:id, :title, :body]
  end

  # Interface WITHOUT manual resolve_type - should auto-generate
  defmodule AutoNodeInterface do
    use GreenFairy.Interface

    interface "AutoNode" do
      field :id, non_null(:id)
      # No resolve_type here - should be auto-generated!
    end
  end

  # Type that implements the interface with struct:
  defmodule AutoUserType do
    use GreenFairy.Type

    type "AutoUser", struct: TestUser do
      implements(AutoNodeInterface)

      field :id, non_null(:id)
      field :email, :string
      field :name, :string
    end
  end

  defmodule AutoPostType do
    use GreenFairy.Type

    type "AutoPost", struct: TestPost do
      implements(AutoNodeInterface)

      field :id, non_null(:id)
      field :title, :string
      field :body, :string
    end
  end

  defmodule TestSchema do
    use Absinthe.Schema

    import_types AutoNodeInterface
    import_types AutoUserType
    import_types AutoPostType

    query do
      field :node, :auto_node do
        arg :id, non_null(:id)
        arg :type, non_null(:string)

        resolve fn _, %{id: id, type: type}, _ ->
          case type do
            "user" -> {:ok, %TestUser{id: id, email: "test@example.com", name: "Test User"}}
            "post" -> {:ok, %TestPost{id: id, title: "Test Post", body: "Content"}}
            _ -> {:ok, nil}
          end
        end
      end
    end
  end

  describe "auto resolve_type" do
    test "interface auto-generates resolve_type from registry" do
      # Query for a user through the interface
      query = """
      {
        node(id: "123", type: "user") {
          id
          ... on AutoUser {
            email
            name
          }
        }
      }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, TestSchema)
      assert data["node"]["id"] == "123"
      assert data["node"]["email"] == "test@example.com"
      assert data["node"]["name"] == "Test User"
    end

    test "resolves different types correctly" do
      # Query for a post through the interface
      query = """
      {
        node(id: "456", type: "post") {
          id
          ... on AutoPost {
            title
            body
          }
        }
      }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, TestSchema)
      assert data["node"]["id"] == "456"
      assert data["node"]["title"] == "Test Post"
      assert data["node"]["body"] == "Content"
    end

    test "registry contains correct mappings" do
      implementations = GreenFairy.Registry.implementations(AutoNodeInterface)

      assert {TestUser, :auto_user} in implementations
      assert {TestPost, :auto_post} in implementations
    end
  end
end
