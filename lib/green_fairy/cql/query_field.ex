defmodule GreenFairy.CQL.QueryField do
  @moduledoc """
  Represents a queryable field in a CQL type definition.

  This struct captures metadata about a field that can be filtered or
  ordered in CQL queries, including type information, custom constraints,
  and visibility settings.

  ## Fields

  - `:field` - The field name (atom)
  - `:field_type` - The field type (:string, :integer, :datetime, etc.)
  - `:column` - The database column name (defaults to field name)
  - `:description` - Field description for documentation
  - `:hidden` - If true, field is excluded from CQL queries
  - `:operators` - Custom list of allowed operators
  - `:custom_constraint` - Custom filter function
  - `:allow_in_nested` - Whether field can be used in nested filters

  ## Example

      %QueryField{
        field: :name,
        field_type: :string,
        description: "User's full name",
        operators: [:eq, :contains, :starts_with]
      }
  """

  @basic_types ~w[
    string
    integer
    float
    decimal
    boolean
    datetime
    date
    time
    id
    binary_id
    location
    geo_point
    money
    duration
  ]a

  @complex_types [
    {:array, :id},
    {:array, :string},
    {:array, :integer},
    {:array, :datetime}
  ]

  @valid_types @complex_types ++ @basic_types

  defstruct [
    :field,
    :field_type,
    :column,
    :description,
    :operators,
    :custom_constraint,
    hidden: false,
    allow_in_nested: true
  ]

  @type t :: %__MODULE__{
          field: atom(),
          field_type: atom() | tuple(),
          column: atom() | nil,
          description: String.t() | nil,
          hidden: boolean(),
          operators: [atom()] | nil,
          custom_constraint: function() | nil,
          allow_in_nested: boolean()
        }

  @doc """
  Creates a new QueryField.

  ## Options

  - `:field` - Required. The field name.
  - `:field_type` - Required. The field type.
  - `:column` - Database column name (defaults to field name).
  - `:description` - Field description.
  - `:hidden` - If true, excludes from CQL queries.
  - `:operators` - Custom list of allowed operators.
  - `:custom_constraint` - Custom filter function.
  - `:allow_in_nested` - Whether field can be used in nested filters.
  """
  def new(opts) do
    field = Keyword.fetch!(opts, :field)
    field_type = Keyword.fetch!(opts, :field_type)

    unless field_type in @valid_types do
      raise ArgumentError,
            "Invalid field_type #{inspect(field_type)}. Must be one of: #{inspect(@valid_types)}"
    end

    opts =
      opts
      |> Keyword.put_new(:column, field)
      |> Keyword.put_new(:hidden, false)
      |> Keyword.put_new(:allow_in_nested, true)

    struct!(__MODULE__, opts)
  end

  @doc """
  Returns the list of valid field types.
  """
  def valid_types, do: @valid_types

  @doc """
  Checks if a field can be used in nested filters.

  Fields with custom constraints cannot be used in nested filters
  by default, as the constraint function may depend on context.
  """
  def allowed_in_nested?(%__MODULE__{allow_in_nested: false}), do: false
  def allowed_in_nested?(%__MODULE__{custom_constraint: f}) when is_function(f), do: false
  def allowed_in_nested?(%__MODULE__{}), do: true

  @doc """
  Returns default operators for a field type.
  """
  def default_operators(:string), do: [:eq, :neq, :contains, :starts_with, :ends_with, :in, :is_nil]
  def default_operators(:integer), do: [:eq, :neq, :gt, :gte, :lt, :lte, :in, :is_nil]
  def default_operators(:float), do: [:eq, :neq, :gt, :gte, :lt, :lte, :in, :is_nil]
  def default_operators(:decimal), do: [:eq, :neq, :gt, :gte, :lt, :lte, :in, :is_nil]
  def default_operators(:boolean), do: [:eq, :neq, :is_nil]
  def default_operators(:datetime), do: [:eq, :neq, :gt, :gte, :lt, :lte, :is_nil, :between]
  def default_operators(:date), do: [:eq, :neq, :gt, :gte, :lt, :lte, :is_nil]
  def default_operators(:time), do: [:eq, :neq, :gt, :gte, :lt, :lte, :is_nil]
  def default_operators(:id), do: [:eq, :neq, :in, :is_nil]
  def default_operators(:binary_id), do: [:eq, :neq, :in, :is_nil]
  def default_operators(:location), do: [:eq, :neq, :is_nil, :st_dwithin, :st_within_bounding_box]
  def default_operators(:geo_point), do: [:eq, :neq, :is_nil, :st_dwithin, :st_within_bounding_box]
  def default_operators(:money), do: [:eq, :neq, :gt, :gte, :lt, :lte, :is_nil]
  def default_operators(:duration), do: [:eq, :neq, :gt, :gte, :lt, :lte, :is_nil]

  def default_operators({:array, _}),
    do: [:includes, :excludes, :includes_all, :excludes_all, :includes_any, :excludes_any, :is_empty]

  def default_operators(_), do: [:eq, :in, :is_nil]
end
