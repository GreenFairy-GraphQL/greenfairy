defmodule GreenFairy.Field.Association do
  @moduledoc """
  Macros for defining association fields with automatic DataLoader setup.

  ## Usage

      type "User", struct: MyApp.User do
        # Infers belongs_to from Ecto schema, returns single User
        assoc :organization

        # Infers has_many from Ecto schema, returns [Post] with limit/offset
        assoc :posts

        # Relay-style connection with cursor pagination
        connection :posts
      end

  ## Pagination Configuration

  Configure defaults and maximums in your config:

      config :green_fairy, :pagination,
        default_limit: 20,
        max_limit: 100,
        max_offset: 10000

  ## Association Inference

  The `assoc` macro automatically detects:
  - Association type (belongs_to, has_one, has_many, many_to_many)
  - Cardinality (:one or :many)
  - Related module

  For `:many` associations, it adds `limit` and `offset` arguments with
  validation middleware.
  """

  @doc """
  Generates field AST for an association at compile time.

  Called during AST transformation in GreenFairy.Type.
  """
  def generate_assoc_field_ast(struct_module, field_name, opts, env) do
    # Get association info from Ecto schema
    case get_association_info(struct_module, field_name) do
      {:ok, assoc_info} ->
        generate_field_ast(field_name, assoc_info, opts)

      {:error, reason} ->
        raise CompileError,
          file: env.file,
          line: env.line,
          description: "Cannot define assoc :#{field_name} - #{reason}"
    end
  end

  defp get_association_info(module, field_name) do
    # Ensure the module is compiled/loaded
    case Code.ensure_compiled(module) do
      {:module, ^module} ->
        if function_exported?(module, :__schema__, 2) do
          case module.__schema__(:association, field_name) do
            nil ->
              {:error, "no association #{inspect(field_name)} found on #{inspect(module)}"}

            %Ecto.Association.HasThrough{} = _assoc ->
              {:error,
               "has_through associations are not supported by assoc macro. " <>
                 "Use `field` with manual DataLoader resolver for :#{field_name}"}

            assoc ->
              {:ok,
               %{
                 cardinality: assoc.cardinality,
                 related: assoc.related,
                 field: field_name,
                 owner_key: assoc.owner_key,
                 related_key: get_related_key(assoc)
               }}
          end
        else
          {:error, "#{inspect(module)} is not an Ecto schema (no __schema__/2 function)"}
        end

      {:error, _reason} ->
        {:error, "#{inspect(module)} could not be compiled/loaded"}
    end
  end

  defp get_related_key(%{related_key: key}), do: key
  defp get_related_key(%{related: related}), do: hd(related.__schema__(:primary_key))

  defp generate_field_ast(field_name, %{cardinality: :one} = assoc_info, _opts) do
    # Single association - simple DataLoader
    type_identifier = get_type_identifier(assoc_info.related)

    quote do
      field unquote(field_name), unquote(type_identifier) do
        resolve Absinthe.Resolution.Helpers.dataloader(:repo)
      end
    end
  end

  defp generate_field_ast(field_name, %{cardinality: :many} = assoc_info, opts) do
    # List association - add limit/offset args
    type_identifier = get_type_identifier(assoc_info.related)

    default_limit = opts[:default_limit] || get_config(:default_limit, 20)
    max_limit = opts[:max_limit] || get_config(:max_limit, 100)
    max_offset = opts[:max_offset] || get_config(:max_offset, 10_000)

    quote do
      field unquote(field_name), list_of(unquote(type_identifier)) do
        arg :limit, :integer, default_value: unquote(default_limit)
        arg :offset, :integer, default_value: 0

        middleware GreenFairy.Field.Association.ValidatePagination,
          max_limit: unquote(max_limit),
          max_offset: unquote(max_offset)

        resolve Absinthe.Resolution.Helpers.dataloader(:repo)
      end
    end
  end

  @doc """
  Get the GraphQL type identifier for a module.

  Tries to call `__green_fairy_identifier__/0` if available,
  otherwise converts the module name to snake_case.

  ## Examples

      iex> get_type_identifier(MyApp.Accounts.User)
      :user

  """
  def get_type_identifier(module) do
    # Try to get the GraphQL type identifier from the module
    # This assumes the module has __green_fairy_identifier__/0
    if Code.ensure_loaded?(module) and function_exported?(module, :__green_fairy_identifier__, 0) do
      module.__green_fairy_identifier__()
    else
      # Fall back to converting module name to snake_case identifier
      module
      |> Module.split()
      |> List.last()
      |> Macro.underscore()
      |> String.to_atom()
    end
  end

  defp get_config(key, default) do
    Application.get_env(:green_fairy, :pagination, [])
    |> Keyword.get(key, default)
  end
end
