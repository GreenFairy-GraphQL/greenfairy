defmodule GreenFairy.CQL.Schema.EnumOperatorInput do
  @moduledoc """
  Generates type-specific CQL operator input types for GraphQL enums.

  When an enum is used in a CQL-enabled type, this module automatically generates
  a type-specific operator input that uses the actual enum type for comparisons.

  ## Example

  For an `OrderStatus` enum used in a CQL-enabled type:

      input CqlEnumOrderStatusInput {
        _eq: OrderStatus
        _neq: OrderStatus
        _in: [OrderStatus!]
        _nin: [OrderStatus!]
        _is_null: Boolean
      }

  This provides type safety - the GraphQL schema validates that only valid
  enum values are provided for filtering.

  ## Naming Convention

  Follows the pattern: `CqlEnum{EnumName}Input`

  - `OrderStatus` → `CqlEnumOrderStatusInput` (identifier: `:cql_enum_order_status_input`)
  - `UserRole` → `CqlEnumUserRoleInput` (identifier: `:cql_enum_user_role_input`)
  """

  @doc """
  Generates the operator input type identifier for an enum type.

  ## Examples

      iex> EnumOperatorInput.operator_type_identifier(:order_status)
      :cql_enum_order_status_input

      iex> EnumOperatorInput.operator_type_identifier("OrderStatus")
      :cql_enum_order_status_input

  """
  def operator_type_identifier(enum_identifier) when is_atom(enum_identifier) do
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    String.to_atom("cql_enum_#{enum_identifier}_input")
  end

  def operator_type_identifier(enum_name) when is_binary(enum_name) do
    underscored = Macro.underscore(enum_name)
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    String.to_atom("cql_enum_#{underscored}_input")
  end

  @doc """
  Generates the array operator input type identifier for an enum type.

  ## Examples

      iex> EnumOperatorInput.array_operator_type_identifier(:order_status)
      :cql_enum_order_status_array_input

  """
  def array_operator_type_identifier(enum_identifier) when is_atom(enum_identifier) do
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    String.to_atom("cql_enum_#{enum_identifier}_array_input")
  end

  def array_operator_type_identifier(enum_name) when is_binary(enum_name) do
    underscored = Macro.underscore(enum_name)
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    String.to_atom("cql_enum_#{underscored}_array_input")
  end

  @doc """
  Generates AST for a type-specific enum operator input.

  ## Parameters

  - `enum_identifier` - The GraphQL enum type identifier (e.g., `:order_status`)
  - `description` - Optional description for the input type

  ## Returns

  AST for the input_object definition.
  """
  def generate(enum_identifier, description \\ nil) do
    input_identifier = operator_type_identifier(enum_identifier)
    desc = description || "CQL operators for #{enum_identifier} enum"

    # Build field definitions matching Absinthe's expected AST
    field_defs = [
      quote(do: Absinthe.Schema.Notation.field(:_eq, unquote(enum_identifier))),
      quote(do: Absinthe.Schema.Notation.field(:_ne, unquote(enum_identifier))),
      quote(do: Absinthe.Schema.Notation.field(:_neq, unquote(enum_identifier))),
      quote(do: Absinthe.Schema.Notation.field(:_in, list_of(non_null(unquote(enum_identifier))))),
      quote(do: Absinthe.Schema.Notation.field(:_nin, list_of(non_null(unquote(enum_identifier))))),
      quote(do: Absinthe.Schema.Notation.field(:_is_null, :boolean))
    ]

    quote do
      Absinthe.Schema.Notation.input_object unquote(input_identifier) do
        @desc unquote(desc)
        unquote_splicing(field_defs)
      end
    end
  end

  @doc """
  Generates AST for a type-specific enum array operator input.

  ## Parameters

  - `enum_identifier` - The GraphQL enum type identifier (e.g., `:order_status`)
  - `description` - Optional description for the input type

  ## Returns

  AST for the array operator input_object definition.
  """
  def generate_array(enum_identifier, description \\ nil) do
    input_identifier = array_operator_type_identifier(enum_identifier)
    desc = description || "CQL array operators for #{enum_identifier} enum"

    # Build field definitions matching Absinthe's expected AST
    field_defs = [
      quote(do: Absinthe.Schema.Notation.field(:_includes, unquote(enum_identifier))),
      quote(do: Absinthe.Schema.Notation.field(:_excludes, unquote(enum_identifier))),
      quote(do: Absinthe.Schema.Notation.field(:_includes_all, list_of(non_null(unquote(enum_identifier))))),
      quote(do: Absinthe.Schema.Notation.field(:_excludes_all, list_of(non_null(unquote(enum_identifier))))),
      quote(do: Absinthe.Schema.Notation.field(:_includes_any, list_of(non_null(unquote(enum_identifier))))),
      quote(do: Absinthe.Schema.Notation.field(:_excludes_any, list_of(non_null(unquote(enum_identifier))))),
      quote(do: Absinthe.Schema.Notation.field(:_is_empty, :boolean)),
      quote(do: Absinthe.Schema.Notation.field(:_is_null, :boolean))
    ]

    quote do
      Absinthe.Schema.Notation.input_object unquote(input_identifier) do
        @desc unquote(desc)
        unquote_splicing(field_defs)
      end
    end
  end

  @doc """
  Generates AST for multiple enum operator inputs.

  Takes a list of enum identifiers and generates both scalar and array
  operator inputs for each.

  ## Example

      EnumOperatorInput.generate_all([:order_status, :user_role])

  """
  def generate_all(enum_identifiers) do
    enum_identifiers
    |> Enum.flat_map(fn enum_id ->
      [generate(enum_id), generate_array(enum_id)]
    end)
  end
end
