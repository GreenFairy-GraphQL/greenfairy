defmodule GreenFairy.Authorization.FieldMiddleware do
  @moduledoc """
  Middleware that handles field-level authorization with support for on_unauthorized behavior.

  This middleware:
  1. Checks if the current user can access the field
  2. Respects @onUnauthorized directive from the client
  3. Falls back to field-level and type-level on_unauthorized configuration
  4. Returns nil or error based on the resolved behavior

  ## Behavior Priority (highest to lowest):
  1. Client `@onUnauthorized(behavior: ...)` directive
  2. Field-level `on_unauthorized:` option
  3. Type-level `on_unauthorized:` option
  4. AuthorizedObject's `on_unauthorized` setting
  5. Global default (`:error`)
  """

  @behaviour Absinthe.Middleware

  alias GreenFairy.AuthorizedObject

  @impl true
  def call(%{state: :resolved} = resolution, _config) do
    resolution
  end

  def call(%{state: :unresolved, source: source} = resolution, config) do
    field_name = resolution.definition.schema_node.identifier
    field_meta = resolution.definition.schema_node.meta

    # Determine the on_unauthorized behavior
    behavior = determine_behavior(field_meta, config, source)

    case check_field_access(source, field_name) do
      {:ok, value} ->
        # Field is accessible, resolve it
        %{resolution | state: :resolved, value: value}

      :unauthorized ->
        # Field is not accessible, apply behavior
        handle_unauthorized(resolution, behavior, field_name)
    end
  end

  # Check if field is accessible in the AuthorizedObject
  defp check_field_access(%AuthorizedObject{} = auth_obj, field_name) do
    case AuthorizedObject.get_field(auth_obj, field_name) do
      {:ok, value} -> {:ok, value}
      :hidden -> :unauthorized
    end
  end

  # Non-authorized objects - all fields accessible
  defp check_field_access(source, field_name) when is_map(source) or is_struct(source) do
    {:ok, Map.get(source, field_name)}
  end

  defp check_field_access(_source, _field_name) do
    :unauthorized
  end

  # Determine the on_unauthorized behavior from multiple sources
  defp determine_behavior(field_meta, config, source) do
    cond do
      # 1. Client directive (highest priority)
      directive_behavior = get_directive_behavior(field_meta) ->
        directive_behavior

      # 2. Field-level configuration
      field_behavior = get_in(config, [:on_unauthorized]) ->
        field_behavior

      # 3. Type-level configuration (passed in config)
      type_behavior = get_in(config, [:type_on_unauthorized]) ->
        type_behavior

      # 4. AuthorizedObject setting
      match?(%AuthorizedObject{}, source) ->
        source.on_unauthorized

      # 5. Global default
      true ->
        :error
    end
  end

  # Extract behavior from @onUnauthorized directive
  defp get_directive_behavior(meta) do
    case meta[:on_unauthorized] do
      :error -> :error
      :return_nil -> :return_nil
      nil -> nil
      _other -> nil
    end
  end

  # Handle unauthorized access based on behavior
  defp handle_unauthorized(resolution, :return_nil, _field_name) do
    # Return nil - query continues
    %{resolution | state: :resolved, value: nil}
  end

  defp handle_unauthorized(resolution, :error, field_name) do
    # Return error - stops propagation
    error = %{
      message: "Not authorized to access field '#{field_name}'",
      code: :unauthorized
    }
    Absinthe.Resolution.put_result(resolution, {:error, error})
  end
end
