defmodule GreenFairy.Field.Loader do
  @moduledoc """
  Custom batch loading for fields.

  ## Design

  All fields use the `field` macro. Resolution is determined by:
  - **`resolve`** - Single-item resolver (receives one parent)
  - **`loader`** - Batch loader (receives list of parents)
  - **Default** - Adapter provides default (Map.get for scalars, DataLoader for associations)

  ## Custom Batch Loader

  Use `loader` within field blocks for custom batch loading:

      field :nearby_gigs, list_of(:gig) do
        arg :location, non_null(:point)  # Uses Geo.Point scalar
        arg :radius_meters, :integer, default_value: 1000

        loader fn workers, args, ctx ->
          # Receives LIST of parent objects
          # Returns map of parent => results OR list in same order as parents
          MyApp.Gigs.batch_load_nearby(workers, args.location, args.radius_meters)
        end
      end

  The loader function receives:
  - `parents` - List of parent objects being resolved (batched together)
  - `args` - The field arguments
  - `context` - The GraphQL context

  Must return either:
  - A map of `parent => result`
  - A list of results in the same order as parents

  ## Custom Resolver

  For single-item resolution, use Absinthe's `resolve`:

      field :full_name, :string do
        resolve fn user, _args, _ctx ->
          {:ok, "\#{user.first_name} \#{user.last_name}"}
        end
      end

  ## Mutual Exclusivity

  A field cannot have both `resolve` and `loader`. Use one or the other.

  """

  @doc """
  Defines a custom batch loader for relationship fields.

  The loader receives a list of parent objects and should return
  a map of `parent => result` or a list in the same order as parents.

  ## Inline Block Syntax (Recommended)

      field :friends, list_of(:user) do
        loader users, args, context do
          ids = Enum.map(users, & &1.id)

          Model.UserFriends
          |> where([uf], uf.left_id in ^ids or uf.right_id in ^ids)
          |> Repo.all()
          |> Enum.group_by(fn friendship ->
            Enum.find(users, &(&1.id == friendship.left_id or &1.id == friendship.right_id))
          end)
        end
      end

  ## Function Syntax

      field :posts, list_of(:post) do
        loader fn users, args, ctx ->
          MyApp.Posts.batch_load_for_users(users, args)
        end
      end

  ## Cross-Adapter Loading

      field :search_results, list_of(:result) do
        arg :query, non_null(:string)

        loader items, args, _ctx do
          # Load from Elasticsearch based on parent items
          ids = Enum.map(items, & &1.id)
          MyApp.Search.batch_search(ids, args.query)
        end
      end

  """
  # Inline block syntax: loader parents_var, args_var, context_var do ... end
  defmacro loader(parents_var, args_var, context_var, do: block) do
    quote do
      resolve fn parent, args, %{context: context} ->
        # Create an anonymous function from the inline block
        batch_fn = fn unquote(parents_var), unquote(args_var), unquote(context_var) ->
          unquote(block)
        end

        # Use Absinthe's batch helper for proper batching
        Absinthe.Resolution.Helpers.batch(
          {GreenFairy.Field.Loader, :__batch_loader__, [batch_fn, args, context]},
          parent,
          fn results ->
            {:ok, Map.get(results, parent)}
          end
        )
      end
    end
  end

  # Function syntax: loader fn parents, args, ctx -> ... end
  defmacro loader(func) do
    quote do
      resolve fn parent, args, %{context: context} ->
        batch_fn = unquote(func)

        # Use Absinthe's batch helper for proper batching
        Absinthe.Resolution.Helpers.batch(
          {GreenFairy.Field.Loader, :__batch_loader__, [batch_fn, args, context]},
          parent,
          fn results ->
            {:ok, Map.get(results, parent)}
          end
        )
      end
    end
  end

  @doc false
  def __batch_loader__(batch_fn, args, context, parents) do
    results =
      case :erlang.fun_info(batch_fn, :arity) do
        {:arity, 2} -> batch_fn.(parents, args)
        {:arity, 3} -> batch_fn.(parents, args, context)
        _ -> raise ArgumentError, "loader function must have arity 2 or 3"
      end

    # Convert results to a map keyed by parent if it's a list
    case results do
      %{} = map -> map
      list when is_list(list) -> Enum.zip(parents, list) |> Map.new()
      _ -> %{}
    end
  end
end
