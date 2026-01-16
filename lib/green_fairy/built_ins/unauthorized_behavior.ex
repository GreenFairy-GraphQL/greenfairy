defmodule GreenFairy.BuiltIns.UnauthorizedBehavior do
  @moduledoc """
  Defines the UnauthorizedBehavior enum for controlling how unauthorized field access is handled.

  ## Values

  - `ERROR` - Return an error when a field is not authorized (default)
  - `NIL` - Return nil when a field is not authorized

  ## Usage

  Can be used with the `@onUnauthorized` directive or configured at the type/field level.
  """

  use GreenFairy.Enum

  enum "UnauthorizedBehavior" do
    @desc "Return an error when unauthorized"
    value :error

    @desc "Return nil when unauthorized"
    value :return_nil
  end
end
