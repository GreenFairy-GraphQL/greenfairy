defmodule GreenFairy.GraphDiscoveryTest do
  use ExUnit.Case, async: false  # Can't be async because TypeRegistry is shared

  alias GreenFairy.TypeRegistry

  setup do
    # Clear registry before each test
    TypeRegistry.clear()
    :ok
  end

  describe "TypeRegistry" do
    test "registers and looks up type identifiers" do
      defmodule Registry.TestUser do
        use GreenFairy.Type

        type "User" do
          field :id, non_null(:id)
          field :name, :string
        end
      end

      # Type should be registered automatically
      assert TypeRegistry.lookup_module(:user) == Registry.TestUser
    end

    test "returns nil for unknown identifiers" do
      assert TypeRegistry.lookup_module(:unknown_type_xyz) == nil
    end
  end

  describe "Type reference tracking" do
    test "tracks direct field type references" do
      defmodule Tracking.UserWithPosts do
        use GreenFairy.Type

        type "User" do
          field :id, non_null(:id)
          field :posts, list_of(:post)
          field :best_friend, :user
        end
      end

      refs = Tracking.UserWithPosts.__green_fairy_referenced_types__()
      assert :post in refs
      assert :user in refs
    end

    test "does not track built-in scalar types" do
      defmodule Tracking.UserWithScalars do
        use GreenFairy.Type

        type "User" do
          field :id, non_null(:id)
          field :name, :string
          field :age, :integer
          field :score, :float
          field :active, :boolean
        end
      end

      refs = Tracking.UserWithScalars.__green_fairy_referenced_types__()
      # Should not include built-in scalars
      refute :id in refs
      refute :string in refs
      refute :integer in refs
      refute :float in refs
      refute :boolean in refs
    end

    test "unwraps non_null and list_of wrappers" do
      defmodule Tracking.UserWithWrappedTypes do
        use GreenFairy.Type

        type "User" do
          field :id, non_null(:id)
          field :posts, non_null(list_of(non_null(:post)))
          field :comments, list_of(:comment)
        end
      end

      refs = Tracking.UserWithWrappedTypes.__green_fairy_referenced_types__()
      assert :post in refs
      assert :comment in refs
    end
  end

  describe "Union reference tracking" do
    test "tracks union member types" do
      defmodule Unions.SearchResult do
        use GreenFairy.Union

        union "SearchResult" do
          types [:user_result, :post_result, :comment_result]

          resolve_type fn
            %{__struct__: _}, _ -> :user_result
          end
        end
      end

      refs = Unions.SearchResult.__green_fairy_referenced_types__()
      assert :user_result in refs
      assert :post_result in refs
      assert :comment_result in refs
    end
  end

  describe "Input reference tracking" do
    test "tracks input field type references" do
      defmodule Inputs.CreatePostInput do
        use GreenFairy.Input

        input "CreatePostInput" do
          field :title, non_null(:string)
          field :body, :string
          field :author_id, :id
          field :metadata, :post_metadata_input
        end
      end

      refs = Inputs.CreatePostInput.__green_fairy_referenced_types__()
      assert :post_metadata_input in refs
      refute :string in refs
      refute :id in refs
    end
  end

  describe "Graph-based discovery" do
    test "discovers types reachable from query root" do
      # Define a type graph:
      # Query -> GraphUser -> GraphPost -> GraphComment

      defmodule Graph1.Comment do
        use GreenFairy.Type

        type "Comment1" do
          field :id, non_null(:id)
          field :body, :string
        end
      end

      defmodule Graph1.Post do
        use GreenFairy.Type

        type "Post1" do
          field :id, non_null(:id)
          field :title, :string
          field :comments, list_of(:comment1)
        end
      end

      defmodule Graph1.User do
        use GreenFairy.Type

        type "User1" do
          field :id, non_null(:id)
          field :name, :string
          field :posts, list_of(:post1)
        end
      end

      defmodule Graph1.Query do
        use GreenFairy.Query

        queries do
          field :current_user, :user1 do
            resolve fn _, _, _ -> {:ok, nil} end
          end
        end
      end

      defmodule Graph1.Schema do
        use GreenFairy.Schema,
          query: Graph1.Query
      end

      # Verify all types were discovered
      discovered = Graph1.Schema.__green_fairy_discovered__()
      discovered_modules = Enum.map(discovered, & &1)

      assert Graph1.Query in discovered_modules
      assert Graph1.User in discovered_modules
      assert Graph1.Post in discovered_modules
      assert Graph1.Comment in discovered_modules
    end
  end
end
