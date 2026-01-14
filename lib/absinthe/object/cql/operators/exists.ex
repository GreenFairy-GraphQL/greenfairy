defmodule Absinthe.Object.CQL.Operators.Exists do
  @moduledoc """
  The `_exists` operator for checking association existence.

  This operator is only valid in nested association filters and cannot
  be combined with other filter operators in the same filter object.

  ## Usage

  Check if an association exists:

      query {
        users(where: {
          organization: {_exists: true}
        }) {
          id
          name
        }
      }

  Check if an association does NOT exist:

      query {
        users(where: {
          organization: {_exists: false}
        }) {
          id
          name
        }
      }

  ## Combining with _or

  The `_exists` operator is useful with `_or` to find records with OR without
  certain associations:

      query {
        users(where: {
          _or: [
            {organization: {status: {_eq: "active"}}},
            {organization: {_exists: false}}
          ]
        }) {
          id
        }
      }

  ## Restrictions

  - `_exists` can ONLY be used within an association filter, not at the top level
  - `_exists` cannot be combined with other operators in the same filter object
  - `_exists` takes a boolean value (true = must exist, false = must not exist)
  """

  @doc """
  Checks if _exists is valid in the given context.

  Returns :ok if valid, or {:error, message} if invalid.
  """
  def validate_exists_usage(filter, opts \\ []) do
    has_exists? = Map.has_key?(filter, :_exists)
    is_nested? = Keyword.get(opts, :is_nested, false)
    only_exists? = map_size(filter) == 1

    cond do
      not has_exists? ->
        :ok

      has_exists? and is_nested? and only_exists? ->
        :ok

      not is_nested? ->
        {:error, "`_exists` can only be used in associated filters, not at the top level"}

      not only_exists? ->
        {:error, "`_exists` cannot be combined with other operators in the same filter object"}
    end
  end

  @doc """
  Checks if _exists is present as a direct member of a logical operator list.

  The `_exists` operator cannot be used directly inside `_or` or `_and` arrays.
  It must be wrapped in an association filter.

  ## Examples

  Invalid: `{_or: [{_exists: true}, {name: {_eq: "foo"}}]}`
  Valid: `{_or: [{organization: {_exists: true}}, {organization: {name: {_eq: "foo"}}}]}`
  """
  def validate_exists_in_logical_operator(filters, operator) when is_list(filters) do
    has_exists_directly? =
      Enum.any?(filters, fn filter ->
        is_map(filter) and Map.has_key?(filter, :_exists)
      end)

    if has_exists_directly? do
      {:error,
       "`_exists` cannot be used as a direct member of `#{operator}`. " <>
         "Instead, move `_exists` to its own separate association filter within the `#{operator}`."}
    else
      :ok
    end
  end
end
