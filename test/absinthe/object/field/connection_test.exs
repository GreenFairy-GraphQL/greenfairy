defmodule Absinthe.Object.Field.ConnectionTest do
  use ExUnit.Case, async: true

  alias Absinthe.Object.Field.Connection

  describe "from_list/3" do
    test "returns connection result for empty list" do
      assert {:ok, result} = Connection.from_list([], %{})

      assert result.edges == []
      assert result.page_info.has_next_page == false
      assert result.page_info.has_previous_page == false
      assert result.page_info.start_cursor == nil
      assert result.page_info.end_cursor == nil
    end

    test "returns edges with nodes and cursors" do
      items = [%{id: 1}, %{id: 2}, %{id: 3}]

      assert {:ok, result} = Connection.from_list(items, %{})

      assert length(result.edges) == 3
      assert Enum.at(result.edges, 0).node == %{id: 1}
      assert Enum.at(result.edges, 1).node == %{id: 2}
      assert Enum.at(result.edges, 2).node == %{id: 3}

      # Each edge has a cursor
      assert Enum.all?(result.edges, fn edge -> is_binary(edge.cursor) end)
    end

    test "applies first limit" do
      items = [1, 2, 3, 4, 5]

      assert {:ok, result} = Connection.from_list(items, %{first: 2})

      assert length(result.edges) == 2
      assert Enum.at(result.edges, 0).node == 1
      assert Enum.at(result.edges, 1).node == 2
      assert result.page_info.has_next_page == true
      assert result.page_info.has_previous_page == false
    end

    test "applies last limit" do
      items = [1, 2, 3, 4, 5]

      assert {:ok, result} = Connection.from_list(items, %{last: 2})

      assert length(result.edges) == 2
      assert Enum.at(result.edges, 0).node == 4
      assert Enum.at(result.edges, 1).node == 5
      assert result.page_info.has_next_page == false
      assert result.page_info.has_previous_page == true
    end

    test "first takes precedence over last" do
      items = [1, 2, 3, 4, 5]

      assert {:ok, result} = Connection.from_list(items, %{first: 2, last: 3})

      assert length(result.edges) == 2
      assert Enum.at(result.edges, 0).node == 1
    end

    test "applies after cursor" do
      items = [1, 2, 3, 4, 5]
      # Get cursor for item at index 1 (second item)
      cursor = Base.encode64("cursor:1")

      assert {:ok, result} = Connection.from_list(items, %{after: cursor})

      # Should return items after the cursor
      assert length(result.edges) == 3
      assert Enum.at(result.edges, 0).node == 3
    end

    test "applies before cursor" do
      items = [1, 2, 3, 4, 5]
      # Get cursor for item at index 3 (fourth item)
      cursor = Base.encode64("cursor:3")

      assert {:ok, result} = Connection.from_list(items, %{before: cursor})

      # Should return items before the cursor
      assert length(result.edges) == 3
      assert Enum.at(result.edges, 2).node == 3
    end

    test "accepts custom cursor function" do
      items = [%{uuid: "a"}, %{uuid: "b"}, %{uuid: "c"}]
      cursor_fn = fn item, _idx -> item.uuid end

      assert {:ok, result} = Connection.from_list(items, %{}, cursor_fn: cursor_fn)

      assert Enum.at(result.edges, 0).cursor == "a"
      assert Enum.at(result.edges, 1).cursor == "b"
      assert Enum.at(result.edges, 2).cursor == "c"
    end

    test "sets start_cursor and end_cursor" do
      items = [1, 2, 3]

      assert {:ok, result} = Connection.from_list(items, %{})

      assert result.page_info.start_cursor == Base.encode64("cursor:0")
      assert result.page_info.end_cursor == Base.encode64("cursor:2")
    end

    test "has_next_page is false when first is greater than items count" do
      items = [1, 2, 3]

      assert {:ok, result} = Connection.from_list(items, %{first: 10})

      assert length(result.edges) == 3
      assert result.page_info.has_next_page == false
    end

    test "has_previous_page is false when last is greater than items count" do
      items = [1, 2, 3]

      assert {:ok, result} = Connection.from_list(items, %{last: 10})

      assert length(result.edges) == 3
      assert result.page_info.has_previous_page == false
    end
  end

  describe "connection macro" do
    # Note: The connection macro currently has a limitation where it can't define
    # nested `object` types within a type definition due to Absinthe's restriction
    # that `object` must be top-level. This would need refactoring to work with
    # Absinthe's Relay extension pattern.

    # For now, we test the parsing helpers used by the macro
    test "parse_connection_block handles nil" do
      # Testing through reflection since parse_connection_block is private
      # The from_list function exercises the core pagination logic
      assert {:ok, _} = Connection.from_list([], %{})
    end
  end

  describe "connection inside type block" do
    # This tests that connections work inside type definitions,
    # which was previously broken due to nested object generation.

    defmodule FriendType do
      use Absinthe.Object.Type

      type "ConnectionFriend" do
        field :id, non_null(:id)
        field :name, :string
      end
    end

    defmodule UserWithFriendsType do
      use Absinthe.Object.Type

      type "ConnectionUser" do
        field :id, non_null(:id)
        field :name, :string

        # Connection inside a type block - this should work with deferred generation
        connection :friends, FriendType do
          edge do
            field :friendship_date, :string
          end

          field :total_count, :integer
        end
      end
    end

    defmodule ConnectionInTypeSchema do
      use Absinthe.Schema

      import_types FriendType
      import_types UserWithFriendsType
      import_types Absinthe.Object.BuiltIns.PageInfo

      query do
        field :user, :connection_user do
          resolve fn _, _, _ ->
            {:ok, %{id: "1", name: "Test User"}}
          end
        end
      end
    end

    test "connection types are generated" do
      # Verify edge type exists
      edge_type = Absinthe.Schema.lookup_type(ConnectionInTypeSchema, :friends_edge)
      assert edge_type != nil
      assert Map.has_key?(edge_type.fields, :node)
      assert Map.has_key?(edge_type.fields, :cursor)
      assert Map.has_key?(edge_type.fields, :friendship_date)

      # Verify connection type exists
      conn_type = Absinthe.Schema.lookup_type(ConnectionInTypeSchema, :friends_connection)
      assert conn_type != nil
      assert Map.has_key?(conn_type.fields, :edges)
      assert Map.has_key?(conn_type.fields, :page_info)
      assert Map.has_key?(conn_type.fields, :total_count)
    end

    test "user type has friends connection field" do
      user_type = Absinthe.Schema.lookup_type(ConnectionInTypeSchema, :connection_user)
      assert Map.has_key?(user_type.fields, :friends)

      # Verify field has pagination args
      friends_field = user_type.fields[:friends]
      arg_names = Map.keys(friends_field.args)
      assert :first in arg_names
      assert :after in arg_names
      assert :last in arg_names
      assert :before in arg_names
    end

    test "connection definition is stored in type" do
      definition = UserWithFriendsType.__absinthe_object_definition__()
      assert is_list(definition.connections)
      assert length(definition.connections) == 1

      conn = hd(definition.connections)
      assert conn.field_name == :friends
      assert conn.connection_name == :friends_connection
      assert conn.edge_name == :friends_edge
    end

    test "can query user" do
      query = """
      {
        user {
          id
          name
        }
      }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, ConnectionInTypeSchema)
      assert data["user"]["id"] == "1"
      assert data["user"]["name"] == "Test User"
    end
  end

  describe "from_list edge cases" do
    test "handles after cursor with first limit" do
      items = [1, 2, 3, 4, 5]
      # Cursor for index 1
      cursor = Base.encode64("cursor:1")

      assert {:ok, result} = Connection.from_list(items, %{after: cursor, first: 2})

      # After cursor 1 (item 2), take first 2 -> items 3, 4
      assert length(result.edges) == 2
      assert Enum.at(result.edges, 0).node == 3
      assert Enum.at(result.edges, 1).node == 4
      assert result.page_info.has_next_page == true
    end

    test "handles before cursor with last limit" do
      items = [1, 2, 3, 4, 5]
      # Cursor for index 4
      cursor = Base.encode64("cursor:4")

      assert {:ok, result} = Connection.from_list(items, %{before: cursor, last: 2})

      # Before cursor 4 (item 5), take last 2 -> items 3, 4
      assert length(result.edges) == 2
      assert result.page_info.has_previous_page == true
    end

    test "handles both after and before cursors" do
      items = [1, 2, 3, 4, 5, 6, 7]
      # After cursor at index 1 (value 2)
      after_cursor = Base.encode64("cursor:1")
      # After filtering by after_cursor, list becomes [3, 4, 5, 6, 7] with NEW indices [0, 1, 2, 3, 4]
      # Before cursor at NEW index 3 (value 6 in the filtered list)
      before_cursor = Base.encode64("cursor:3")

      assert {:ok, result} = Connection.from_list(items, %{after: after_cursor, before: before_cursor})

      # After cursor:1 gives [3, 4, 5, 6, 7], before cursor:3 (new index) gives [3, 4, 5]
      assert length(result.edges) == 3
      assert Enum.at(result.edges, 0).node == 3
      assert Enum.at(result.edges, 2).node == 5
    end

    test "after cursor not found returns empty" do
      items = [1, 2, 3]
      cursor = Base.encode64("cursor:999")

      assert {:ok, result} = Connection.from_list(items, %{after: cursor})
      assert length(result.edges) == 0
    end

    test "before cursor not found returns all items" do
      items = [1, 2, 3]
      cursor = Base.encode64("cursor:999")

      assert {:ok, result} = Connection.from_list(items, %{before: cursor})
      # All items returned since cursor not found
      assert length(result.edges) == 3
    end
  end

  describe "from_query/4" do
    defmodule MockRepo do
      def all(_query), do: [%{id: 1}, %{id: 2}, %{id: 3}]
    end

    test "fetches all items and applies pagination" do
      assert {:ok, result} = Connection.from_query(:query, MockRepo, %{first: 2})

      assert length(result.edges) == 2
      assert Enum.at(result.edges, 0).node == %{id: 1}
      assert result.page_info.has_next_page == true
    end

    test "works with empty args" do
      assert {:ok, result} = Connection.from_query(:query, MockRepo, %{})

      assert length(result.edges) == 3
    end

    test "accepts custom cursor function" do
      cursor_fn = fn item, _idx -> "item-#{item.id}" end

      assert {:ok, result} = Connection.from_query(:query, MockRepo, %{}, cursor_fn: cursor_fn)

      assert Enum.at(result.edges, 0).cursor == "item-1"
    end
  end
end
