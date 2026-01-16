defmodule GreenFairy.CQL.InputOperators do
  @moduledoc """
  Defines CQL operator input types for filtering queries.

  These types provide typed operators that can be used in generated filter inputs.
  Based on Hasura's filtering operators.
  """

  use GreenFairy.Input

  # String operators
  input "CqlOpStringInput" do
    @desc "Equals"
    field :_eq, :string

    @desc "Not equals"
    field :_neq, :string

    @desc "Greater than"
    field :_gt, :string

    @desc "Greater than or equal"
    field :_gte, :string

    @desc "Less than"
    field :_lt, :string

    @desc "Less than or equal"
    field :_lte, :string

    @desc "Case-insensitive LIKE"
    field :_ilike, :string

    @desc "Case-sensitive LIKE"
    field :_like, :string

    @desc "Case-insensitive NOT LIKE"
    field :_nilike, :string

    @desc "Case-sensitive NOT LIKE"
    field :_nlike, :string

    @desc "In array"
    field :_in, list_of(:string)

    @desc "Not in array"
    field :_nin, list_of(:string)

    @desc "Is null"
    field :_is_null, :boolean
  end

  # Integer operators
  input "CqlOpIntegerInput" do
    @desc "Equals"
    field :_eq, :integer

    @desc "Not equals"
    field :_neq, :integer

    @desc "Greater than"
    field :_gt, :integer

    @desc "Greater than or equal"
    field :_gte, :integer

    @desc "Less than"
    field :_lt, :integer

    @desc "Less than or equal"
    field :_lte, :integer

    @desc "In array"
    field :_in, list_of(:integer)

    @desc "Not in array"
    field :_nin, list_of(:integer)

    @desc "Is null"
    field :_is_null, :boolean
  end

  # Float operators
  input "CqlOpFloatInput" do
    @desc "Equals"
    field :_eq, :float

    @desc "Not equals"
    field :_neq, :float

    @desc "Greater than"
    field :_gt, :float

    @desc "Greater than or equal"
    field :_gte, :float

    @desc "Less than"
    field :_lt, :float

    @desc "Less than or equal"
    field :_lte, :float

    @desc "In array"
    field :_in, list_of(:float)

    @desc "Not in array"
    field :_nin, list_of(:float)

    @desc "Is null"
    field :_is_null, :boolean
  end

  # Boolean operators
  input "CqlOpBooleanInput" do
    @desc "Equals"
    field :_eq, :boolean

    @desc "Not equals"
    field :_neq, :boolean

    @desc "Is null"
    field :_is_null, :boolean
  end

  # ID operators
  input "CqlOpIdInput" do
    @desc "Equals"
    field :_eq, :id

    @desc "Not equals"
    field :_neq, :id

    @desc "In array"
    field :_in, list_of(:id)

    @desc "Not in array"
    field :_nin, list_of(:id)

    @desc "Is null"
    field :_is_null, :boolean
  end

  # DateTime operators
  input "CqlOpDateTimeInput" do
    @desc "Equals"
    field :_eq, :datetime

    @desc "Not equals"
    field :_neq, :datetime

    @desc "Greater than"
    field :_gt, :datetime

    @desc "Greater than or equal"
    field :_gte, :datetime

    @desc "Less than"
    field :_lt, :datetime

    @desc "Less than or equal"
    field :_lte, :datetime

    @desc "In array"
    field :_in, list_of(:datetime)

    @desc "Not in array"
    field :_nin, list_of(:datetime)

    @desc "Is null"
    field :_is_null, :boolean
  end

  # Date operators
  input "CqlOpDateInput" do
    @desc "Equals"
    field :_eq, :date

    @desc "Not equals"
    field :_neq, :date

    @desc "Greater than"
    field :_gt, :date

    @desc "Greater than or equal"
    field :_gte, :date

    @desc "Less than"
    field :_lt, :date

    @desc "Less than or equal"
    field :_lte, :date

    @desc "In array"
    field :_in, list_of(:date)

    @desc "Not in array"
    field :_nin, list_of(:date)

    @desc "Is null"
    field :_is_null, :boolean
  end

  # Time operators
  input "CqlOpTimeInput" do
    @desc "Equals"
    field :_eq, :time

    @desc "Not equals"
    field :_neq, :time

    @desc "Greater than"
    field :_gt, :time

    @desc "Greater than or equal"
    field :_gte, :time

    @desc "Less than"
    field :_lt, :time

    @desc "Less than or equal"
    field :_lte, :time

    @desc "In array"
    field :_in, list_of(:time)

    @desc "Not in array"
    field :_nin, list_of(:time)

    @desc "Is null"
    field :_is_null, :boolean
  end

  # NaiveDateTime operators
  input "CqlOpNaiveDateTimeInput" do
    @desc "Equals"
    field :_eq, :naive_datetime

    @desc "Not equals"
    field :_neq, :naive_datetime

    @desc "Greater than"
    field :_gt, :naive_datetime

    @desc "Greater than or equal"
    field :_gte, :naive_datetime

    @desc "Less than"
    field :_lt, :naive_datetime

    @desc "Less than or equal"
    field :_lte, :naive_datetime

    @desc "In array"
    field :_in, list_of(:naive_datetime)

    @desc "Not in array"
    field :_nin, list_of(:naive_datetime)

    @desc "Is null"
    field :_is_null, :boolean
  end

  # Decimal operators
  input "CqlOpDecimalInput" do
    @desc "Equals"
    field :_eq, :decimal

    @desc "Not equals"
    field :_neq, :decimal

    @desc "Greater than"
    field :_gt, :decimal

    @desc "Greater than or equal"
    field :_gte, :decimal

    @desc "Less than"
    field :_lt, :decimal

    @desc "Less than or equal"
    field :_lte, :decimal

    @desc "In array"
    field :_in, list_of(:decimal)

    @desc "Not in array"
    field :_nin, list_of(:decimal)

    @desc "Is null"
    field :_is_null, :boolean
  end
end
