defmodule Absinthe.ObjectTest do
  use ExUnit.Case
  doctest Absinthe.Object

  describe "Absinthe.Object" do
    test "module exists" do
      assert Code.ensure_loaded?(Absinthe.Object)
    end
  end
end
