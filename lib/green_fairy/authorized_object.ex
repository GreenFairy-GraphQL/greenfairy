defmodule GreenFairy.AuthorizedObject do
  @moduledoc """
  Internal wrapper for objects with field-level authorization applied.

  This struct wraps a source object and tracks which fields are visible
  to the current viewer. It's used internally by the authorization system
  to filter field access during resolution.

  ## Structure

      %AuthorizedObject{
        source: %User{id: 1, name: "John", ssn: "123-45-6789"},
        visible_fields: [:id, :name],
        all_visible: false
      }

  When `all_visible` is true, all fields are accessible without checking
  the `visible_fields` list.
  """

  @type t :: %__MODULE__{
          source: struct(),
          visible_fields: [atom()] | nil,
          all_visible: boolean(),
          on_unauthorized: :error | :return_nil
        }

  defstruct [:source, :visible_fields, all_visible: false, on_unauthorized: :error]

  @doc """
  Creates an AuthorizedObject from authorization result.

  ## Examples

      AuthorizedObject.new(user, :all)
      AuthorizedObject.new(user, :none)
      AuthorizedObject.new(user, [:id, :name])
      AuthorizedObject.new(user, :all, on_unauthorized: :return_nil)

  """
  def new(source, auth_result, opts \\ [])

  def new(source, :all, opts) do
    on_unauthorized = Keyword.get(opts, :on_unauthorized, :error)
    %__MODULE__{source: source, visible_fields: nil, all_visible: true, on_unauthorized: on_unauthorized}
  end

  def new(_source, :none, _opts) do
    nil
  end

  def new(source, visible_fields, opts) when is_list(visible_fields) do
    on_unauthorized = Keyword.get(opts, :on_unauthorized, :error)
    if visible_fields == [] do
      nil
    else
      %__MODULE__{source: source, visible_fields: visible_fields, all_visible: false, on_unauthorized: on_unauthorized}
    end
  end

  @doc """
  Checks if a field is visible.
  """
  def field_visible?(%__MODULE__{all_visible: true}, _field), do: true

  def field_visible?(%__MODULE__{visible_fields: fields}, field) do
    field in fields
  end

  @doc """
  Gets a field value if visible, returns `{:ok, value}` or `:hidden`.
  """
  def get_field(%__MODULE__{all_visible: true, source: source}, field) do
    {:ok, Map.get(source, field)}
  end

  def get_field(%__MODULE__{visible_fields: fields, source: source}, field) do
    if field in fields do
      {:ok, Map.get(source, field)}
    else
      :hidden
    end
  end

  @doc """
  Returns the list of visible fields.
  """
  def visible_fields(%__MODULE__{all_visible: true, source: source}) do
    source |> Map.from_struct() |> Map.keys()
  end

  def visible_fields(%__MODULE__{visible_fields: fields}) do
    fields
  end

  @doc """
  Unwraps to get the original source struct.
  """
  def unwrap(%__MODULE__{source: source}), do: source
  def unwrap(other), do: other
end
