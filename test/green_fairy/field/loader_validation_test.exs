defmodule GreenFairy.Field.LoaderValidationTest do
  use ExUnit.Case, async: true

  describe "resolve and loader mutual exclusivity" do
    test "raises CompileError when field has both resolve and loader" do
      assert_raise CompileError, ~r/cannot have both `resolve` and `loader`/, fn ->
        defmodule InvalidBothResolveAndLoader do
          use GreenFairy.Type

          type "Invalid" do
            field :bad_field, :string do
              resolve fn _, _, _ -> {:ok, "from resolve"} end

              loader items, _args, _context do
                Map.new(items, fn item -> {item, "from loader"} end)
              end
            end
          end
        end
      end
    end

    test "allows field with only resolve" do
      defmodule ValidResolveOnly do
        use GreenFairy.Type

        type "ValidResolve" do
          field :good_field, :string do
            resolve fn _, _, _ -> {:ok, "from resolve"} end
          end
        end
      end

      assert function_exported?(ValidResolveOnly, :__green_fairy_definition__, 0)
    end

    test "allows field with only loader" do
      defmodule ValidLoaderOnly do
        use GreenFairy.Type

        type "ValidLoader" do
          field :good_field, :string do
            loader items, _args, _context do
              Map.new(items, fn item -> {item, "from loader"} end)
            end
          end
        end
      end

      assert function_exported?(ValidLoaderOnly, :__green_fairy_definition__, 0)
    end

    test "allows field with neither resolve nor loader" do
      defmodule ValidPlainField do
        use GreenFairy.Type

        type "ValidPlain" do
          field :good_field, :string
        end
      end

      assert function_exported?(ValidPlainField, :__green_fairy_definition__, 0)
    end

    test "raises with helpful error message including field name" do
      error =
        assert_raise CompileError, fn ->
          defmodule InvalidWithFieldName do
            use GreenFairy.Type

            type "Invalid" do
              field :problematic_field, :string do
                resolve fn _, _, _ -> {:ok, "resolve"} end
                loader items, _args, _ctx do
                  Map.new(items, fn item -> {item, "loader"} end)
                end
              end
            end
          end
        end

      assert error.description =~ "problematic_field"
      assert error.description =~ "mutually exclusive"
      assert error.description =~ "Use `resolve` for single-item resolution"
      assert error.description =~ "Use `loader` for batch loading"
    end

    test "allows field with resolve and other statements" do
      defmodule ValidResolveWithArg do
        use GreenFairy.Type

        type "ValidWithArg" do
          field :good_field, :string do
            arg :input, :string
            resolve fn _, _, _ -> {:ok, "resolve"} end
          end
        end
      end

      assert function_exported?(ValidResolveWithArg, :__green_fairy_definition__, 0)
    end

    test "allows field with loader and other statements" do
      defmodule ValidLoaderWithArg do
        use GreenFairy.Type

        type "ValidWithArg" do
          field :good_field, :string do
            arg :input, :string

            loader items, _args, _context do
              Map.new(items, fn item -> {item, "loader"} end)
            end
          end
        end
      end

      assert function_exported?(ValidLoaderWithArg, :__green_fairy_definition__, 0)
    end

    test "raises when loader comes before resolve" do
      assert_raise CompileError, ~r/cannot have both/, fn ->
        defmodule InvalidLoaderBeforeResolve do
          use GreenFairy.Type

          type "Invalid" do
            field :bad_field, :string do
              loader items, _args, _context do
                Map.new(items, fn item -> {item, "loader"} end)
              end

              resolve fn _, _, _ -> {:ok, "resolve"} end
            end
          end
        end
      end
    end

    test "allows function syntax for loader" do
      defmodule ValidLoaderFunctionSyntax do
        use GreenFairy.Type

        type "ValidFunction" do
          field :good_field, :string do
            loader fn items, _args, _context ->
              Map.new(items, fn item -> {item, "loader"} end)
            end
          end
        end
      end

      assert function_exported?(ValidLoaderFunctionSyntax, :__green_fairy_definition__, 0)
    end

    test "raises when using both resolve and function syntax loader" do
      assert_raise CompileError, ~r/cannot have both/, fn ->
        defmodule InvalidResolveAndFunctionLoader do
          use GreenFairy.Type

          type "Invalid" do
            field :bad_field, :string do
              resolve fn _, _, _ -> {:ok, "resolve"} end

              loader fn items, _args, _context ->
                Map.new(items, fn item -> {item, "loader"} end)
              end
            end
          end
        end
      end
    end
  end
end
