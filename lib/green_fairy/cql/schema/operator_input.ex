defmodule GreenFairy.CQL.Schema.OperatorInput do
  @moduledoc """
  Generates CQL operator input types for different field types.

  These are the `CqlOp{Type}Input` types that define available operators
  for each scalar type in CQL filters.

  ## Generated Types

  - `CqlOpIdInput` - Operators for ID fields
  - `CqlOpStringInput` - Operators for string fields
  - `CqlOpIntegerInput` - Operators for integer fields
  - `CqlOpFloatInput` - Operators for float fields
  - `CqlOpBooleanInput` - Operators for boolean fields
  - `CqlOpDatetimeInput` - Operators for datetime fields
  - `CqlOpDateInput` - Operators for date fields
  - `CqlOpEnumInput` - Operators for enum fields

  ## Example

  The `CqlOpStringInput` type generates:

      input CqlOpStringInput {
        eq: String
        neq: String
        contains: String
        starts_with: String
        ends_with: String
        in: [String]
        is_nil: Boolean
      }
  """

  @doc """
  Returns the operator input type identifier for a given Ecto/adapter type or GraphQL scalar module.

  If the type is a module with a custom CQL input type, that will be used.
  Otherwise, falls back to standard type mappings.
  """
  def type_for(module) when is_atom(module) do
    # Check if it's a module with a custom CQL input type
    if Code.ensure_loaded?(module) and function_exported?(module, :__cql_input_identifier__, 0) do
      case module.__cql_input_identifier__() do
        nil -> type_for_scalar(module)
        identifier -> identifier
      end
    else
      type_for_scalar(module)
    end
  end

  def type_for(other), do: type_for_scalar(other)

  @doc """
  Returns the array operator input type identifier for array fields.

  This is used for fields that are arrays (e.g., `{:array, :string}`) to
  provide array-specific operators like `_includes`, `_excludes`, etc.
  """
  def array_type_for({:array, inner_type}) do
    case type_for_scalar(inner_type) do
      :cql_op_enum_input -> :cql_op_enum_array_input
      :cql_op_string_input -> :cql_op_string_array_input
      :cql_op_integer_input -> :cql_op_integer_array_input
      :cql_op_id_input -> :cql_op_id_array_input
      _ -> :cql_op_generic_array_input
    end
  end

  def array_type_for(_), do: nil

  # Internal function for standard type mappings
  defp type_for_scalar(:id), do: :cql_op_id_input
  defp type_for_scalar(:binary_id), do: :cql_op_id_input
  defp type_for_scalar(:string), do: :cql_op_string_input
  defp type_for_scalar(:integer), do: :cql_op_integer_input
  defp type_for_scalar(:float), do: :cql_op_float_input
  defp type_for_scalar(:decimal), do: :cql_op_decimal_input
  defp type_for_scalar(:boolean), do: :cql_op_boolean_input
  defp type_for_scalar(:naive_datetime), do: :cql_op_naive_date_time_input
  defp type_for_scalar(:utc_datetime), do: :cql_op_date_time_input
  defp type_for_scalar(:naive_datetime_usec), do: :cql_op_naive_date_time_input
  defp type_for_scalar(:utc_datetime_usec), do: :cql_op_date_time_input
  defp type_for_scalar(:date), do: :cql_op_date_input
  defp type_for_scalar(:time), do: :cql_op_time_input
  defp type_for_scalar(:time_usec), do: :cql_op_time_input
  defp type_for_scalar(:datetime), do: :cql_op_date_time_input
  defp type_for_scalar(:map), do: nil
  defp type_for_scalar(:array), do: nil
  defp type_for_scalar({:array, inner_type}), do: array_type_for({:array, inner_type})
  defp type_for_scalar({:map, _}), do: nil
  defp type_for_scalar({:parameterized, Ecto.Enum, _}), do: :cql_op_enum_input
  defp type_for_scalar({:parameterized, Ecto.Embedded, _}), do: nil
  defp type_for_scalar(_), do: :cql_op_generic_input

  @doc """
  Returns the GraphQL scalar type for a given Ecto/adapter type.
  """
  def scalar_for(:id), do: :id
  def scalar_for(:binary_id), do: :id
  def scalar_for(:string), do: :string
  def scalar_for(:integer), do: :integer
  def scalar_for(:float), do: :float
  def scalar_for(:decimal), do: :float
  def scalar_for(:boolean), do: :boolean
  def scalar_for(:naive_datetime), do: :datetime
  def scalar_for(:utc_datetime), do: :datetime
  def scalar_for(:naive_datetime_usec), do: :datetime
  def scalar_for(:utc_datetime_usec), do: :datetime
  def scalar_for(:date), do: :date
  def scalar_for(:time), do: :time
  def scalar_for(:time_usec), do: :time
  def scalar_for({:parameterized, Ecto.Enum, _}), do: :string
  def scalar_for(_), do: :string

  @doc """
  DEPRECATED: Use `adapter.operator_inputs/0` instead.

  This function is kept for backwards compatibility with existing tests only.
  Adapters now own their operator definitions via the `operator_inputs/0` callback.

  ## Migration

  Instead of:
  ```elixir
  OperatorInput.operator_types()
  ```

  Use:
  ```elixir
  adapter = GreenFairy.CQL.Adapters.Postgres
  adapter.operator_inputs()
  ```
  """
  @deprecated "Use adapter.operator_inputs/0 instead - adapters own their operators"
  def operator_types do
    # Return PostgreSQL operators as default for backwards compatibility
    GreenFairy.CQL.Adapters.Postgres.operator_inputs()
  end

  @doc """
  Generates AST for all operator input types from the adapter.

  ## IMPORTANT: Adapter is REQUIRED

  CQL operators are database-specific. The adapter declares what operators
  it supports by implementing the `operator_inputs/0` callback.

  ## Options

  - `:adapter` - **REQUIRED** CQL adapter module (defaults to PostgreSQL if nil)

  ## Examples

      # PostgreSQL operators
      generate_all(adapter: GreenFairy.CQL.Adapters.Postgres)

      # MySQL operators (different from PostgreSQL!)
      generate_all(adapter: GreenFairy.CQL.Adapters.MySQL)

      # Default to PostgreSQL (for testing)
      generate_all(adapter: nil)

  ## Raises

  `ArgumentError` if adapter is not provided or doesn't implement operator_inputs/0.

  """
  def generate_all(opts \\ []) do
    adapter = Keyword.fetch!(opts, :adapter)
    # Default to PostgreSQL if adapter is nil (for backwards compatibility/testing)
    adapter = adapter || GreenFairy.CQL.Adapters.Postgres

    unless Code.ensure_loaded?(adapter) and function_exported?(adapter, :operator_inputs, 0) do
      raise ArgumentError, """
      Adapter #{inspect(adapter)} does not implement operator_inputs/0.

      Adapters must implement the GreenFairy.CQL.Adapter behavior
      and define which operators they support.
      """
    end

    for {identifier, {operators, scalar, description}} <- adapter.operator_inputs() do
      generate_input(identifier, operators, scalar, description)
    end
  end

  @doc """
  Determines the operator category from the identifier.

  Used to query adapters for supported operators.

  ## Examples

      operator_category(:cql_op_string_input)
      # => :scalar

      operator_category(:cql_op_enum_array_input)
      # => :array

  """
  def operator_category(identifier) when is_atom(identifier) do
    id_string = Atom.to_string(identifier)

    cond do
      String.contains?(id_string, "_array_") -> :array
      String.contains?(id_string, "_json_") -> :json
      true -> :scalar
    end
  end

  @doc """
  Generates AST for a single operator input type.
  """
  def generate_input(identifier, operators, scalar_type, description) do
    fields = Enum.map(operators, &operator_field(&1, scalar_type))

    quote do
      @desc unquote(description)
      input_object unquote(identifier) do
        (unquote_splicing(fields))
      end
    end
  end

  # Standard comparison operators (camelCase versions)
  defp operator_field(:eq, scalar), do: quote(do: field(:eq, unquote(scalar)))
  defp operator_field(:neq, scalar), do: quote(do: field(:neq, unquote(scalar)))
  defp operator_field(:gt, scalar), do: quote(do: field(:gt, unquote(scalar)))
  defp operator_field(:gte, scalar), do: quote(do: field(:gte, unquote(scalar)))
  defp operator_field(:lt, scalar), do: quote(do: field(:lt, unquote(scalar)))
  defp operator_field(:lte, scalar), do: quote(do: field(:lte, unquote(scalar)))
  defp operator_field(:in, scalar), do: quote(do: field(:in, list_of(unquote(scalar))))
  defp operator_field(:nin, scalar), do: quote(do: field(:nin, list_of(unquote(scalar))))

  # Hasura-style underscore operators (underscore prefixed)
  defp operator_field(:_eq, scalar), do: quote(do: field(:_eq, unquote(scalar)))
  defp operator_field(:_ne, scalar), do: quote(do: field(:_ne, unquote(scalar)))
  defp operator_field(:_neq, scalar), do: quote(do: field(:_neq, unquote(scalar)))
  defp operator_field(:_gt, scalar), do: quote(do: field(:_gt, unquote(scalar)))
  defp operator_field(:_gte, scalar), do: quote(do: field(:_gte, unquote(scalar)))
  defp operator_field(:_lt, scalar), do: quote(do: field(:_lt, unquote(scalar)))
  defp operator_field(:_lte, scalar), do: quote(do: field(:_lte, unquote(scalar)))
  defp operator_field(:_in, scalar), do: quote(do: field(:_in, list_of(unquote(scalar))))
  defp operator_field(:_nin, scalar), do: quote(do: field(:_nin, list_of(unquote(scalar))))

  # String pattern operators
  defp operator_field(:like, _scalar), do: quote(do: field(:like, :string))
  defp operator_field(:nlike, _scalar), do: quote(do: field(:nlike, :string))
  defp operator_field(:ilike, _scalar), do: quote(do: field(:ilike, :string))
  defp operator_field(:nilike, _scalar), do: quote(do: field(:nilike, :string))
  defp operator_field(:_like, _scalar), do: quote(do: field(:_like, :string))
  defp operator_field(:_nlike, _scalar), do: quote(do: field(:_nlike, :string))
  defp operator_field(:_ilike, _scalar), do: quote(do: field(:_ilike, :string))
  defp operator_field(:_nilike, _scalar), do: quote(do: field(:_nilike, :string))

  # String matching operators (for _contains, _starts_with, etc.)
  defp operator_field(:contains, _scalar), do: quote(do: field(:contains, :string))
  defp operator_field(:starts_with, _scalar), do: quote(do: field(:starts_with, :string))
  defp operator_field(:ends_with, _scalar), do: quote(do: field(:ends_with, :string))
  defp operator_field(:_contains, _scalar), do: quote(do: field(:_contains, :string))
  defp operator_field(:_icontains, _scalar), do: quote(do: field(:_icontains, :string))
  defp operator_field(:_starts_with, _scalar), do: quote(do: field(:_starts_with, :string))
  defp operator_field(:_istarts_with, _scalar), do: quote(do: field(:_istarts_with, :string))
  defp operator_field(:_ends_with, _scalar), do: quote(do: field(:_ends_with, :string))
  defp operator_field(:_iends_with, _scalar), do: quote(do: field(:_iends_with, :string))

  # Null checking operators
  defp operator_field(:is_nil, _scalar), do: quote(do: field(:is_nil, :boolean))
  defp operator_field(:_is_null, _scalar), do: quote(do: field(:_is_null, :boolean))

  # Range operators
  # For _between, we use a list with exactly 2 elements [start, end]
  # This matches GigSmart's CqlOpDatetimeBetweenInput pattern but simpler
  defp operator_field(:_between, scalar), do: quote(do: field(:_between, list_of(non_null(unquote(scalar)))))

  # Array operators
  defp operator_field(:_includes, scalar), do: quote(do: field(:_includes, unquote(scalar)))
  defp operator_field(:_excludes, scalar), do: quote(do: field(:_excludes, unquote(scalar)))
  defp operator_field(:_includes_all, scalar), do: quote(do: field(:_includes_all, list_of(non_null(unquote(scalar)))))
  defp operator_field(:_excludes_all, scalar), do: quote(do: field(:_excludes_all, list_of(non_null(unquote(scalar)))))
  defp operator_field(:_includes_any, scalar), do: quote(do: field(:_includes_any, list_of(non_null(unquote(scalar)))))
  defp operator_field(:_excludes_any, scalar), do: quote(do: field(:_excludes_any, list_of(non_null(unquote(scalar)))))
  defp operator_field(:_is_empty, _scalar), do: quote(do: field(:_is_empty, :boolean))

  # Elasticsearch-specific full-text search operators
  defp operator_field(:_match, _scalar), do: quote(do: field(:_match, :string))
  defp operator_field(:_match_phrase, _scalar), do: quote(do: field(:_match_phrase, :string))
  defp operator_field(:_match_phrase_prefix, _scalar), do: quote(do: field(:_match_phrase_prefix, :string))
  defp operator_field(:_fuzzy, _scalar), do: quote(do: field(:_fuzzy, :string))
  defp operator_field(:_prefix, _scalar), do: quote(do: field(:_prefix, :string))
  defp operator_field(:_regexp, _scalar), do: quote(do: field(:_regexp, :string))
  defp operator_field(:_wildcard, _scalar), do: quote(do: field(:_wildcard, :string))

  # Period operators for date/time fields
  # These use custom input types defined by the DateTime scalar
  defp operator_field(:_period, _scalar), do: quote(do: field(:_period, :cql_period_input))
  defp operator_field(:_current_period, _scalar), do: quote(do: field(:_current_period, :cql_current_period_input))
end
