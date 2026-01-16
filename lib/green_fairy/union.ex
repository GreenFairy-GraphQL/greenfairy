defmodule GreenFairy.Union do
  @moduledoc """
  Defines a GraphQL union type with a clean DSL.

  ## Usage

      defmodule MyApp.GraphQL.Unions.SearchResult do
        use GreenFairy.Union

        union "SearchResult" do
          types [:user, :post, :comment]

          resolve_type fn
            %MyApp.User{}, _ -> :user
            %MyApp.Post{}, _ -> :post
            %MyApp.Comment{}, _ -> :comment
            _, _ -> nil
          end
        end
      end

  ## Options

  - `:description` - Description of the union type (can also use @desc)

  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Absinthe.Schema.Notation
      import Absinthe.Schema.Notation, except: [union: 2]

      import GreenFairy.Union, only: [union: 2, union: 3]

      Module.register_attribute(__MODULE__, :green_fairy_union, accumulate: false)
      Module.register_attribute(__MODULE__, :green_fairy_referenced_types, accumulate: true)

      @before_compile GreenFairy.Union
    end
  end

  @doc """
  Defines a GraphQL union type.

  ## Examples

      union "SearchResult" do
        types [:user, :post, :comment]

        resolve_type fn
          %MyApp.User{}, _ -> :user
          %MyApp.Post{}, _ -> :post
          _, _ -> nil
        end
      end

  """
  defmacro union(name, opts \\ [], do: block) do
    identifier = GreenFairy.Naming.to_identifier(name)

    # Extract member types from the block for graph discovery
    member_types = extract_member_types(block)

    quote do
      @green_fairy_union %{
        kind: :union,
        name: unquote(name),
        identifier: unquote(identifier),
        description: unquote(opts[:description])
      }

      # Track member type references for graph discovery
      unquote_splicing(
        Enum.map(member_types, fn type ->
          quote do
            @green_fairy_referenced_types unquote(type)
          end
        end)
      )

      @desc unquote(opts[:description])
      Absinthe.Schema.Notation.union unquote(identifier) do
        unquote(block)
      end
    end
  end

  # Extract member types from union block
  defp extract_member_types({:__block__, _, statements}) do
    Enum.flat_map(statements, &extract_types_from_statement/1)
  end

  defp extract_member_types(statement) do
    extract_types_from_statement(statement)
  end

  defp extract_types_from_statement({:types, _, [types_list]}) when is_list(types_list) do
    types_list
  end

  defp extract_types_from_statement(_), do: []

  @doc false
  defmacro __before_compile__(env) do
    union_def = Module.get_attribute(env.module, :green_fairy_union)

    quote do
      # Register this union in the TypeRegistry for graph-based discovery
      GreenFairy.TypeRegistry.register(
        unquote(union_def[:identifier]),
        __MODULE__
      )

      @doc false
      def __green_fairy_definition__ do
        %{
          kind: :union,
          name: unquote(union_def[:name]),
          identifier: unquote(union_def[:identifier])
        }
      end

      @doc false
      def __green_fairy_identifier__ do
        unquote(union_def[:identifier])
      end

      @doc false
      def __green_fairy_kind__ do
        :union
      end

      @doc false
      def __green_fairy_referenced_types__ do
        unquote(Macro.escape(Module.get_attribute(env.module, :green_fairy_referenced_types) || []))
      end
    end
  end
end
