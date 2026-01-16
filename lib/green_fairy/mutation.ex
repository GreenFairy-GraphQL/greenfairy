defmodule GreenFairy.Mutation do
  @moduledoc """
  Defines mutation fields in a dedicated module.

  ## Usage

      defmodule MyApp.GraphQL.Mutations.UserMutations do
        use GreenFairy.Mutation

        mutations do
          field :create_user, MyApp.GraphQL.Types.User do
            arg :input, MyApp.GraphQL.Inputs.CreateUserInput, null: false

            middleware MyApp.Middleware.Authenticate
            resolve &MyApp.Resolvers.User.create/3
          end

          field :update_user, MyApp.GraphQL.Types.User do
            arg :id, :id, null: false
            arg :input, MyApp.GraphQL.Inputs.UpdateUserInput, null: false

            resolve &MyApp.Resolvers.User.update/3
          end
        end
      end

  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Absinthe.Schema.Notation

      import GreenFairy.Mutation, only: [mutations: 1]

      Module.register_attribute(__MODULE__, :green_fairy_mutations, accumulate: false)
      Module.register_attribute(__MODULE__, :green_fairy_referenced_types, accumulate: true)

      @before_compile GreenFairy.Mutation
    end
  end

  @doc """
  Defines mutation fields.

  ## Examples

      mutations do
        field :create_user, :user do
          arg :input, :create_user_input, null: false
          resolve &Resolver.create_user/3
        end
      end

  """
  defmacro mutations(do: block) do
    # Extract type references from field definitions
    type_refs = extract_field_type_refs(block)

    quote do
      @green_fairy_mutations true

      # Track type references for graph discovery
      unquote_splicing(
        Enum.map(type_refs, fn type_ref ->
          quote do
            @green_fairy_referenced_types unquote(type_ref)
          end
        end)
      )

      # Store the block for later extraction by the schema
      def __green_fairy_mutation_fields__ do
        unquote(Macro.escape(block))
      end

      def __green_fairy_mutation_fields_identifier__ do
        :green_fairy_mutations
      end

      # Define mutations object that can be imported
      object :green_fairy_mutations do
        unquote(block)
      end
    end
  end

  # Extract type references from field statements in the block
  defp extract_field_type_refs({:__block__, _, statements}) do
    Enum.flat_map(statements, &extract_field_type_refs/1)
  end

  defp extract_field_type_refs({:field, _, args}) do
    # Field can be: [name, type] or [name, type, do: block]
    type_ref = extract_type_from_args(args)
    if type_ref, do: [type_ref], else: []
  end

  defp extract_field_type_refs(_), do: []

  defp extract_type_from_args([_name]), do: nil
  defp extract_type_from_args([_name, type]) when not is_list(type), do: unwrap_type_ref(type)
  defp extract_type_from_args([_name, type, _opts]) when not is_list(type), do: unwrap_type_ref(type)
  defp extract_type_from_args(_), do: nil

  defp unwrap_type_ref({:non_null, _, [inner]}), do: unwrap_type_ref(inner)
  defp unwrap_type_ref({:list_of, _, [inner]}), do: unwrap_type_ref(inner)
  defp unwrap_type_ref({:__aliases__, _, _} = module_ast), do: module_ast
  defp unwrap_type_ref(type) when is_atom(type), do: if(builtin?(type), do: nil, else: type)
  defp unwrap_type_ref(_), do: nil

  @builtins ~w(id string integer float boolean datetime date time naive_datetime decimal)a
  defp builtin?(type), do: type in @builtins

  @doc false
  defmacro __before_compile__(env) do
    has_mutations = Module.get_attribute(env.module, :green_fairy_mutations)

    quote do
      @doc false
      def __green_fairy_definition__ do
        %{
          kind: :mutations,
          has_mutations: unquote(has_mutations || false)
        }
      end

      @doc false
      def __green_fairy_kind__ do
        :mutations
      end

      @doc false
      def __green_fairy_referenced_types__ do
        unquote(Macro.escape(Module.get_attribute(env.module, :green_fairy_referenced_types) || []))
      end
    end
  end
end
