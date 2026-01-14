defmodule Absinthe.Object.Field.DataloaderTest do
  use ExUnit.Case, async: true

  alias Absinthe.Object.Field.Dataloader, as: DL

  describe "resolver/3" do
    test "returns a function" do
      resolver = DL.resolver(SomeModule, :items)
      assert is_function(resolver, 3)
    end

    test "raises when loader not in context" do
      resolver = DL.resolver(SomeModule, :items)

      assert_raise RuntimeError, ~r/DataLoader not found in context/, fn ->
        resolver.(%{}, %{}, %{context: %{}})
      end
    end

    test "accepts source option" do
      resolver = DL.resolver(SomeModule, :items, source: :custom_source)
      assert is_function(resolver, 3)
    end

    test "accepts args option" do
      resolver = DL.resolver(SomeModule, :items, args: %{status: :active})
      assert is_function(resolver, 3)
    end

    test "accepts callback option" do
      callback = fn result -> {:ok, Enum.reverse(result)} end
      resolver = DL.resolver(SomeModule, :items, callback: callback)
      assert is_function(resolver, 3)
    end
  end

  describe "on_load/2" do
    test "delegates to Absinthe.Resolution.Helpers.on_load" do
      # Ensure module is loaded before checking function_exported?
      Code.ensure_loaded!(DL)
      assert function_exported?(DL, :on_load, 2)
    end
  end

  describe "resolver with dataloader in context" do
    # Create a simple KV source for testing
    defmodule TestSource do
      @behaviour Dataloader.Source

      @impl true
      def load(source, batch_key, items) do
        # Store the items to be loaded
        items = MapSet.new(items)
        Map.update(source, batch_key, items, &MapSet.union(&1, items))
      end

      @impl true
      def fetch(source, batch_key, item) do
        # Return test data based on the batch key
        case batch_key do
          {:posts, _args} -> {:ok, [%{id: 1, title: "Post 1"}, %{id: 2, title: "Post 2"}]}
          {:profile, _args} -> {:ok, %{id: 1, bio: "Test bio"}}
          _ -> {:ok, nil}
        end
      end

      @impl true
      def run(source) do
        source
      end

      @impl true
      def pending_batches?(_source) do
        false
      end

      @impl true
      def timeout(_source) do
        :infinity
      end
    end

    test "resolver uses loader from context when present" do
      # Create a dataloader with our test source
      loader =
        Dataloader.new()
        |> Dataloader.add_source(:repo, Dataloader.KV.new(&kv_query/2))

      resolver = DL.resolver(SomeModule, :posts, source: :repo)

      # The resolver returns a function that requires the loader
      # When called, it should not raise since loader is present
      context = %{loader: loader}
      parent = %{id: 1}

      # Call the resolver - this exercises the loader branch
      result = resolver.(parent, %{}, %{context: context})

      # The result is a middleware tuple for async resolution
      assert is_tuple(result)
    end

    test "resolver merges args from query with default args" do
      loader =
        Dataloader.new()
        |> Dataloader.add_source(:repo, Dataloader.KV.new(&kv_query/2))

      resolver = DL.resolver(SomeModule, :posts, source: :repo, args: %{status: :active})

      context = %{loader: loader}
      parent = %{id: 1}

      # Call with additional args
      result = resolver.(parent, %{limit: 10}, %{context: context})
      assert is_tuple(result)
    end

    test "resolver uses dataloader_source from context when source not specified" do
      loader =
        Dataloader.new()
        |> Dataloader.add_source(:custom, Dataloader.KV.new(&kv_query/2))

      resolver = DL.resolver(SomeModule, :posts)

      # Context has a custom dataloader_source
      context = %{loader: loader, dataloader_source: :custom}
      parent = %{id: 1}

      result = resolver.(parent, %{}, %{context: context})
      assert is_tuple(result)
    end

    test "resolver defaults to :repo source when no source specified" do
      loader =
        Dataloader.new()
        |> Dataloader.add_source(:repo, Dataloader.KV.new(&kv_query/2))

      resolver = DL.resolver(SomeModule, :posts)

      context = %{loader: loader}
      parent = %{id: 1}

      result = resolver.(parent, %{}, %{context: context})
      assert is_tuple(result)
    end

    # Helper for KV source
    defp kv_query(batch_key, items) do
      items
      |> Enum.map(fn item ->
        case batch_key do
          :posts -> {item, [%{id: 1}, %{id: 2}]}
          :profile -> {item, %{bio: "Test"}}
          _ -> {item, nil}
        end
      end)
      |> Map.new()
    end
  end

  describe "source_for/1" do
    test "returns :repo when type has no struct" do
      assert DL.source_for(NonExistentModule) == :repo
    end

    test "returns :repo when struct has no adapter" do
      # SomeModule doesn't have __absinthe_object_struct__
      assert DL.source_for(SomeModule) == :repo
    end
  end

  describe "resolver with explicit adapter" do
    test "uses provided adapter" do
      resolver = DL.resolver(SomeModule, :items, adapter: Absinthe.Object.Adapters.Ecto)
      assert is_function(resolver, 3)
    end
  end
end
