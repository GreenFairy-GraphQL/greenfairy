defmodule GreenFairy.Interface do
  @moduledoc """
  Defines a GraphQL interface type with a clean DSL.

  ## Usage

      defmodule MyApp.GraphQL.Interfaces.Node do
        use GreenFairy.Interface

        interface "Node" do
          @desc "A globally unique identifier"
          field :id, :id, null: false
        end
      end

  The `resolve_type` function is automatically generated based on types that
  implement this interface using `implements/1`. Each implementing type must
  specify its backing struct via `type "Name", struct: Module`.

  ## Manual resolve_type

  You can override the auto-generated resolve_type if needed:

      interface "Node" do
        field :id, :id, null: false

        resolve_type fn
          %MyApp.User{} -> :user
          %MyApp.Post{} -> :post
          _ -> nil
        end
      end

  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Absinthe.Schema.Notation
      import Absinthe.Schema.Notation, except: [interface: 2, interface: 3]

      import GreenFairy.Interface, only: [interface: 2, interface: 3, visible: 1]

      Module.register_attribute(__MODULE__, :green_fairy_interface, accumulate: false)
      Module.register_attribute(__MODULE__, :green_fairy_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :green_fairy_resolve_type, accumulate: false)
      Module.register_attribute(__MODULE__, :green_fairy_visible_fn, accumulate: false)
      Module.register_attribute(__MODULE__, :green_fairy_field_visible, accumulate: true)

      @before_compile GreenFairy.Interface
    end
  end

  @doc """
  Controls whether this interface or its fields appear in introspection results.
  See `GreenFairy.Type.visible/1` for details.
  """
  defmacro visible(func) do
    quote do
      @green_fairy_visible_fn unquote(Macro.escape(func))
    end
  end

  @doc """
  Defines a GraphQL interface.

  If no `resolve_type` is provided, one will be auto-generated using
  the registry of types that implement this interface.

  ## Examples

      interface "Node" do
        field :id, :id, null: false
      end

  """
  defmacro interface(name, opts \\ [], do: block) do
    identifier = GreenFairy.Naming.to_identifier(name)
    interface_module = __CALLER__.module

    # Check if block contains a resolve_type call
    has_resolve_type = has_resolve_type?(block)

    # If no resolve_type provided, inject auto-generated one
    final_block =
      if has_resolve_type do
        block
      else
        inject_auto_resolve_type(block, interface_module)
      end

    quote do
      @green_fairy_interface %{
        kind: :interface,
        name: unquote(name),
        identifier: unquote(identifier),
        description: unquote(opts[:description])
      }

      @desc unquote(opts[:description])
      Absinthe.Schema.Notation.interface unquote(identifier) do
        meta :green_fairy_type_module, __MODULE__
        unquote(final_block)
      end
    end
  end

  # Check if block contains a resolve_type call
  defp has_resolve_type?({:__block__, _, statements}) do
    Enum.any?(statements, &resolve_type_statement?/1)
  end

  defp has_resolve_type?(statement), do: resolve_type_statement?(statement)

  defp resolve_type_statement?({:resolve_type, _, _}), do: true
  defp resolve_type_statement?(_), do: false

  # Inject auto resolve_type into the block
  defp inject_auto_resolve_type({:__block__, meta, statements}, interface_module) do
    auto_resolve =
      quote do
        resolve_type fn value, _ ->
          GreenFairy.Registry.resolve_type(value, unquote(interface_module))
        end
      end

    {:__block__, meta, statements ++ [auto_resolve]}
  end

  defp inject_auto_resolve_type(statement, interface_module) do
    auto_resolve =
      quote do
        resolve_type fn value, _ ->
          GreenFairy.Registry.resolve_type(value, unquote(interface_module))
        end
      end

    {:__block__, [], [statement, auto_resolve]}
  end

  @doc false
  defmacro __before_compile__(env) do
    interface_def = Module.get_attribute(env.module, :green_fairy_interface)
    fields_def = Module.get_attribute(env.module, :green_fairy_fields) || []
    resolve_type_def = Module.get_attribute(env.module, :green_fairy_resolve_type)
    visible_fn = Module.get_attribute(env.module, :green_fairy_visible_fn)
    field_visible_defs = Module.get_attribute(env.module, :green_fairy_field_visible) || []

    visibility_impl = generate_visibility_impl(visible_fn, field_visible_defs)

    quote do
      # Register this interface in the TypeRegistry for graph-based discovery
      GreenFairy.TypeRegistry.register(
        unquote(interface_def[:identifier]),
        __MODULE__
      )

      @doc false
      def __green_fairy_definition__ do
        %{
          kind: :interface,
          name: unquote(interface_def[:name]),
          identifier: unquote(interface_def[:identifier]),
          description: unquote(interface_def[:description]),
          fields: unquote(Macro.escape(Enum.reverse(fields_def))),
          resolve_type: unquote(Macro.escape(resolve_type_def))
        }
      end

      @doc false
      def __green_fairy_identifier__ do
        unquote(interface_def[:identifier])
      end

      @doc false
      def __green_fairy_kind__ do
        :interface
      end

      @doc false
      def __green_fairy_fields__ do
        unquote(Macro.escape(Enum.reverse(fields_def)))
      end

      # Visibility implementation
      unquote(visibility_impl)
    end
  end

  defp generate_visibility_impl(nil, []) do
    quote do
      @doc false
      def __type_visible__(_context), do: true

      @doc false
      def __field_visible__(_field_name, _context), do: true
    end
  end

  defp generate_visibility_impl(visible_fn, field_visible_defs) do
    type_visible =
      if visible_fn do
        quote do
          @doc false
          def __type_visible__(context) do
            !!(unquote(visible_fn)).(context)
          end
        end
      else
        quote do
          @doc false
          def __type_visible__(_context), do: true
        end
      end

    field_clauses =
      field_visible_defs
      |> Enum.reverse()
      |> Enum.map(fn {field_name, func} ->
        quote do
          def __field_visible__(unquote(field_name), context) do
            !!(unquote(func)).(context)
          end
        end
      end)

    fallback =
      quote do
        def __field_visible__(_field_name, _context), do: true
      end

    quote do
      unquote(type_visible)

      @doc false
      unquote_splicing(field_clauses)
      unquote(fallback)
    end
  end
end
