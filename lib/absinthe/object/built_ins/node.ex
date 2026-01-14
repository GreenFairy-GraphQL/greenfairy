defmodule Absinthe.Object.BuiltIns.Node do
  @moduledoc """
  Built-in Relay Node interface.

  This interface provides the standard Relay Global Object Identification
  pattern with a globally unique ID field.

  ## Usage

  Types can implement this interface:

      defmodule MyApp.GraphQL.Types.User do
        use Absinthe.Object.Type

        type "User", struct: MyApp.User do
          implements Absinthe.Object.BuiltIns.Node

          field :id, non_null(:id)
          field :email, :string
        end
      end

  """

  use Absinthe.Object.Interface

  interface "Node" do
    @desc "A globally unique identifier"
    field :id, non_null(:id)

    resolve_type fn
      %{__struct__: struct}, %{schema: schema} ->
        # Try to find the type that has this struct
        # This is a simple implementation - real apps might want custom logic
        find_type_for_struct(struct, schema)

      _, _ ->
        nil
    end
  end

  defp find_type_for_struct(struct, schema) do
    # Get all types from schema and find the one with matching struct
    schema.__absinthe_types__()
    |> Enum.find_value(fn {identifier, _} ->
      case Absinthe.Schema.lookup_type(schema, identifier) do
        %{identifier: id} = _type ->
          # Check if this type has a matching struct
          # This would need to be enhanced with actual struct tracking
          if has_struct_match?(schema, id, struct) do
            id
          end

        _ ->
          nil
      end
    end)
  end

  defp has_struct_match?(_schema, _identifier, _struct) do
    # Placeholder - would need access to struct mapping
    # In practice, this would be generated at compile time
    false
  end
end
