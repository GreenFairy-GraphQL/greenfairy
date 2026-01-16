defmodule GreenFairy.CQL.ScalarMapper do
  @moduledoc """
  Maps Ecto field types to CQL scalar modules.

  This module provides the mapping between Ecto schema field types
  and their corresponding CQL scalar implementations. It supports:

  1. **Built-in scalars** - Common Ecto types (string, integer, datetime, etc.)
  2. **Custom scalars (opt-in)** - Explicitly registered via configuration

  ## Usage

      iex> ScalarMapper.scalar_for(:string)
      GreenFairy.CQL.Scalars.String

      iex> ScalarMapper.scalar_for({:array, :string})
      GreenFairy.CQL.Scalars.ArrayString

  ## Custom Scalars (Opt-In)

  Custom scalars must be explicitly registered in your application config:

      # config/config.exs
      config :green_fairy, :custom_scalars, %{
        money: MyApp.CQL.Scalars.Money,
        phone_number: MyApp.CQL.Scalars.PhoneNumber,
        duration: MyApp.CQL.Scalars.Duration
      }

  Then use the custom type in your Ecto schema:

      schema "products" do
        field :price, :money  # Maps to MyApp.CQL.Scalars.Money
      end

  ## Implementing Custom Scalars

  Define your own scalars by implementing the `GreenFairy.CQL.Scalar` behavior:

      defmodule MyApp.CQL.Scalars.Money do
        @behaviour GreenFairy.CQL.Scalar

        @impl true
        def operator_input(:postgres) do
          {[:_eq, :_neq, :_gt, :_gte, :_lt, :_lte, :_is_null],
           :decimal, "Money operators (stored as decimal)"}
        end

        @impl true
        def apply_operator(query, field, :_gt, value, :postgres, opts) do
          binding = Keyword.get(opts, :binding)
          if binding do
            where(query, [{^binding, q}], field(q, ^field) > ^value)
          else
            where(query, [q], field(q, ^field) > ^value)
          end
        end

        @impl true
        def operator_type_identifier(_adapter), do: :cql_op_money_input
      end

  ## Lookup Order

  1. Check custom scalars from application config
  2. Check built-in scalar mappings
  3. Return nil if no scalar found
  """

  alias GreenFairy.CQL.Scalars

  @doc """
  Returns the CQL scalar module for an Ecto field type.

  Lookup order:
  1. Custom scalars from application config
  2. Built-in scalar mappings
  3. Returns nil if not found

  ## Parameters

  - `ecto_type` - Ecto field type from schema

  ## Returns

  Scalar module atom or `nil` if type is not filterable.

  ## Examples

      scalar_for(:string)
      # => GreenFairy.CQL.Scalars.String

      scalar_for({:array, :integer})
      # => GreenFairy.CQL.Scalars.ArrayInteger

      scalar_for(:money)  # with custom scalar configured
      # => MyApp.CQL.Scalars.Money

      scalar_for(:map)
      # => GreenFairy.BuiltIns.Scalars.JSON
  """
  def scalar_for(ecto_type) do
    custom_scalar_for(ecto_type) || built_in_scalar_for(ecto_type)
  end

  # Check for custom scalar in application config (opt-in)
  defp custom_scalar_for(ecto_type) do
    custom_scalars = Application.get_env(:green_fairy, :custom_scalars, %{})
    Map.get(custom_scalars, ecto_type)
  end

  # Built-in scalar mappings
  defp built_in_scalar_for(:id), do: Scalars.ID
  defp built_in_scalar_for(:binary_id), do: Scalars.ID
  defp built_in_scalar_for(:string), do: Scalars.String
  defp built_in_scalar_for(:integer), do: Scalars.Integer
  defp built_in_scalar_for(:float), do: Scalars.Float
  defp built_in_scalar_for(:decimal), do: Scalars.Decimal
  defp built_in_scalar_for(:boolean), do: Scalars.Boolean
  defp built_in_scalar_for(:naive_datetime), do: Scalars.NaiveDateTime
  defp built_in_scalar_for(:utc_datetime), do: Scalars.DateTime
  defp built_in_scalar_for(:naive_datetime_usec), do: Scalars.NaiveDateTime
  defp built_in_scalar_for(:utc_datetime_usec), do: Scalars.DateTime
  defp built_in_scalar_for(:date), do: Scalars.Date
  defp built_in_scalar_for(:time), do: Scalars.Time
  defp built_in_scalar_for(:time_usec), do: Scalars.Time
  defp built_in_scalar_for(:datetime), do: Scalars.DateTime

  # Geo-spatial types
  defp built_in_scalar_for(:geometry), do: Scalars.Coordinates
  defp built_in_scalar_for(:geography), do: Scalars.Coordinates
  defp built_in_scalar_for(:coordinates), do: Scalars.Coordinates
  defp built_in_scalar_for(:geo_point), do: Scalars.Coordinates
  defp built_in_scalar_for(:location), do: Scalars.Coordinates

  # JSON/Map types
  defp built_in_scalar_for(:map), do: GreenFairy.BuiltIns.Scalars.JSON
  defp built_in_scalar_for({:map, _}), do: GreenFairy.BuiltIns.Scalars.JSON

  # Array type without inner type specified
  defp built_in_scalar_for(:array), do: nil

  # Array types
  defp built_in_scalar_for({:array, :string}), do: Scalars.ArrayString
  defp built_in_scalar_for({:array, :integer}), do: Scalars.ArrayInteger
  defp built_in_scalar_for({:array, :id}), do: Scalars.ArrayID
  defp built_in_scalar_for({:array, :binary_id}), do: Scalars.ArrayID
  defp built_in_scalar_for({:array, {:parameterized, Ecto.Enum, _}}), do: Scalars.ArrayEnum
  defp built_in_scalar_for({:array, _}), do: nil  # Unknown array types

  # Ecto.Enum (built-in parameterized enum type)
  defp built_in_scalar_for({:parameterized, Ecto.Enum, _}), do: Scalars.Enum

  # Embedded schemas not filterable
  defp built_in_scalar_for({:parameterized, Ecto.Embedded, _}), do: nil

  # EctoEnum library support (https://hexdocs.pm/ecto_enum)
  # EctoEnum types are modules that implement __enum_map__/0
  defp built_in_scalar_for(type_module) when is_atom(type_module) do
    if Code.ensure_loaded?(type_module) and function_exported?(type_module, :__enum_map__, 0) do
      Scalars.Enum
    else
      nil
    end
  end

  # Fallback for unknown types
  defp built_in_scalar_for(_), do: nil

  @doc """
  Returns the operator type identifier for an Ecto field type.

  Uses a default adapter since most scalars return the same identifier
  regardless of adapter. Use the 2-arity version if adapter-specific
  behavior is needed.

  ## Examples

      operator_type_identifier(:string)
      # => :cql_op_string_input

      operator_type_identifier({:array, :string})
      # => :cql_op_string_array_input

      # For GreenFairy enums, returns type-specific identifier:
      operator_type_identifier(:order_status)  # if :order_status is a GreenFairy enum
      # => :cql_enum_order_status_input
  """
  def operator_type_identifier(ecto_type) do
    operator_type_identifier(ecto_type, :postgres)
  end

  @doc """
  Returns the operator type identifier for an Ecto field type and adapter.

  This is used for GraphQL schema generation.

  ## Examples

      operator_type_identifier(:string, :postgres)
      # => :cql_op_string_input

      operator_type_identifier({:array, :string}, :postgres)
      # => :cql_op_string_array_input

      # For GreenFairy enums:
      operator_type_identifier(:order_status, :postgres)  # if :order_status is a GreenFairy enum
      # => :cql_enum_order_status_input
  """
  def operator_type_identifier(ecto_type, adapter) do
    # First check if it's a GreenFairy enum (type-specific operator input)
    cond do
      is_atom(ecto_type) and GreenFairy.TypeRegistry.is_enum?(ecto_type) ->
        GreenFairy.CQL.Schema.EnumOperatorInput.operator_type_identifier(ecto_type)

      is_gf_enum_array?(ecto_type) ->
        {:array, inner} = ecto_type
        GreenFairy.CQL.Schema.EnumOperatorInput.array_operator_type_identifier(inner)

      true ->
        # Standard scalar mapping
        case scalar_for(ecto_type) do
          nil ->
            # Fallback for unknown array types to generic array input
            case ecto_type do
              {:array, _inner_type} -> :cql_op_generic_array_input
              _ -> nil
            end
          scalar_module ->
            scalar_module.operator_type_identifier(adapter)
        end
    end
  end

  # Check if type is an array of a GreenFairy enum
  defp is_gf_enum_array?({:array, inner}) when is_atom(inner) do
    GreenFairy.TypeRegistry.is_enum?(inner)
  end
  defp is_gf_enum_array?(_), do: false

  @doc """
  Returns the operator input definition for an Ecto field type and adapter.

  ## Returns

  `{operators, scalar_type, description}` tuple or `nil` if not filterable.

  ## Examples

      operator_input(:string, :postgres)
      # => {[:_eq, :_neq, :_like, :_ilike, ...], :string, "String operators"}

      operator_input(:map, :postgres)
      # => nil
  """
  def operator_input(ecto_type, adapter) do
    case scalar_for(ecto_type) do
      nil -> nil
      scalar_module -> scalar_module.operator_input(adapter)
    end
  end
end
