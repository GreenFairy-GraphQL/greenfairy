defmodule GreenFairy.CQLIntegrationTest do
  use ExUnit.Case, async: false

  defmodule TestUser do
    defstruct [:id, :name, :email, :age]

    def __schema__(:source), do: "users"
    def __schema__(:prefix), do: nil
    def __schema__(:fields), do: [:id, :name, :email, :age]
    def __schema__(:primary_key), do: [:id]
    def __schema__(:type, :id), do: :id
    def __schema__(:type, :name), do: :string
    def __schema__(:type, :email), do: :string
    def __schema__(:type, :age), do: :integer
    def __schema__(:associations), do: []
    def __schema__(:embeds), do: []
    def __schema__(:association, _field), do: nil
  end

  defmodule TestUserType do
    use GreenFairy.Type

    alias GreenFairy.CQLIntegrationTest.TestUser

    type "User", struct: TestUser do
      use GreenFairy.CQL

      field :id, non_null(:id)
      field :name, :string
      field :email, :string
      field :age, :integer
    end
  end

  describe "CQL as core feature" do

    test "types with struct automatically get CQL functions" do
      assert function_exported?(TestUserType, :__cql_filter_input_identifier__, 0)
      assert function_exported?(TestUserType, :__cql_order_input_identifier__, 0)
      assert function_exported?(TestUserType, :__cql_filterable_fields__, 0)
      assert function_exported?(TestUserType, :__cql_orderable_fields__, 0)
    end

    test "CQL filter input identifier is generated" do
      assert TestUserType.__cql_filter_input_identifier__() == :cql_filter_user_input
    end

    test "CQL order input identifier is generated" do
      assert TestUserType.__cql_order_input_identifier__() == :cql_order_user_input
    end

    test "CQL filterable fields are detected" do
      fields = TestUserType.__cql_filterable_fields__()
      assert :id in fields
      assert :name in fields
      assert :email in fields
      assert :age in fields
    end

    test "CQL orderable fields match filterable fields by default" do
      filterable = TestUserType.__cql_filterable_fields__()
      orderable = TestUserType.__cql_orderable_fields__()
      assert filterable == orderable
    end
  end

  describe "Custom filters" do
    defmodule TestPost do
      defstruct [:id, :title, :first_name, :last_name]

      def __schema__(:source), do: "posts"
      def __schema__(:prefix), do: nil
      def __schema__(:fields), do: [:id, :title, :first_name, :last_name]
      def __schema__(:primary_key), do: [:id]
      def __schema__(:type, :id), do: :id
      def __schema__(:type, :title), do: :string
      def __schema__(:type, :first_name), do: :string
      def __schema__(:type, :last_name), do: :string
      def __schema__(:associations), do: []
      def __schema__(:embeds), do: []
    end

    defmodule TestPostType do
      use GreenFairy.Type
      import Ecto.Query

      type "Post", struct: TestPost do
        field :id, non_null(:id)
        field :title, :string

        # Custom filter for computed field
        custom_filter :full_name, [:_eq, :_ilike], fn query, op, value ->
          case op do
            :_eq ->
              from(p in query,
                where: fragment("concat(?, ' ', ?)", p.first_name, p.last_name) == ^value
              )

            :_ilike ->
              from(p in query,
                where: ilike(fragment("concat(?, ' ', ?)", p.first_name, p.last_name), ^"%#{value}%")
              )
          end
        end
      end
    end

    test "custom filter is included in filterable fields" do
      fields = TestPostType.__cql_filterable_fields__()
      assert :full_name in fields
    end

    test "custom filter has correct operators" do
      ops = TestPostType.__cql_operators_for__(:full_name)
      assert :_eq in ops
      assert :_ilike in ops
    end

    test "custom filter function is callable" do
      import Ecto.Query

      query = from(p in TestPost)
      result = TestPostType.__cql_apply_custom_filter__(:full_name, query, :_eq, "John Doe")

      assert %Ecto.Query{} = result
    end
  end

  describe "Connection enhancements - eager loading" do
    alias GreenFairy.Field.Connection

    test "from_list returns nodes, totalCount, and exists eagerly" do
      items = [%{id: 1}, %{id: 2}, %{id: 3}]
      {:ok, result} = Connection.from_list(items, %{first: 2})

      assert length(result.nodes) == 2
      assert result.total_count == 3
      assert result.exists == true
    end

    test "from_list with empty list returns exists: false" do
      {:ok, result} = Connection.from_list([], %{})

      assert result.nodes == []
      assert result.total_count == 0
      assert result.exists == false
    end

    test "from_list respects total_count option" do
      items = [%{id: 1}, %{id: 2}]
      {:ok, result} = Connection.from_list(items, %{}, total_count: 100)

      assert result.total_count == 100
      assert result.exists == true
    end

    test "nodes match edges" do
      items = [%{id: 1}, %{id: 2}, %{id: 3}]
      {:ok, result} = Connection.from_list(items, %{})

      nodes_from_edges = Enum.map(result.edges, & &1.node)
      assert result.nodes == nodes_from_edges
    end
  end

  describe "Connection enhancements - deferred loading" do
    alias GreenFairy.Field.Connection

    test "from_list with deferred: true returns functions" do
      items = [%{id: 1}, %{id: 2}, %{id: 3}]
      {:ok, result} = Connection.from_list(items, %{first: 2}, deferred: true)

      # Should have function keys instead of values
      assert is_function(result._total_count_fn, 0)
      assert is_function(result._exists_fn, 0)
      refute Map.has_key?(result, :total_count)
      refute Map.has_key?(result, :exists)

      # Functions should work when called
      assert result._total_count_fn.() == 3
      assert result._exists_fn.() == true
    end

    test "from_list deferred with empty list" do
      {:ok, result} = Connection.from_list([], %{}, deferred: true)

      assert result.nodes == []
      assert result._total_count_fn.() == 0
      assert result._exists_fn.() == false
    end

    test "from_list deferred with custom count function" do
      items = [%{id: 1}, %{id: 2}]
      custom_count_fn = fn -> 1000 end
      custom_exists_fn = fn -> true end

      {:ok, result} =
        Connection.from_list(items, %{},
          deferred: true,
          total_count_fn: custom_count_fn,
          exists_fn: custom_exists_fn
        )

      assert result._total_count_fn.() == 1000
      assert result._exists_fn.() == true
    end

    test "nodes still eager even with deferred count/exists" do
      items = [%{id: 1}, %{id: 2}, %{id: 3}]
      {:ok, result} = Connection.from_list(items, %{}, deferred: true)

      # Nodes should still be available immediately
      assert length(result.nodes) == 3
      assert result.nodes == [%{id: 1}, %{id: 2}, %{id: 3}]
    end
  end

  describe "CQL operator types" do
    alias GreenFairy.CQL.ScalarMapper
    alias GreenFairy.CQL.Adapters.Postgres

    test "operator_type_identifier maps standard types to operator inputs" do
      assert ScalarMapper.operator_type_identifier(:string) == :cql_op_string_input
      assert ScalarMapper.operator_type_identifier(:integer) == :cql_op_integer_input
      assert ScalarMapper.operator_type_identifier(:float) == :cql_op_float_input
      assert ScalarMapper.operator_type_identifier(:boolean) == :cql_op_boolean_input
      assert ScalarMapper.operator_type_identifier(:id) == :cql_op_id_input
      assert ScalarMapper.operator_type_identifier(:datetime) == :cql_op_date_time_input
    end

    test "operator_type_identifier returns JSON for map types" do
      assert ScalarMapper.operator_type_identifier(:map) == :cql_op_json_input
    end

    test "operator_type_identifier returns nil for unsupported types" do
      assert ScalarMapper.operator_type_identifier(:array) == nil
    end

    test "operator_inputs includes all standard types" do
      types = Postgres.operator_inputs()

      assert Map.has_key?(types, :cql_op_string_input)
      assert Map.has_key?(types, :cql_op_integer_input)
      assert Map.has_key?(types, :cql_op_float_input)
      assert Map.has_key?(types, :cql_op_boolean_input)
      assert Map.has_key?(types, :cql_op_id_input)
    end

    test "operator types use Hasura-style underscore prefixes" do
      {ops, _scalar, _desc} = Postgres.operator_inputs()[:cql_op_string_input]

      assert :_eq in ops
      assert :_neq in ops
      assert :_ilike in ops
      assert :_in in ops
      assert :_is_null in ops
    end
  end

  describe "Sort direction enum" do
    test "CqlSortDirection enum is defined" do
      # This would be tested in actual GraphQL schema compilation
      # For now, just verify the module exists
      assert Code.ensure_loaded?(GreenFairy.CQL.SortDirection)
    end
  end

  describe "CQL QueryBuilder integration" do
    alias GreenFairy.CQL.QueryBuilder
    alias GreenFairy.CQLIntegrationTest.{TestUser, TestUserType}

    test "QueryBuilder transforms where input to Ecto query" do
      import Ecto.Query

      query = from(u in TestUser)
      where_input = %{name: %{_eq: "Alice"}, age: %{_gte: 18}}

      {:ok, result} = QueryBuilder.apply_where(query, where_input, TestUserType)

      assert %Ecto.Query{wheres: wheres} = result
      assert length(wheres) == 2
    end

    test "QueryBuilder transforms orderBy input to Ecto query" do
      import Ecto.Query

      query = from(u in TestUser)
      order_input = [%{name: %{direction: :asc}}, %{age: %{direction: :desc}}]

      result = QueryBuilder.apply_order_by(query, order_input, TestUserType)

      assert %Ecto.Query{order_bys: [order]} = result
      assert length(order.expr) == 2
    end

    test "QueryBuilder handles logical operators" do
      import Ecto.Query

      query = from(u in TestUser)

      where_input = %{
        _and: [
          %{age: %{_gte: 18}},
          %{_or: [%{name: %{_eq: "Alice"}}, %{name: %{_eq: "Bob"}}]}
        ]
      }

      {:ok, result} = QueryBuilder.apply_where(query, where_input, TestUserType)

      assert %Ecto.Query{} = result
    end
  end

  describe "Authorization integration with CQL" do
    defmodule TestSecureUser do
      defstruct [:id, :name, :email, :ssn]

      def __schema__(:fields), do: [:id, :name, :email, :ssn]
      def __schema__(:primary_key), do: [:id]
      def __schema__(:type, :id), do: :id
      def __schema__(:type, :name), do: :string
      def __schema__(:type, :email), do: :string
      def __schema__(:type, :ssn), do: :string
    end

    defmodule TestSecureUserType do
      use GreenFairy.Type

      type "SecureUser", struct: TestSecureUser do
        authorize fn user, ctx ->
          current_user = ctx[:current_user]

          cond do
            current_user && current_user.admin -> :all
            current_user && current_user.id == user.id -> [:id, :name, :email]
            true -> [:id, :name]
          end
        end

        field :id, non_null(:id)
        field :name, :string
        field :email, :string
        field :ssn, :string
      end
    end

    test "authorized fields restricts filterable fields" do
      user = %TestSecureUser{id: 1, name: "Alice"}

      # Admin can filter on all fields
      admin_ctx = %{current_user: %{id: 999, admin: true}}
      admin_fields = TestSecureUserType.__cql_authorized_fields__(user, admin_ctx)
      assert :ssn in admin_fields

      # Self can filter on id, name, email
      self_ctx = %{current_user: %{id: 1, admin: false}}
      self_fields = TestSecureUserType.__cql_authorized_fields__(user, self_ctx)
      assert :email in self_fields
      refute :ssn in self_fields

      # Public can only filter on id, name
      public_ctx = %{current_user: nil}
      public_fields = TestSecureUserType.__cql_authorized_fields__(user, public_ctx)
      assert :name in public_fields
      refute :email in public_fields
      refute :ssn in public_fields
    end
  end
end
