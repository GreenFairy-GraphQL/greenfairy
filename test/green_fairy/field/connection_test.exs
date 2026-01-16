defmodule GreenFairy.Field.ConnectionTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Field.Connection

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

  describe "parse_connection_block/1" do
    test "handles nil" do
      assert {nil, nil, nil, nil} = Connection.parse_connection_block(nil)
    end

    test "parses block with only edge" do
      block = {:edge, [], [[do: {:field, [], [:extra, :string]}]]}

      {edge_block, connection_fields, _resolver, _aggregates} = Connection.parse_connection_block(block)

      assert edge_block == {:field, [], [:extra, :string]}
      assert connection_fields == nil
    end

    test "parses block with edge and other fields" do
      statements = [
        {:edge, [], [[do: {:field, [], [:extra, :string]}]]},
        {:field, [], [:total_count, :integer]}
      ]

      block = {:__block__, [], statements}

      {edge_block, connection_fields, _resolver, _aggregates} = Connection.parse_connection_block(block)

      assert edge_block == {:field, [], [:extra, :string]}
      assert connection_fields == {:__block__, [], [{:field, [], [:total_count, :integer]}]}
    end

    test "parses block with only connection fields (no edge)" do
      statements = [
        {:field, [], [:total_count, :integer]},
        {:field, [], [:average_score, :float]}
      ]

      block = {:__block__, [], statements}

      {edge_block, connection_fields, _resolver, _aggregates} = Connection.parse_connection_block(block)

      assert edge_block == nil
      assert connection_fields == {:__block__, [], statements}
    end

    test "parses single statement that is not edge" do
      single = {:field, [], [:total_count, :integer]}

      {edge_block, connection_fields, _resolver, _aggregates} = Connection.parse_connection_block(single)

      assert edge_block == nil
      assert connection_fields == single
    end

    test "handles multiple edges (takes first)" do
      # When there are multiple edge declarations, it takes the first one
      statements = [
        {:edge, [], [[do: {:field, [], [:first_extra, :string]}]]},
        {:edge, [], [[do: {:field, [], [:second_extra, :string]}]]}
      ]

      block = {:__block__, [], statements}

      {edge_block, connection_fields, _resolver, _aggregates} = Connection.parse_connection_block(block)

      assert edge_block == {:field, [], [:first_extra, :string]}
      assert connection_fields == nil
    end

    test "handles block with empty statements after filtering edges" do
      statements = [
        {:edge, [], [[do: {:field, [], [:extra, :string]}]]}
      ]

      block = {:__block__, [], statements}

      {edge_block, connection_fields, _resolver, _aggregates} = Connection.parse_connection_block(block)

      assert edge_block == {:field, [], [:extra, :string]}
      assert connection_fields == nil
    end
  end

  describe "connection inside type block" do
    # This tests that connections work inside type definitions,
    # which was previously broken due to nested object generation.

    defmodule FriendType do
      use GreenFairy.Type

      type "ConnectionFriend" do
        field :id, non_null(:id)
        field :name, :string
      end
    end

    defmodule UserWithFriendsType do
      use GreenFairy.Type

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
      import_types GreenFairy.BuiltIns.PageInfo

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
      definition = UserWithFriendsType.__green_fairy_definition__()
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
      assert result.edges == []
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
    defmodule MockItem do
      use Ecto.Schema

      schema "items" do
        field :value, :string
      end
    end

    defmodule MockRepo do
      def all(_query), do: [%{id: 1}, %{id: 2}, %{id: 3}]
      def aggregate(_query, :count, :id), do: 3
    end

    test "fetches all items and applies pagination" do
      import Ecto.Query
      query = from(i in MockItem, select: i)

      assert {:ok, result} = Connection.from_query(query, MockRepo, %{first: 2})

      assert length(result.edges) == 2
      assert Enum.at(result.edges, 0).node == %{id: 1}
      assert result.page_info.has_next_page == true
    end

    test "works with empty args" do
      import Ecto.Query
      query = from(i in MockItem, select: i)

      assert {:ok, result} = Connection.from_query(query, MockRepo, %{})

      assert length(result.edges) == 3
    end

    test "accepts custom cursor function" do
      import Ecto.Query
      query = from(i in MockItem, select: i)
      cursor_fn = fn item, _idx -> "item-#{item.id}" end

      assert {:ok, result} = Connection.from_query(query, MockRepo, %{}, cursor_fn: cursor_fn)

      assert Enum.at(result.edges, 0).cursor == "item-1"
    end

    test "supports deferred loading" do
      import Ecto.Query
      query = from(i in MockItem, select: i)

      assert {:ok, result} = Connection.from_query(query, MockRepo, %{}, deferred: true)

      # Deferred mode returns functions for count operations
      assert is_function(result._total_count_fn, 0)
      assert is_function(result._exists_fn, 0)
    end
  end

  describe "from_list/3 with deferred loading" do
    test "returns deferred functions when deferred: true" do
      items = [1, 2, 3]

      assert {:ok, result} = Connection.from_list(items, %{}, deferred: true)

      # Should have deferred functions
      assert is_function(result._total_count_fn, 0)
      assert is_function(result._exists_fn, 0)
      assert result._total_count_fn.() == 3
      assert result._exists_fn.() == true
    end

    test "returns eager values when deferred: false" do
      items = [1, 2, 3]

      assert {:ok, result} = Connection.from_list(items, %{}, deferred: false)

      # Should have eager values
      assert result.total_count == 3
      assert result.exists == true
    end

    test "defaults to eager loading (no deferred option)" do
      items = [1, 2, 3]

      assert {:ok, result} = Connection.from_list(items, %{})

      # Should have eager values
      assert result.total_count == 3
      assert result.exists == true
    end

    test "accepts custom total_count in eager mode" do
      items = [1, 2, 3]

      assert {:ok, result} = Connection.from_list(items, %{}, total_count: 100)

      assert result.total_count == 100
    end

    test "accepts custom total_count_fn in deferred mode" do
      items = [1, 2, 3]

      assert {:ok, result} = Connection.from_list(items, %{}, deferred: true, total_count_fn: fn -> 999 end)

      assert result._total_count_fn.() == 999
    end

    test "accepts custom exists_fn in deferred mode" do
      items = [1, 2, 3]

      assert {:ok, result} = Connection.from_list(items, %{}, deferred: true, exists_fn: fn -> false end)

      assert result._exists_fn.() == false
    end

    test "includes nodes list (GitHub-style shortcut)" do
      items = [%{id: 1}, %{id: 2}, %{id: 3}]

      assert {:ok, result} = Connection.from_list(items, %{})

      assert result.nodes == items
    end

    test "includes aggregates when provided" do
      items = [1, 2, 3]
      aggregates = %{sum: %{amount: 100}}

      assert {:ok, result} = Connection.from_list(items, %{}, aggregates: aggregates)

      assert result.sum == %{amount: 100}
    end
  end

  describe "parse_connection_block/1 with resolve and loader" do
    test "parses block with resolve" do
      statements = [
        {:resolve, [], [fn _, _ -> nil end]}
      ]
      block = {:__block__, [], statements}

      {_edge_block, _connection_fields, resolver, _aggregates} = Connection.parse_connection_block(block)

      assert {:resolve, [], _} = resolver
    end

    test "parses single resolve statement" do
      block = {:resolve, [], [fn _, _ -> nil end]}

      {edge_block, connection_fields, resolver, aggregates} = Connection.parse_connection_block(block)

      assert edge_block == nil
      assert connection_fields == nil
      assert {:resolve, [], _} = resolver
      assert aggregates == nil
    end

    test "parses single loader statement" do
      block = {:loader, [], [fn _, _ -> nil end]}

      {edge_block, connection_fields, resolver, aggregates} = Connection.parse_connection_block(block)

      assert edge_block == nil
      assert connection_fields == nil
      assert {:loader, [], _} = resolver
      assert aggregates == nil
    end

    test "parses block with loader" do
      statements = [
        {:loader, [], [fn _, _ -> nil end]}
      ]
      block = {:__block__, [], statements}

      {_edge_block, _connection_fields, resolver, _aggregates} = Connection.parse_connection_block(block)

      assert {:loader, [], _} = resolver
    end

    test "parses block with aggregate" do
      aggregate_block = {:__block__, [], [{:sum, [], [[:amount]]}]}
      statements = [
        {:aggregate, [], [[do: aggregate_block]]}
      ]
      block = {:__block__, [], statements}

      {_edge_block, _connection_fields, _resolver, aggregates} = Connection.parse_connection_block(block)

      assert aggregates.sum == [:amount]
    end

    test "parses edge with opts inside block" do
      # Edge with opts (second format) - only works inside a block
      statements = [
        {:edge, [], [[], [do: {:field, [], [:extra, :string]}]]}
      ]
      block = {:__block__, [], statements}

      {edge_block, _connection_fields, _resolver, _aggregates} = Connection.parse_connection_block(block)

      assert edge_block == {:field, [], [:extra, :string]}
    end
  end

  describe "generate_connection_types/1" do
    test "generates edge and connection types" do
      conn = %{
        field_name: :friends,
        type_identifier: :user,
        connection_name: :friends_connection,
        edge_name: :friends_edge,
        edge_block: nil,
        connection_fields: nil,
        aggregates: nil
      }

      types = Connection.generate_connection_types([conn])

      # Should generate 2 types: edge + connection
      assert length(types) == 2
    end

    test "generates aggregate types when aggregates present" do
      conn = %{
        field_name: :engagements,
        type_identifier: :engagement,
        connection_name: :engagements_connection,
        edge_name: :engagements_edge,
        edge_block: nil,
        connection_fields: nil,
        aggregates: %{sum: [:amount], avg: [], min: [], max: []}
      }

      types = Connection.generate_connection_types([conn])

      # Should generate edge + connection + aggregate main + aggregate sum
      assert length(types) >= 3
    end
  end
end
