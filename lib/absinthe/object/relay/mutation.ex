defmodule Absinthe.Object.Relay.Mutation do
  @moduledoc """
  Relay-compliant mutation helpers with clientMutationId support.

  This module provides macros for defining Relay-style mutations that
  automatically handle the `clientMutationId` field.

  ## Usage

  Use `relay_mutation` instead of `field` for Relay-compliant mutations:

      defmodule MyApp.GraphQL.Mutations.UserMutations do
        use Absinthe.Object.Mutation
        import Absinthe.Object.Relay.Mutation

        mutations do
          relay_mutation :create_user do
            @desc "Creates a new user"

            input do
              field :email, non_null(:string)
              field :name, :string
            end

            output do
              field :user, :user
              field :errors, list_of(:string)
            end

            resolve fn input, ctx ->
              case MyApp.Accounts.create_user(input) do
                {:ok, user} -> {:ok, %{user: user}}
                {:error, changeset} -> {:ok, %{errors: format_errors(changeset)}}
              end
            end
          end
        end
      end

  This generates:
  - `CreateUserInput` input type with `clientMutationId` field
  - `CreateUserPayload` output type with `clientMutationId` field
  - Automatic passthrough of `clientMutationId` from input to output

  """

  @doc """
  Defines a Relay-compliant mutation with automatic clientMutationId handling.

  ## Options

  - `:input` - Block defining input fields (clientMutationId is added automatically)
  - `:output` - Block defining output fields (clientMutationId is added automatically)
  - `:resolve` - Resolver function

  """
  defmacro relay_mutation(name, do: block) do
    quote do
      require Absinthe.Object.Relay.Mutation
      Absinthe.Object.Relay.Mutation.__define_relay_mutation__(
        unquote(name),
        unquote(Macro.escape(block))
      )
    end
  end

  @doc false
  defmacro __define_relay_mutation__(name, block) do
    {input_block, output_block, resolve_fn, desc} = parse_mutation_block(block)

    input_type_name = mutation_input_name(name)
    payload_type_name = mutation_payload_name(name)

    quote do
      # Generate input type
      input_object unquote(input_type_name) do
        @desc "A unique identifier for the client performing the mutation"
        field :client_mutation_id, :string
        unquote(input_block)
      end

      # Generate payload type
      object unquote(payload_type_name) do
        @desc "A unique identifier for the client performing the mutation"
        field :client_mutation_id, :string
        unquote(output_block)
      end

      # Generate mutation field
      field unquote(name), unquote(payload_type_name) do
        unquote(if desc, do: quote(do: @desc unquote(desc)), else: nil)

        arg :input, non_null(unquote(input_type_name))

        resolve fn _, %{input: input}, resolution ->
          # Extract clientMutationId before calling resolver
          client_mutation_id = Map.get(input, :client_mutation_id)
          input_without_id = Map.delete(input, :client_mutation_id)

          # Call the user's resolver
          resolver = unquote(resolve_fn)

          case resolver.(input_without_id, resolution.context) do
            {:ok, result} when is_map(result) ->
              # Add clientMutationId to result
              {:ok, Map.put(result, :client_mutation_id, client_mutation_id)}

            {:error, _} = error ->
              error

            other ->
              other
          end
        end
      end
    end
  end

  # Parse the mutation block to extract input, output, resolve, and description
  defp parse_mutation_block({:__block__, _, statements}) do
    input_block = find_block(statements, :input)
    output_block = find_block(statements, :output)
    resolve_fn = find_resolve(statements)
    desc = find_desc(statements)
    {input_block, output_block, resolve_fn, desc}
  end

  defp parse_mutation_block(statement) do
    parse_mutation_block({:__block__, [], [statement]})
  end

  defp find_block(statements, type) do
    Enum.find_value(statements, fn
      {^type, _, [[do: block]]} -> block
      _ -> nil
    end)
  end

  defp find_resolve(statements) do
    Enum.find_value(statements, fn
      {:resolve, _, [fun]} -> fun
      _ -> nil
    end)
  end

  defp find_desc(statements) do
    Enum.find_value(statements, fn
      {:@, _, [{:desc, _, [desc]}]} -> desc
      _ -> nil
    end)
  end

  @doc """
  Converts a mutation name to its input type name.

  ## Examples

      iex> mutation_input_name(:create_user)
      :create_user_input

  """
  def mutation_input_name(name) do
    :"#{name}_input"
  end

  @doc """
  Converts a mutation name to its payload type name.

  ## Examples

      iex> mutation_payload_name(:create_user)
      :create_user_payload

  """
  def mutation_payload_name(name) do
    :"#{name}_payload"
  end

  defmodule ClientMutationId do
    @moduledoc """
    Middleware that automatically passes `clientMutationId` from input to output.

    Use this if you want to manually handle clientMutationId in custom mutations.

    ## Usage

        field :custom_mutation, :custom_payload do
          arg :input, non_null(:custom_input)
          middleware Absinthe.Object.Relay.Mutation.ClientMutationId
          resolve &MyResolver.custom/3
        end

    """

    @behaviour Absinthe.Middleware

    @impl true
    def call(%{arguments: %{input: input}} = resolution, _config) do
      client_mutation_id = Map.get(input, :client_mutation_id)

      %{resolution | private: Map.put(resolution.private, :client_mutation_id, client_mutation_id)}
    end

    def call(resolution, _config), do: resolution

    @doc """
    Adds clientMutationId to a result map.

    Call this in your resolver or use the after-resolution middleware.
    """
    def add_to_result(result, resolution) when is_map(result) do
      client_mutation_id = resolution.private[:client_mutation_id]
      Map.put(result, :client_mutation_id, client_mutation_id)
    end

    def add_to_result(result, _resolution), do: result
  end
end
