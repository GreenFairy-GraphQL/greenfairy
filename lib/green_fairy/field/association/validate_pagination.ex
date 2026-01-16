defmodule GreenFairy.Field.Association.ValidatePagination do
  @moduledoc """
  Middleware that validates pagination arguments (limit and offset).

  Enforces maximum limits to prevent resource exhaustion.
  """

  @behaviour Absinthe.Middleware

  @impl Absinthe.Middleware
  def call(%Absinthe.Resolution{arguments: args} = resolution, opts) do
    max_limit = Keyword.get(opts, :max_limit, 100)
    max_offset = Keyword.get(opts, :max_offset, 10_000)

    with :ok <- validate_limit(args[:limit], max_limit),
         :ok <- validate_offset(args[:offset], max_offset) do
      resolution
    else
      {:error, message} ->
        Absinthe.Resolution.put_result(resolution, {:error, message})
    end
  end

  defp validate_limit(nil, _max), do: :ok

  defp validate_limit(limit, max) when is_integer(limit) and limit > 0 and limit <= max do
    :ok
  end

  defp validate_limit(limit, max) when is_integer(limit) and limit > max do
    {:error, "limit cannot exceed #{max}"}
  end

  defp validate_limit(limit, _max) when is_integer(limit) do
    {:error, "limit must be greater than 0"}
  end

  defp validate_limit(_limit, _max) do
    {:error, "limit must be an integer"}
  end

  defp validate_offset(nil, _max), do: :ok

  defp validate_offset(offset, max) when is_integer(offset) and offset >= 0 and offset <= max do
    :ok
  end

  defp validate_offset(offset, max) when is_integer(offset) and offset > max do
    {:error, "offset cannot exceed #{max}"}
  end

  defp validate_offset(offset, _max) when is_integer(offset) do
    {:error, "offset must be greater than or equal to 0"}
  end

  defp validate_offset(_offset, _max) do
    {:error, "offset must be an integer"}
  end
end
