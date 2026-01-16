defmodule GreenFairy.CQLTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Adapter
  alias GreenFairy.Adapters.Ecto, as: EctoAdapter
  alias GreenFairy.CQL

  # Plain struct (not Ecto)
  defmodule PlainUser do
    defstruct [:id, :name, :email]
  end

  # Mock Ecto schema for testing
  defmodule MockEctoUser do
    @moduledoc false

    # Simulate Ecto schema behavior
    def __schema__(:fields), do: [:id, :name, :email, :age, :active, :inserted_at]
    def __schema__(:type, :id), do: :id
    def __schema__(:type, :name), do: :string
    def __schema__(:type, :email), do: :string
    def __schema__(:type, :age), do: :integer
    def __schema__(:type, :active), do: :boolean
    def __schema__(:type, :inserted_at), do: :naive_datetime
    def __schema__(:type, _), do: nil

    defstruct [:id, :name, :email, :age, :active, :inserted_at, :full_name]
  end

  # Mock Ecto schema with enum
  defmodule MockEctoWithEnum do
    def __schema__(:fields), do: [:id, :status]
    def __schema__(:type, :id), do: :id
    def __schema__(:type, :status), do: {:parameterized, Ecto.Enum, %{}}
    def __schema__(:type, _), do: nil

    defstruct [:id, :status]
  end

  # ============================================================================
  # Unified Adapter Tests
  # ============================================================================

  describe "EctoAdapter.handles?/1" do
    test "returns true for module with __schema__/1" do
      assert EctoAdapter.handles?(MockEctoUser)
    end

    test "returns false for plain struct" do
      refute EctoAdapter.handles?(PlainUser)
    end

    test "returns false for non-module" do
      refute EctoAdapter.handles?("not a module")
      refute EctoAdapter.handles?(nil)
    end
  end

  describe "EctoAdapter.queryable_fields/1" do
    test "returns fields for Ecto schema" do
      fields = EctoAdapter.queryable_fields(MockEctoUser)
      assert :id in fields
      assert :name in fields
      assert :email in fields
    end

    test "returns empty list for non-Ecto module" do
      assert EctoAdapter.queryable_fields(PlainUser) == []
    end
  end

  describe "EctoAdapter.field_type/2" do
    test "returns type for Ecto schema field" do
      assert EctoAdapter.field_type(MockEctoUser, :name) == :string
      assert EctoAdapter.field_type(MockEctoUser, :age) == :integer
      assert EctoAdapter.field_type(MockEctoUser, :active) == :boolean
    end

    test "returns nil for non-Ecto module" do
      assert EctoAdapter.field_type(PlainUser, :name) == nil
    end
  end

  describe "EctoAdapter.operators_for_type/1" do
    test "returns string operators" do
      ops = EctoAdapter.operators_for_type(:string)
      assert :eq in ops
      assert :contains in ops
      assert :starts_with in ops
      assert :ends_with in ops
      assert :in in ops
      assert :is_nil in ops
    end

    test "returns integer operators" do
      ops = EctoAdapter.operators_for_type(:integer)
      assert :eq in ops
      assert :gt in ops
      assert :lt in ops
      assert :gte in ops
      assert :lte in ops
      assert :in in ops
    end

    test "returns boolean operators" do
      ops = EctoAdapter.operators_for_type(:boolean)
      assert :eq in ops
      assert :is_nil in ops
      refute :contains in ops
    end

    test "returns datetime operators" do
      for type <- [:naive_datetime, :utc_datetime, :date] do
        ops = EctoAdapter.operators_for_type(type)
        assert :eq in ops
        assert :gt in ops
        assert :lt in ops
        refute :contains in ops
      end
    end

    test "returns id operators" do
      ops = EctoAdapter.operators_for_type(:id)
      assert :eq in ops
      assert :in in ops
      refute :gt in ops
    end

    test "handles Ecto.Enum parameterized type" do
      ops = EctoAdapter.operators_for_type({:parameterized, Ecto.Enum, %{}})
      assert :eq in ops
      assert :in in ops
      assert :neq in ops
    end

    test "returns default operators for unknown type" do
      ops = EctoAdapter.operators_for_type(:unknown_type)
      assert :eq in ops
      assert :in in ops
    end
  end

  describe "EctoAdapter.type_operators/0" do
    test "returns all type mappings" do
      operators = EctoAdapter.type_operators()

      assert is_map(operators)
      assert Map.has_key?(operators, :string)
      assert Map.has_key?(operators, :integer)
      assert Map.has_key?(operators, :boolean)
      assert Map.has_key?(operators, :naive_datetime)
    end
  end

  describe "EctoAdapter capabilities" do
    test "returns correct capabilities" do
      assert EctoAdapter.capabilities() == [:cql, :dataloader]
    end

    test "dataloader_source returns :repo by default" do
      assert EctoAdapter.dataloader_source(MockEctoUser) == :repo
    end
  end

  # ============================================================================
  # Unified Adapter Discovery Tests
  # ============================================================================

  describe "Adapter.find_adapter/2" do
    test "returns nil for nil module" do
      assert Adapter.find_adapter(nil, nil) == nil
    end

    test "finds Ecto adapter for Ecto schema" do
      adapter = Adapter.find_adapter(MockEctoUser, nil)
      assert adapter == EctoAdapter
    end

    test "returns nil for plain struct with no matching adapter" do
      adapter = Adapter.find_adapter(PlainUser, nil)
      assert adapter == nil
    end

    test "uses explicit adapter override when provided" do
      defmodule MockAdapter do
        use GreenFairy.Adapter

        @impl true
        def handles?(_), do: true

        @impl true
        def queryable_fields(_), do: [:mock_field]

        @impl true
        def field_type(_, _), do: :string

        @impl true
        def operators_for_type(_), do: [:eq]
      end

      adapter = Adapter.find_adapter(PlainUser, MockAdapter)
      assert adapter == MockAdapter
    end
  end

  describe "Adapter.default_adapters/0" do
    test "returns list with Ecto adapter" do
      adapters = Adapter.default_adapters()
      assert EctoAdapter in adapters
    end
  end

  describe "Adapter.supports?/2" do
    test "returns true for supported capabilities" do
      assert Adapter.supports?(EctoAdapter, :cql)
      assert Adapter.supports?(EctoAdapter, :dataloader)
    end

    test "returns false for unsupported capabilities" do
      refute Adapter.supports?(EctoAdapter, :full_text_search)
    end
  end

  # ============================================================================
  # CQL Extension Integration Tests
  # ============================================================================

  describe "Extension with Ecto schema" do
    defmodule EctoCQLType do
      use GreenFairy.Type

      type "EctoUser", struct: MockEctoUser do
        use CQL

        field :id, non_null(:id)
        field :name, :string
        field :email, :string
        field :age, :integer
        # Not in Ecto schema
        field :full_name, :string
      end
    end

    test "detects adapter" do
      config = EctoCQLType.__cql_config__()
      assert config.adapter == EctoAdapter
    end

    test "extracts adapter fields" do
      config = EctoCQLType.__cql_config__()
      assert :id in config.adapter_fields
      assert :name in config.adapter_fields
      assert :email in config.adapter_fields
      assert :age in config.adapter_fields
    end

    test "extracts adapter field types" do
      config = EctoCQLType.__cql_config__()
      assert config.adapter_field_types[:name] == :string
      assert config.adapter_field_types[:age] == :integer
    end

    test "filterable fields includes adapter fields" do
      fields = EctoCQLType.__cql_filterable_fields__()
      assert :id in fields
      assert :name in fields
      assert :age in fields
    end

    test "operators are inferred from adapter" do
      # name is :string in Ecto
      name_ops = EctoCQLType.__cql_operators_for__(:name)
      assert :contains in name_ops

      # age is :integer in Ecto
      age_ops = EctoCQLType.__cql_operators_for__(:age)
      assert :gt in age_ops
      assert :lt in age_ops
      refute :contains in age_ops
    end

    test "non-adapter field has no operators" do
      # full_name is not in the Ecto schema
      ops = EctoCQLType.__cql_operators_for__(:full_name)
      assert ops == []
    end
  end

  describe "Extension with plain struct" do
    defmodule PlainCQLType do
      use GreenFairy.Type

      type "PlainUser", struct: PlainUser do
        use CQL

        field :id, :id
        field :name, :string
      end
    end

    test "has no adapter" do
      config = PlainCQLType.__cql_config__()
      assert config.adapter == nil
    end

    test "has no adapter fields" do
      config = PlainCQLType.__cql_config__()
      assert config.adapter_fields == []
    end

    test "has no filterable fields without custom filters" do
      fields = PlainCQLType.__cql_filterable_fields__()
      assert fields == []
    end
  end

  # ============================================================================
  # Custom Filter Tests
  # ============================================================================

  describe "custom_filter macro" do
    defmodule CustomFilterType do
      use GreenFairy.Type

      type "CustomUser", struct: MockEctoUser do
        use CQL

        field :id, non_null(:id)
        field :name, :string
        # Computed field
        field :full_name, :string

        # Custom filter for computed field
        custom_filter(:full_name, [:eq, :contains], fn query, op, value ->
          case op do
            :eq -> {:custom_eq, query, value}
            :contains -> {:custom_contains, query, value}
          end
        end)
      end
    end

    test "custom filter is registered" do
      config = CustomFilterType.__cql_config__()
      assert Map.has_key?(config.custom_filters, :full_name)
    end

    test "custom filter has correct operators" do
      ops = CustomFilterType.__cql_operators_for__(:full_name)
      assert :eq in ops
      assert :contains in ops
      refute :gt in ops
    end

    test "custom filter field is in filterable fields" do
      fields = CustomFilterType.__cql_filterable_fields__()
      assert :full_name in fields
    end

    test "custom filter function is generated" do
      # The custom filter function is generated as __cql_apply_custom_filter__
      assert function_exported?(CustomFilterType, :__cql_apply_custom_filter__, 4)

      # Test it works
      result = CustomFilterType.__cql_apply_custom_filter__(:full_name, %{query: true}, :eq, "test")
      assert result == {:custom_eq, %{query: true}, "test"}
    end
  end

  describe "custom_filter with type shorthand" do
    defmodule TypeShorthandFilterType do
      use GreenFairy.Type

      type "ShorthandUser", struct: PlainUser do
        use CQL

        field :id, :id
        field :computed_score, :integer

        # Use :integer shorthand to get all integer operators
        custom_filter(:computed_score, :integer, fn query, _op, _value -> query end)
      end
    end

    test "type shorthand expands to operators" do
      ops = TypeShorthandFilterType.__cql_operators_for__(:computed_score)
      assert :eq in ops
      assert :gt in ops
      assert :lt in ops
      assert :gte in ops
      assert :lte in ops
    end
  end

  # ============================================================================
  # Authorization Integration Tests
  # ============================================================================

  describe "CQL authorization integration" do
    defmodule AuthorizedUser do
      defstruct [:id, :name, :email, :ssn, :salary]
    end

    defmodule AuthorizedCQLType do
      use GreenFairy.Type

      type "AuthorizedUser", struct: AuthorizedUser do
        use CQL

        # Authorization based on context
        authorize(fn _user, ctx ->
          cond do
            ctx[:role] == :admin -> :all
            ctx[:role] == :hr -> [:id, :name, :email, :salary]
            true -> [:id, :name]
          end
        end)

        field :id, non_null(:id)
        field :name, :string
        field :email, :string
        field :ssn, :string
        field :salary, :integer

        # Custom filters for all fields
        custom_filter(:id, [:eq, :in], fn q, _, _ -> q end)
        custom_filter(:name, [:eq, :contains], fn q, _, _ -> q end)
        custom_filter(:email, [:eq, :contains], fn q, _, _ -> q end)
        custom_filter(:ssn, [:eq], fn q, _, _ -> q end)
        custom_filter(:salary, [:eq, :gt, :lt], fn q, _, _ -> q end)
      end
    end

    test "__cql_authorized_fields__ returns all fields for admin" do
      object = %AuthorizedUser{}
      ctx = %{role: :admin}
      fields = AuthorizedCQLType.__cql_authorized_fields__(object, ctx)

      assert :id in fields
      assert :name in fields
      assert :email in fields
      assert :ssn in fields
      assert :salary in fields
    end

    test "__cql_authorized_fields__ excludes ssn for HR" do
      object = %AuthorizedUser{}
      ctx = %{role: :hr}
      fields = AuthorizedCQLType.__cql_authorized_fields__(object, ctx)

      assert :id in fields
      assert :name in fields
      assert :email in fields
      refute :ssn in fields
      assert :salary in fields
    end

    test "__cql_authorized_fields__ returns only public fields for regular users" do
      object = %AuthorizedUser{}
      ctx = %{role: :user}
      fields = AuthorizedCQLType.__cql_authorized_fields__(object, ctx)

      assert :id in fields
      assert :name in fields
      refute :email in fields
      refute :ssn in fields
      refute :salary in fields
    end

    test "__cql_validate_filter__ returns :ok for authorized fields" do
      object = %AuthorizedUser{}
      ctx = %{role: :admin}
      result = AuthorizedCQLType.__cql_validate_filter__([:id, :name, :email], object, ctx)

      assert result == :ok
    end

    test "__cql_validate_filter__ returns error for unauthorized fields" do
      object = %AuthorizedUser{}
      ctx = %{role: :user}
      result = AuthorizedCQLType.__cql_validate_filter__([:id, :name, :email, :ssn], object, ctx)

      assert {:error, {:unauthorized_fields, unauthorized}} = result
      assert :email in unauthorized
      assert :ssn in unauthorized
    end

    test "__cql_validate_filter__ handles map input" do
      object = %AuthorizedUser{}
      ctx = %{role: :user}
      filter = %{id: "123", email: "test@example.com"}
      result = AuthorizedCQLType.__cql_validate_filter__(filter, object, ctx)

      assert {:error, {:unauthorized_fields, [:email]}} = result
    end

    test "__cql_validate_filter__ ignores logical operators in map" do
      object = %AuthorizedUser{}
      ctx = %{role: :admin}
      filter = %{id: "123", _and: [%{name: "Test"}], _or: [], _not: %{}}
      result = AuthorizedCQLType.__cql_validate_filter__(filter, object, ctx)

      assert result == :ok
    end

    test "__cql_authorized_operators_for__ returns operators for authorized fields" do
      object = %AuthorizedUser{}
      ctx = %{role: :admin}
      ops = AuthorizedCQLType.__cql_authorized_operators_for__(:salary, object, ctx)

      assert :eq in ops
      assert :gt in ops
      assert :lt in ops
    end

    test "__cql_authorized_operators_for__ returns empty list for unauthorized fields" do
      object = %AuthorizedUser{}
      ctx = %{role: :user}
      ops = AuthorizedCQLType.__cql_authorized_operators_for__(:salary, object, ctx)

      assert ops == []
    end
  end

  # ============================================================================
  # FilterInput Helper Tests
  # ============================================================================

  describe "FilterInput" do
    alias GreenFairy.CQL.Schema.FilterInput

    test "generates filter input name from string" do
      assert FilterInput.input_name("User") == :UserFilter
    end

    test "generates filter input name from atom" do
      assert FilterInput.input_name(:user) == :UserFilter
      assert FilterInput.input_name(:blog_post) == :BlogPostFilter
    end
  end

  # ============================================================================
  # GigSmart-style CQL Filter Type Tests
  # ============================================================================

  describe "GigSmart-style filter input generation" do
    # Use the module defined earlier in this test file
    alias GreenFairy.CQLTest.EctoCQLType

    test "__cql_filter_input_identifier__ returns CqlFilter{Type}Input identifier" do
      identifier = EctoCQLType.__cql_filter_input_identifier__()
      assert identifier == :cql_filter_ecto_user_input
    end

    test "__cql_filter_fields__ returns field with types" do
      fields = EctoCQLType.__cql_filter_fields__()

      # Should return list of {field_name, field_type} tuples
      assert is_list(fields)
      assert {:id, :id} in fields
      assert {:name, :string} in fields
      assert {:email, :string} in fields
      assert {:age, :integer} in fields
    end

    test "__cql_config__ includes filter input identifier" do
      config = EctoCQLType.__cql_config__()

      assert config.type_name == "EctoUser"
      assert config.type_identifier == :ecto_user
      assert config.filter_input_identifier == :cql_filter_ecto_user_input
    end

    test "__cql_generate_filter_input__ returns valid AST" do
      ast = EctoCQLType.__cql_generate_filter_input__()

      assert is_tuple(ast)
      ast_string = Macro.to_string(ast)

      # Should contain the filter input identifier
      assert ast_string =~ "cql_filter_ecto_user_input"

      # Should contain combinator fields
      assert ast_string =~ "_and"
      assert ast_string =~ "_or"
      assert ast_string =~ "_not"

      # Should contain field-specific operator types
      assert ast_string =~ "cql_op_id_input"
      assert ast_string =~ "cql_op_string_input"
      assert ast_string =~ "cql_op_integer_input"
    end
  end

  describe "Custom filter with GigSmart-style generation" do
    alias GreenFairy.CQLTest.CustomFilterType

    test "__cql_generate_filter_input__ includes custom filter fields" do
      ast = CustomFilterType.__cql_generate_filter_input__()
      ast_string = Macro.to_string(ast)

      # Should contain the full_name field (custom filter)
      assert ast_string =~ "full_name"

      # Custom filter with :contains should use string operator type
      assert ast_string =~ "cql_op_string_input"
    end
  end
end
