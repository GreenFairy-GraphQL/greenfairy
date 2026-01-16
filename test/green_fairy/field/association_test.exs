defmodule GreenFairy.Field.AssociationTest do
  use ExUnit.Case, async: true

  defmodule TestRepo do
    def all(queryable), do: []
    def get(queryable, id), do: nil
  end

  defmodule TestAuthor do
    use Ecto.Schema

    schema "authors" do
      field :name, :string
      has_many :posts, __MODULE__.TestPost
      has_one :profile, __MODULE__.TestProfile
    end
  end

  defmodule TestPost do
    use Ecto.Schema

    schema "posts" do
      field :title, :string
      belongs_to :author, __MODULE__.TestAuthor
      has_many :comments, __MODULE__.TestComment
    end
  end

  defmodule TestComment do
    use Ecto.Schema

    schema "comments" do
      field :body, :string
      belongs_to :post, __MODULE__.TestPost
      belongs_to :author, __MODULE__.TestAuthor
    end
  end

  defmodule TestProfile do
    use Ecto.Schema

    schema "profiles" do
      field :bio, :string
      belongs_to :author, __MODULE__.TestAuthor
    end
  end

  describe "assoc macro" do
    test "generates field AST for belongs_to association" do
      env = %Macro.Env{
        file: __ENV__.file,
        line: __ENV__.line
      }

      ast =
        GreenFairy.Field.Association.generate_assoc_field_ast(
          TestPost,
          :author,
          [],
          env
        )

      # Should generate a field with dataloader resolver
      assert {:field, [], [:author, type_identifier, opts]} = ast
      assert is_atom(type_identifier)
      assert [do: {:resolve, _, _}] = opts
    end

    test "generates field AST for has_many association with pagination" do
      env = %Macro.Env{
        file: __ENV__.file,
        line: __ENV__.line
      }

      ast =
        GreenFairy.Field.Association.generate_assoc_field_ast(
          TestPost,
          :comments,
          [],
          env
        )

      # Should generate a field with list_of and pagination args
      assert {:field, [], [:comments, {:list_of, [], [type_identifier]}, opts]} = ast
      assert is_atom(type_identifier)

      # Check that pagination args are present
      ast_string = Macro.to_string(ast)
      assert ast_string =~ "arg(:limit"
      assert ast_string =~ "arg(:offset"
      assert ast_string =~ "middleware"
    end

    test "generates field AST for has_one association" do
      env = %Macro.Env{
        file: __ENV__.file,
        line: __ENV__.line
      }

      ast =
        GreenFairy.Field.Association.generate_assoc_field_ast(
          TestAuthor,
          :profile,
          [],
          env
        )

      # Should generate a field with dataloader resolver
      assert {:field, [], [:profile, type_identifier, opts]} = ast
      assert is_atom(type_identifier)
      assert [do: {:resolve, _, _}] = opts
    end

    test "raises error for non-existent association" do
      env = %Macro.Env{
        file: __ENV__.file,
        line: __ENV__.line
      }

      assert_raise CompileError, ~r/no association :nonexistent/, fn ->
        GreenFairy.Field.Association.generate_assoc_field_ast(
          TestPost,
          :nonexistent,
          [],
          env
        )
      end
    end

    test "respects custom pagination options" do
      env = %Macro.Env{
        file: __ENV__.file,
        line: __ENV__.line
      }

      ast =
        GreenFairy.Field.Association.generate_assoc_field_ast(
          TestPost,
          :comments,
          [default_limit: 50, max_limit: 200],
          env
        )

      # Should have the custom limits in the AST
      ast_string = Macro.to_string(ast)
      assert ast_string =~ "50"
      assert ast_string =~ "200"
    end

    test "raises error for non-ecto module" do
      env = %Macro.Env{
        file: __ENV__.file,
        line: __ENV__.line
      }

      defmodule NonEctoModule do
        # Not an Ecto schema - no __schema__/2
      end

      assert_raise CompileError, ~r/not an Ecto schema/, fn ->
        GreenFairy.Field.Association.generate_assoc_field_ast(
          NonEctoModule,
          :something,
          [],
          env
        )
      end
    end
  end

  describe "get_type_identifier/1" do
    defmodule TypeWithIdentifier do
      def __green_fairy_identifier__, do: :custom_identifier
    end

    defmodule TypeWithoutIdentifier do
      # No __green_fairy_identifier__
    end

    test "returns identifier from module if available" do
      result = GreenFairy.Field.Association.get_type_identifier(TypeWithIdentifier)
      assert result == :custom_identifier
    end

    test "falls back to module name conversion" do
      result = GreenFairy.Field.Association.get_type_identifier(TypeWithoutIdentifier)
      assert result == :type_without_identifier
    end
  end
end
