defmodule GreenFairy.Introspection do
  @moduledoc """
  Helpers for introspection visibility filtering.

  ## How visibility filtering is applied

  GreenFairy uses a custom Absinthe phase (`GreenFairy.Introspection.FilterPhase`)
  to filter introspection results. This phase is added to the pipeline via
  the schema's `pipeline/2` callback.

  ### With Absinthe.Plug (production)

  `Absinthe.Plug` calls `schema.pipeline/2`, so filtering works automatically.

  ### With Absinthe.run (tests)

  `Absinthe.run/3` does NOT call `schema.pipeline/2`. Use either:

  1. The generated `MySchema.run/2` helper (recommended):

      {:ok, result} = MySchema.run("{ __type(name: \\"User\\") { fields { name } } }",
        context: %{current_user: admin}
      )

  2. Or pass a `pipeline_modifier`:

      Absinthe.run(query, MySchema,
        context: ctx,
        pipeline_modifier: &GreenFairy.Introspection.pipeline_modifier/2
      )

  ## Custom middleware override

  If you override `pipeline/2` in your schema, include the filter phase:

      def pipeline(config, opts) do
        super(config, opts)
        |> GreenFairy.Introspection.add_filter_phase()
      end

  """

  alias GreenFairy.Introspection.FilterPhase

  @doc """
  Adds the visibility filter phase to an Absinthe pipeline.

  Use this when overriding `pipeline/2` in your schema.
  """
  def add_filter_phase(pipeline) do
    Absinthe.Pipeline.insert_after(pipeline, Absinthe.Phase.Document.Result, FilterPhase)
  end

  @doc """
  Pipeline modifier function for use with `Absinthe.run/3`.

      Absinthe.run(query, MySchema,
        pipeline_modifier: &GreenFairy.Introspection.pipeline_modifier/2
      )
  """
  def pipeline_modifier(pipeline, _opts) do
    add_filter_phase(pipeline)
  end
end
