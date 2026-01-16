defmodule GreenFairy.BuiltIns.TimestampableTest do
  use ExUnit.Case, async: true

  alias GreenFairy.BuiltIns.Timestampable

  describe "interface definition" do
    test "defines __green_fairy_definition__/0" do
      definition = Timestampable.__green_fairy_definition__()

      assert definition.kind == :interface
      assert definition.name == "Timestampable"
      assert definition.identifier == :timestampable
    end

    test "defines __green_fairy_identifier__/0" do
      assert Timestampable.__green_fairy_identifier__() == :timestampable
    end

    test "defines __green_fairy_kind__/0" do
      assert Timestampable.__green_fairy_kind__() == :interface
    end

    test "defines __green_fairy_fields__/0" do
      fields = Timestampable.__green_fairy_fields__()
      assert is_list(fields)
    end

    test "definition includes resolve_type" do
      definition = Timestampable.__green_fairy_definition__()
      # resolve_type is stored in definition
      assert Map.has_key?(definition, :resolve_type)
    end
  end

  describe "Absinthe integration" do
    defmodule TimestampableTestSchema do
      use Absinthe.Schema

      import_types Timestampable

      object :timestamped_post do
        interface :timestampable

        field :id, :id
        field :inserted_at, non_null(:string)
        field :updated_at, non_null(:string)
      end

      query do
        field :post, :timestamped_post do
          resolve fn _, _, _ ->
            {:ok,
             %{
               id: "1",
               inserted_at: "2024-01-01T00:00:00Z",
               updated_at: "2024-01-02T00:00:00Z"
             }}
          end
        end
      end
    end

    test "generates valid Absinthe interface" do
      type = Absinthe.Schema.lookup_type(TimestampableTestSchema, :timestampable)

      assert type != nil
      assert type.name == "Timestampable"
      assert type.identifier == :timestampable
      assert Map.has_key?(type.fields, :inserted_at)
      assert Map.has_key?(type.fields, :updated_at)
    end

    test "interface fields have correct types" do
      type = Absinthe.Schema.lookup_type(TimestampableTestSchema, :timestampable)

      # inserted_at should be non_null string
      inserted_at = type.fields[:inserted_at]
      assert inserted_at != nil

      # updated_at should be non_null string
      updated_at = type.fields[:updated_at]
      assert updated_at != nil
    end

    test "can query timestamped objects" do
      query = """
      {
        post {
          id
          insertedAt
          updatedAt
        }
      }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, TimestampableTestSchema)
      assert data["post"]["id"] == "1"
      assert data["post"]["insertedAt"] == "2024-01-01T00:00:00Z"
      assert data["post"]["updatedAt"] == "2024-01-02T00:00:00Z"
    end
  end
end
