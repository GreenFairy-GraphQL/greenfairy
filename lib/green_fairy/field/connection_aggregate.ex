defmodule GreenFairy.Field.ConnectionAggregate do
  @moduledoc """
  Support for aggregate operations in connections (sum, avg, min, max).

  ## Usage

      connection :engagements, node_type: :engagement do
        arg :where, :cql_filter_engagement_input

        aggregate do
          sum [:hours_worked, :total_pay]
          avg [:hours_worked, :hourly_rate]
          min [:start_time]
          max [:end_time]
        end

        resolve dataloader(Repo, :engagements)
      end

  ## Generated Types

  For each connection with aggregates, generates:
  - `{Type}Aggregate` - Main aggregate type with sum/avg/min/max fields
  - `{Type}SumAggregates` - Sum aggregate fields
  - `{Type}AvgAggregates` - Average aggregate fields
  - `{Type}MinAggregates` - Minimum aggregate fields
  - `{Type}MaxAggregates` - Maximum aggregate fields

  ## Example Schema

      type EngagementAggregate {
        sum: EngagementSumAggregates
        avg: EngagementAvgAggregates
        min: EngagementMinAggregates
        max: EngagementMaxAggregates
      }

      type EngagementSumAggregates {
        hoursWorked: Float
        totalPay: Float
      }
  """

  @doc """
  Macro to define aggregations in a connection.

  ## Examples

      aggregate do
        sum [:hours_worked, :total_pay]
        avg [:hours_worked, :hourly_rate]
        min [:start_time]
        max [:end_time]
      end
  """
  defmacro aggregate(do: block) do
    # Parse the block to extract sum/avg/min/max field lists
    aggregates = parse_aggregate_block(block)

    quote do
      # Store aggregate configuration
      @green_fairy_current_connection_aggregates unquote(Macro.escape(aggregates))
    end
  end

  @doc """
  Defines sum aggregate fields.
  """
  defmacro sum(fields) when is_list(fields) do
    quote do
      {:sum, unquote(fields)}
    end
  end

  @doc """
  Defines average aggregate fields.
  """
  defmacro avg(fields) when is_list(fields) do
    quote do
      {:avg, unquote(fields)}
    end
  end

  @doc """
  Defines minimum aggregate fields.
  """
  defmacro min(fields) when is_list(fields) do
    quote do
      {:min, unquote(fields)}
    end
  end

  @doc """
  Defines maximum aggregate fields.
  """
  defmacro max(fields) when is_list(fields) do
    quote do
      {:max, unquote(fields)}
    end
  end

  @doc false
  def parse_aggregate_block({:__block__, _, statements}) do
    Enum.reduce(statements, %{sum: [], avg: [], min: [], max: []}, fn
      {:sum, _, [fields]}, acc when is_list(fields) ->
        %{acc | sum: fields}

      {:avg, _, [fields]}, acc when is_list(fields) ->
        %{acc | avg: fields}

      {:min, _, [fields]}, acc when is_list(fields) ->
        %{acc | min: fields}

      {:max, _, [fields]}, acc when is_list(fields) ->
        %{acc | max: fields}

      _other, acc ->
        acc
    end)
  end

  def parse_aggregate_block({op, _, [fields]}) when op in [:sum, :avg, :min, :max] and is_list(fields) do
    %{sum: [], avg: [], min: [], max: []}
    |> Map.put(op, fields)
  end

  def parse_aggregate_block(_), do: nil

  @doc """
  Generates aggregate type definitions for a connection.

  Called from __before_compile__ to generate aggregate types.
  """
  def generate_aggregate_types(_connection_name, type_name, aggregates) do
    return_type = :"#{type_name}_aggregate"
    sum_type = :"#{type_name}_sum_aggregates"
    avg_type = :"#{type_name}_avg_aggregates"
    min_type = :"#{type_name}_min_aggregates"
    max_type = :"#{type_name}_max_aggregates"

    types = []

    # Generate sum aggregates type if sum fields present
    types = if Enum.any?(aggregates.sum) do
      [generate_sum_type(sum_type, aggregates.sum) | types]
    else
      types
    end

    # Generate avg aggregates type if avg fields present
    types = if Enum.any?(aggregates.avg) do
      [generate_avg_type(avg_type, aggregates.avg) | types]
    else
      types
    end

    # Generate min aggregates type if min fields present
    types = if Enum.any?(aggregates.min) do
      [generate_min_type(min_type, aggregates.min) | types]
    else
      types
    end

    # Generate max aggregates type if max fields present
    types = if Enum.any?(aggregates.max) do
      [generate_max_type(max_type, aggregates.max) | types]
    else
      types
    end

    # Generate main aggregate type
    main_type = generate_main_aggregate_type(
      return_type,
      aggregates,
      sum_type,
      avg_type,
      min_type,
      max_type
    )

    [main_type | types]
  end

  defp generate_sum_type(type_name, fields) do
    quote do
      Absinthe.Schema.Notation.object unquote(type_name) do
        @desc "Sum aggregates"
        unquote_splicing(generate_aggregate_fields(fields, :float))
      end
    end
  end

  defp generate_avg_type(type_name, fields) do
    quote do
      Absinthe.Schema.Notation.object unquote(type_name) do
        @desc "Average aggregates"
        unquote_splicing(generate_aggregate_fields(fields, :float))
      end
    end
  end

  defp generate_min_type(type_name, fields) do
    quote do
      Absinthe.Schema.Notation.object unquote(type_name) do
        @desc "Minimum value aggregates"
        unquote_splicing(generate_aggregate_fields(fields, :string))
      end
    end
  end

  defp generate_max_type(type_name, fields) do
    quote do
      Absinthe.Schema.Notation.object unquote(type_name) do
        @desc "Maximum value aggregates"
        unquote_splicing(generate_aggregate_fields(fields, :string))
      end
    end
  end

  defp generate_aggregate_fields(fields, default_type) do
    Enum.map(fields, fn field ->
      # Convert snake_case to camelCase for GraphQL
      graphql_name = field |> Atom.to_string() |> Absinthe.Utils.camelize(lower: true) |> String.to_atom()

      quote do
        field(unquote(graphql_name), unquote(default_type))
      end
    end)
  end

  defp generate_main_aggregate_type(type_name, aggregates, sum_type, avg_type, min_type, max_type) do
    fields = []

    fields = if Enum.any?(aggregates.sum) do
      [quote(do: field(:sum, unquote(sum_type))) | fields]
    else
      fields
    end

    fields = if Enum.any?(aggregates.avg) do
      [quote(do: field(:avg, unquote(avg_type))) | fields]
    else
      fields
    end

    fields = if Enum.any?(aggregates.min) do
      [quote(do: field(:min, unquote(min_type))) | fields]
    else
      fields
    end

    fields = if Enum.any?(aggregates.max) do
      [quote(do: field(:max, unquote(max_type))) | fields]
    else
      fields
    end

    quote do
      Absinthe.Schema.Notation.object unquote(type_name) do
        @desc "Aggregates for connection"
        unquote_splicing(fields)
      end
    end
  end

  @doc """
  Computes aggregates from an Ecto query.

  ## Options

  - `:repo` - Ecto repo to use
  - `:aggregates` - Aggregate configuration map
  - `:deferred` - Whether to defer computation (default: true)

  ## Returns

  Map with aggregate results or functions for deferred loading:
  - `sum` - Map of field => sum
  - `avg` - Map of field => average
  - `min` - Map of field => minimum
  - `max` - Map of field => maximum
  """
  def compute_aggregates(query, opts \\ []) do
    repo = Keyword.fetch!(opts, :repo)
    aggregates = Keyword.fetch!(opts, :aggregates)
    deferred = Keyword.get(opts, :deferred, true)

    if deferred do
      # Return functions for deferred computation
      compute_deferred_aggregates(query, repo, aggregates)
    else
      # Compute now
      compute_eager_aggregates(query, repo, aggregates)
    end
  end

  defp compute_deferred_aggregates(query, repo, aggregates) do
    import Ecto.Query, only: [exclude: 2]

    result = %{}

    # Sum aggregates
    result = if Enum.any?(aggregates.sum) do
      sum_map = Map.new(aggregates.sum, fn field ->
        sum_fn = fn ->
          query
          |> exclude(:preload)
          |> exclude(:order_by)
          |> repo.aggregate(:sum, field)
        end
        {field, sum_fn}
      end)
      Map.put(result, :_sum_fns, sum_map)
    else
      result
    end

    # Avg aggregates
    result = if Enum.any?(aggregates.avg) do
      avg_map = Map.new(aggregates.avg, fn field ->
        avg_fn = fn ->
          query
          |> exclude(:preload)
          |> exclude(:order_by)
          |> repo.aggregate(:avg, field)
        end
        {field, avg_fn}
      end)
      Map.put(result, :_avg_fns, avg_map)
    else
      result
    end

    # Min aggregates
    result = if Enum.any?(aggregates.min) do
      min_map = Map.new(aggregates.min, fn field ->
        min_fn = fn ->
          query
          |> exclude(:preload)
          |> exclude(:order_by)
          |> repo.aggregate(:min, field)
        end
        {field, min_fn}
      end)
      Map.put(result, :_min_fns, min_map)
    else
      result
    end

    # Max aggregates
    result = if Enum.any?(aggregates.max) do
      max_map = Map.new(aggregates.max, fn field ->
        max_fn = fn ->
          query
          |> exclude(:preload)
          |> exclude(:order_by)
          |> repo.aggregate(:max, field)
        end
        {field, max_fn}
      end)
      Map.put(result, :_max_fns, max_map)
    else
      result
    end

    result
  end

  defp compute_eager_aggregates(query, repo, aggregates) do
    import Ecto.Query, only: [exclude: 2]

    base_query = query |> exclude(:preload) |> exclude(:order_by)

    result = %{}

    # Compute sum
    result = if Enum.any?(aggregates.sum) do
      sum_map = Map.new(aggregates.sum, fn field ->
        {field, repo.aggregate(base_query, :sum, field)}
      end)
      Map.put(result, :sum, sum_map)
    else
      result
    end

    # Compute avg
    result = if Enum.any?(aggregates.avg) do
      avg_map = Map.new(aggregates.avg, fn field ->
        {field, repo.aggregate(base_query, :avg, field)}
      end)
      Map.put(result, :avg, avg_map)
    else
      result
    end

    # Compute min
    result = if Enum.any?(aggregates.min) do
      min_map = Map.new(aggregates.min, fn field ->
        {field, repo.aggregate(base_query, :min, field)}
      end)
      Map.put(result, :min, min_map)
    else
      result
    end

    # Compute max
    result = if Enum.any?(aggregates.max) do
      max_map = Map.new(aggregates.max, fn field ->
        {field, repo.aggregate(base_query, :max, field)}
      end)
      Map.put(result, :max, max_map)
    else
      result
    end

    result
  end

  @doc """
  Resolves aggregate field with deferred loading.

  Called by aggregate field resolvers to execute deferred aggregate computations.
  """
  def resolve_aggregate_field(parent, field_map_key, field_name) do
    case parent do
      # Deferred loading - execute function
      %{^field_map_key => field_map} when is_map(field_map) ->
        case Map.get(field_map, field_name) do
          fn_value when is_function(fn_value, 0) -> {:ok, fn_value.()}
          value -> {:ok, value}
        end

      # No aggregate data
      _ ->
        {:ok, nil}
    end
  end
end
