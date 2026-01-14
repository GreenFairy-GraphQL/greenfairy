defmodule Absinthe.Object.Deferred.Compiler do
  @moduledoc """
  Compiles deferred type definitions into Absinthe schema notation.

  This is the core of the deferred resolution architecture. It:

  1. Loads all type definitions from registered modules
  2. Resolves module references to Absinthe type identifiers
  3. Generates Absinthe macro calls for each type
  4. Builds resolve_type functions from implementation registrations

  All of this happens at schema compile time, making the schema module
  the single point of dependency on all type modules.
  """

  alias Absinthe.Object.Deferred.Definition

  @doc """
  Compiles specific type modules into the body of a types module.

  Returns AST that can be placed inside a `defmodule` with `use Absinthe.Schema.Notation`.
  """
  def compile_types_module_body(modules) do
    definitions = Enum.map(modules, & &1.__absinthe_object_definition__())
    type_lookup = build_type_lookup_from_definitions(definitions)

    interface_implementors =
      definitions
      |> Enum.filter(&match?(%Definition.Object{}, &1))
      |> Enum.flat_map(fn obj ->
        Enum.map(obj.interfaces, fn iface -> {iface, obj} end)
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    interfaces =
      definitions
      |> Enum.filter(&match?(%Definition.Interface{}, &1))
      |> Enum.flat_map(&compile_interface(&1, type_lookup, interface_implementors))

    objects =
      definitions
      |> Enum.filter(&match?(%Definition.Object{}, &1))
      |> Enum.flat_map(&compile_object(&1, type_lookup))

    type_definitions = interfaces ++ objects

    quote do
      unquote_splicing(type_definitions)
    end
  end

  # Build a map of module -> identifier for type resolution from definitions
  defp build_type_lookup_from_definitions(definitions) do
    definitions
    |> Enum.map(fn def -> {def.module, def.identifier} end)
    |> Map.new()
  end

  defp compile_interface(%Definition.Interface{} = iface, type_lookup, interface_implementors) do
    identifier = iface.identifier
    implementors = Map.get(interface_implementors, iface.module, [])
    fields_ast = Enum.map(iface.fields, &compile_field(&1, type_lookup))

    # Build resolve_type from implementors - use the Registry approach
    type_map =
      implementors
      |> Enum.filter(& &1.struct)
      |> Enum.map(fn obj -> {obj.struct, obj.identifier} end)
      |> Map.new()
      |> Macro.escape()

    [
      quote do
        Absinthe.Schema.Notation.interface unquote(identifier) do
          unquote_splicing(fields_ast)

          resolve_type(fn
            %{__struct__: struct_module}, _ ->
              Map.get(unquote(type_map), struct_module)

            _, _ ->
              nil
          end)
        end
      end
    ]
  end

  defp compile_object(%Definition.Object{} = obj, type_lookup) do
    identifier = obj.identifier
    fields_ast = Enum.map(obj.fields, &compile_field(&1, type_lookup))

    interfaces_ast =
      Enum.map(obj.interfaces, fn iface_module ->
        iface_identifier = Map.get(type_lookup, iface_module, iface_module.__absinthe_object_identifier__())

        quote do
          Absinthe.Schema.Notation.interface(unquote(iface_identifier))
        end
      end)

    connections_ast = Enum.flat_map(obj.connections, &compile_connection(&1, type_lookup))

    object_ast =
      if obj.description do
        quote do
          @desc unquote(obj.description)
          Absinthe.Schema.Notation.object unquote(identifier) do
            unquote_splicing(interfaces_ast)
            unquote_splicing(fields_ast)
          end
        end
      else
        quote do
          Absinthe.Schema.Notation.object unquote(identifier) do
            unquote_splicing(interfaces_ast)
            unquote_splicing(fields_ast)
          end
        end
      end

    connections_ast ++ [object_ast]
  end

  # Compile a field definition into Absinthe AST
  defp compile_field(%Definition.Field{} = field, type_lookup) do
    type_ast = resolve_type_ref(field.type, type_lookup)

    base_field =
      if field.resolve do
        resolve_ast = compile_resolve(field.resolve)

        quote do
          field unquote(field.name), unquote(type_ast) do
            unquote(resolve_ast)
          end
        end
      else
        quote do
          field unquote(field.name), unquote(type_ast)
        end
      end

    base_field
  end

  # Resolve type references, converting module refs to identifiers
  defp resolve_type_ref({:non_null, inner}, type_lookup) do
    quote do: non_null(unquote(resolve_type_ref(inner, type_lookup)))
  end

  defp resolve_type_ref({:list, inner}, type_lookup) do
    quote do: list_of(unquote(resolve_type_ref(inner, type_lookup)))
  end

  defp resolve_type_ref({:module, module}, type_lookup) do
    Map.get(type_lookup, module, module.__absinthe_object_identifier__())
  end

  defp resolve_type_ref(atom, _type_lookup) when is_atom(atom) do
    atom
  end

  # Compile resolve functions
  defp compile_resolve({:dataloader, type_module, field_name, opts}) do
    quote do
      resolve(
        Absinthe.Object.Field.Dataloader.resolver(
          unquote(type_module),
          unquote(field_name),
          unquote(opts)
        )
      )
    end
  end

  defp compile_resolve(other), do: other

  # Compile connection definitions
  defp compile_connection(%Definition.Connection{} = conn, type_lookup) do
    edge_name = :"#{conn.field_name}_edge"
    connection_name = :"#{conn.field_name}_connection"

    node_type =
      case conn.node_type do
        module when is_atom(module) ->
          Map.get(type_lookup, module, module.__absinthe_object_identifier__())
      end

    edge_type =
      quote do
        Absinthe.Schema.Notation.object unquote(edge_name) do
          field(:node, unquote(node_type))
          field(:cursor, non_null(:string))
        end
      end

    connection_type =
      quote do
        Absinthe.Schema.Notation.object unquote(connection_name) do
          field(:edges, list_of(unquote(edge_name)))
          field(:page_info, non_null(:page_info))
        end
      end

    [edge_type, connection_type]
  end
end
