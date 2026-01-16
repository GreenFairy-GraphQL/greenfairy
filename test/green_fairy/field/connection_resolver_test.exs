defmodule GreenFairy.Field.ConnectionResolverTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Field.ConnectionResolver

  defmodule TestSchema do
    use Ecto.Schema

    schema "posts" do
      field :title, :string
      field :user_id, :integer
      field :content, :string
    end
  end

  defmodule UserSchema do
    use Ecto.Schema

    schema "users" do
      field :name, :string
    end
  end

  defmodule MockRepo do
    def all(query) do
      # Return empty list for tests
      _ = query
      []
    end
  end

  describe "resolve_association_connection/4" do
    test "returns connection result when all options are provided" do
      parent = %{id: 1}
      args = %{first: 10}
      resolution = %{context: %{}}
      opts = [repo: MockRepo, related_key: :user_id, queryable: TestSchema]

      result = ConnectionResolver.resolve_association_connection(parent, args, resolution, opts)

      # Returns a connection result
      assert {:ok, connection} = result
      assert is_map(connection)
      assert Map.has_key?(connection, :nodes)
      assert Map.has_key?(connection, :edges)
      assert Map.has_key?(connection, :page_info)
    end

    test "gets repo from context when not in opts" do
      parent = %{id: 1}
      args = %{first: 10}
      resolution = %{context: %{repo: MockRepo}}
      opts = [related_key: :user_id, queryable: TestSchema]

      result = ConnectionResolver.resolve_association_connection(parent, args, resolution, opts)

      assert {:ok, _connection} = result
    end

    test "gets repo from current_repo in context" do
      parent = %{id: 1}
      args = %{first: 10}
      resolution = %{context: %{current_repo: MockRepo}}
      opts = [related_key: :user_id, queryable: TestSchema]

      result = ConnectionResolver.resolve_association_connection(parent, args, resolution, opts)

      assert {:ok, _connection} = result
    end

    test "uses custom owner_key when provided" do
      parent = %{custom_id: 123, id: 1}
      args = %{first: 10}
      resolution = %{context: %{}}
      opts = [
        repo: MockRepo,
        related_key: :user_id,
        queryable: TestSchema,
        owner_key: :custom_id
      ]

      result = ConnectionResolver.resolve_association_connection(parent, args, resolution, opts)

      assert {:ok, _connection} = result
    end

    test "returns empty connection when no items match" do
      parent = %{id: 999}
      args = %{first: 10}
      resolution = %{context: %{}}
      opts = [repo: MockRepo, related_key: :user_id, queryable: TestSchema]

      {:ok, connection} = ConnectionResolver.resolve_association_connection(parent, args, resolution, opts)

      assert connection.nodes == []
      assert connection.edges == []
    end
  end

  describe "batch_resolve_association_connection/4" do
    test "creates map with parent as key" do
      parent1 = %{id: 1}
      parent2 = %{id: 2}
      parents = [parent1, parent2]
      args = %{first: 10}
      resolution = %{context: %{}}
      opts = [repo: MockRepo, related_key: :user_id, queryable: TestSchema]

      result = ConnectionResolver.batch_resolve_association_connection(parents, args, resolution, opts)

      # Should return a map
      assert is_map(result)

      # Each parent should have a result
      assert Map.has_key?(result, parent1)
      assert Map.has_key?(result, parent2)
    end

    test "returns empty connection for parents with no items" do
      parent = %{id: 999}
      parents = [parent]
      args = %{first: 10}
      resolution = %{context: %{}}
      opts = [repo: MockRepo, related_key: :user_id, queryable: TestSchema]

      result = ConnectionResolver.batch_resolve_association_connection(parents, args, resolution, opts)

      assert {:ok, connection} = result[parent]
      assert connection.nodes == []
      assert connection.edges == []
      assert connection.total_count == 0
      assert connection.exists == false
    end

    test "uses custom owner_key when provided" do
      parent = %{custom_id: 123, id: 1}
      parents = [parent]
      args = %{first: 10}
      resolution = %{context: %{}}
      opts = [
        repo: MockRepo,
        related_key: :user_id,
        queryable: TestSchema,
        owner_key: :custom_id
      ]

      result = ConnectionResolver.batch_resolve_association_connection(parents, args, resolution, opts)

      # Should work without error
      assert is_map(result)
      assert Map.has_key?(result, parent)
    end

    test "gets repo from context" do
      parent = %{id: 1}
      parents = [parent]
      args = %{first: 10}
      resolution = %{context: %{repo: MockRepo}}
      opts = [related_key: :user_id, queryable: TestSchema]

      result = ConnectionResolver.batch_resolve_association_connection(parents, args, resolution, opts)

      assert is_map(result)
      assert Map.has_key?(result, parent)
    end
  end

  describe "apply_cql_where/3 (via resolve_association_connection)" do
    test "applies where filter when provided" do
      parent = %{id: 1}
      args = %{first: 10, where: %{title: %{_eq: "test"}}}
      resolution = %{context: %{}}
      opts = [
        repo: MockRepo,
        related_key: :user_id,
        queryable: TestSchema,
        type_module: nil
      ]

      # Should not crash when where is provided
      result = ConnectionResolver.resolve_association_connection(parent, args, resolution, opts)

      assert is_tuple(result)
    end

    test "ignores nil where filter" do
      parent = %{id: 1}
      args = %{first: 10, where: nil}
      resolution = %{context: %{}}
      opts = [
        repo: MockRepo,
        related_key: :user_id,
        queryable: TestSchema
      ]

      result = ConnectionResolver.resolve_association_connection(parent, args, resolution, opts)

      assert is_tuple(result)
    end
  end

  describe "apply_cql_order_by/3 (via resolve_association_connection)" do
    test "applies order_by when provided as list" do
      parent = %{id: 1}
      args = %{first: 10, order_by: [%{field: :title, direction: :asc}]}
      resolution = %{context: %{}}
      opts = [
        repo: MockRepo,
        related_key: :user_id,
        queryable: TestSchema,
        type_module: nil
      ]

      result = ConnectionResolver.resolve_association_connection(parent, args, resolution, opts)

      assert is_tuple(result)
    end

    test "ignores nil order_by" do
      parent = %{id: 1}
      args = %{first: 10, order_by: nil}
      resolution = %{context: %{}}
      opts = [
        repo: MockRepo,
        related_key: :user_id,
        queryable: TestSchema
      ]

      result = ConnectionResolver.resolve_association_connection(parent, args, resolution, opts)

      assert is_tuple(result)
    end

    test "ignores non-list order_by" do
      parent = %{id: 1}
      args = %{first: 10, order_by: "invalid"}
      resolution = %{context: %{}}
      opts = [
        repo: MockRepo,
        related_key: :user_id,
        queryable: TestSchema
      ]

      result = ConnectionResolver.resolve_association_connection(parent, args, resolution, opts)

      assert is_tuple(result)
    end
  end
end
