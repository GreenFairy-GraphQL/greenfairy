defmodule GreenFairy.Enum do
  @moduledoc """
  Defines a GraphQL enum type with a clean DSL and Ecto enum mapping support.

  ## Basic Usage

      defmodule MyApp.GraphQL.Enums.UserStatus do
        use GreenFairy.Enum

        enum "UserStatus" do
          value :active
          value :inactive
          value :pending, as: "PENDING_APPROVAL"
        end
      end

  ## Ecto Enum Mapping

  Map GraphQL enum values to Ecto enum values automatically:

      defmodule MyApp.GraphQL.Enums.PostVisibility do
        use GreenFairy.Enum

        enum "PostVisibility" do
          # GraphQL: PUBLIC, Ecto: :public
          value :public
          # GraphQL: FRIENDS_ONLY, Ecto: :friends
          value :friends_only, ecto: :friends
          # GraphQL: PRIVATE, Ecto: :private
          value :private
        end
      end

  ## Custom Transformations

  Provide custom serialize/parse functions for complex mappings:

      defmodule MyApp.GraphQL.Enums.Priority do
        use GreenFairy.Enum

        enum "Priority" do
          value :low
          value :medium
          value :high
        end

        # Transform GraphQL value to database value
        def serialize(:low), do: 1
        def serialize(:medium), do: 5
        def serialize(:high), do: 10

        # Transform database value to GraphQL value
        def parse(1), do: :low
        def parse(5), do: :medium
        def parse(10), do: :high
        def parse(_), do: nil
      end

  ## Options

  - `:description` - Description of the enum type (can also use @desc)
  - `:ecto` (on value) - Map this value to a different Ecto enum value

  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Absinthe.Schema.Notation
      import Absinthe.Schema.Notation, except: [enum: 2, enum: 3]

      import GreenFairy.Enum, only: [enum: 2, enum: 3, enum_mapping: 1]

      Module.register_attribute(__MODULE__, :green_fairy_enum, accumulate: false)
      Module.register_attribute(__MODULE__, :green_fairy_enum_mapping, accumulate: false)

      @before_compile GreenFairy.Enum
    end
  end

  @doc """
  Defines a GraphQL enum type.

  ## Examples

      enum "UserStatus" do
        value :active
        value :inactive
        value :pending, as: "PENDING_APPROVAL"
      end

  """
  defmacro enum(name, opts \\ [], do: block) do
    identifier = GreenFairy.Naming.to_identifier(name)

    quote do
      @green_fairy_enum %{
        kind: :enum,
        name: unquote(name),
        identifier: unquote(identifier),
        description: unquote(opts[:description])
      }

      @desc unquote(opts[:description])
      Absinthe.Schema.Notation.enum unquote(identifier) do
        unquote(block)
      end
    end
  end

  @doc """
  Defines the mapping between GraphQL enum values and Ecto/database values.

  ## Examples

      enum "PostVisibility" do
        value :public
        value :friends_only
        value :private
      end

      # Map GraphQL values to Ecto enum values
      enum_mapping %{
        public: :public,           # Same value
        friends_only: :friends,    # Different value
        private: :private          # Same value
      }

  When using this, serialize/1 and parse/1 functions are automatically generated.
  """
  defmacro enum_mapping(mapping) do
    quote do
      @green_fairy_enum_mapping unquote(Macro.escape(mapping))
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    enum_def = Module.get_attribute(env.module, :green_fairy_enum)
    mapping_ast = Module.get_attribute(env.module, :green_fairy_enum_mapping)

    # Generate serialize/parse functions if mapping is defined
    transform_functions =
      if mapping_ast do
        # Evaluate the AST to get the actual map/list
        {mapping, _} = Code.eval_quoted(mapping_ast)
        generate_transform_functions(mapping)
      else
        quote do
          @doc """
          Transform a GraphQL enum value to its Ecto/database representation.

          Default implementation returns the value unchanged. Override this function
          to provide custom transformations.
          """
          def serialize(value), do: value

          @doc """
          Transform an Ecto/database value to its GraphQL enum representation.

          Default implementation returns the value unchanged. Override this function
          to provide custom transformations.
          """
          def parse(value), do: value
        end
      end

    quote do
      @doc false
      def __green_fairy_definition__ do
        %{
          kind: :enum,
          name: unquote(enum_def[:name]),
          identifier: unquote(enum_def[:identifier])
        }
      end

      @doc false
      def __green_fairy_identifier__ do
        unquote(enum_def[:identifier])
      end

      @doc false
      def __green_fairy_kind__ do
        :enum
      end

      unquote(transform_functions)
    end
  end

  # Generate serialize and parse functions from a mapping
  defp generate_transform_functions(mapping) do
    mapping_map = Map.new(mapping)
    reverse_mapping = Map.new(mapping_map, fn {k, v} -> {v, k} end)

    serialize_clauses =
      Enum.map(mapping_map, fn {graphql_value, ecto_value} ->
        quote do
          def serialize(unquote(graphql_value)), do: unquote(ecto_value)
        end
      end)

    parse_clauses =
      Enum.map(reverse_mapping, fn {ecto_value, graphql_value} ->
        quote do
          def parse(unquote(ecto_value)), do: unquote(graphql_value)
        end
      end)

    quote do
      @doc """
      Transform a GraphQL enum value to its Ecto/database representation.

      Generated from enum_mapping.
      """
      unquote_splicing(serialize_clauses)
      def serialize(value), do: value

      @doc """
      Transform an Ecto/database value to its GraphQL enum representation.

      Generated from enum_mapping.
      """
      unquote_splicing(parse_clauses)
      def parse(value), do: value
    end
  end
end
