defmodule Absinthe.Object.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/gigsmart/absinthe_object"

  def project do
    [
      app: :absinthe_object,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      consolidate_protocols: Mix.env() != :test,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      name: "Absinthe.Object",
      description: "A cleaner DSL for GraphQL schema definitions built on Absinthe",
      source_url: @source_url,
      test_coverage: [
        threshold: 85,
        summary: [threshold: 85],
        ignore_modules: [
          # Mix tasks - tested via command line, not unit tests
          Mix.Tasks.Absinthe.Object.Gen,
          Mix.Tasks.Absinthe.Object.Gen.Type,
          Mix.Tasks.Absinthe.Object.Gen.Enum,
          Mix.Tasks.Absinthe.Object.Gen.Input,
          Mix.Tasks.Absinthe.Object.Gen.Interface,
          Mix.Tasks.Absinthe.Object.Gen.Schema,
          # Deferred definition structs - just data structures
          Absinthe.Object.Deferred.Definition.Arg,
          Absinthe.Object.Deferred.Definition.Connection,
          Absinthe.Object.Deferred.Definition.Enum,
          Absinthe.Object.Deferred.Definition.Field,
          Absinthe.Object.Deferred.Definition.Input,
          Absinthe.Object.Deferred.Definition.Interface,
          Absinthe.Object.Deferred.Definition.Object,
          Absinthe.Object.Deferred.Definition.Scalar,
          Absinthe.Object.Deferred.Definition.Union,
          Absinthe.Object.Deferred.Schema,
          # Macro-only modules
          Absinthe.Object.Extensions.Auth.Macros
        ]
      ],
      preferred_cli_env: [
        credo: :test,
        dialyzer: :test
      ],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:ex_unit, :mix]
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:absinthe, "~> 1.7"},
      {:dataloader, "~> 2.0"},
      {:ecto, "~> 3.10"},
      {:geo, "~> 3.6", optional: true},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["GigSmart"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "guides/getting-started.md",
        "guides/types.md",
        "guides/authorization.md",
        "guides/relationships.md",
        "guides/cql.md",
        "guides/connections.md",
        "guides/operations.md"
      ],
      groups_for_extras: [
        Guides: ~r/guides\/.*/
      ],
      groups_for_modules: [
        "Core DSL": [
          Absinthe.Object,
          Absinthe.Object.Type,
          Absinthe.Object.Interface,
          Absinthe.Object.Input,
          Absinthe.Object.Enum,
          Absinthe.Object.Union,
          Absinthe.Object.Scalar
        ],
        Operations: [
          Absinthe.Object.Query,
          Absinthe.Object.Mutation,
          Absinthe.Object.Subscription
        ],
        "Schema & Discovery": [
          Absinthe.Object.Schema,
          Absinthe.Object.Discovery
        ],
        "Field Helpers": [
          Absinthe.Object.Field.Connection,
          Absinthe.Object.Field.Dataloader,
          Absinthe.Object.Field.Loader,
          Absinthe.Object.Field.Middleware
        ],
        Extensions: [
          Absinthe.Object.Extensions.CQL,
          Absinthe.Object.Extensions.Auth
        ],
        Authorization: [
          Absinthe.Object.AuthorizedObject,
          Absinthe.Object.AuthorizationInfo
        ],
        Adapters: [
          Absinthe.Object.Adapter,
          Absinthe.Object.Adapters.Ecto
        ],
        "Built-ins": [
          Absinthe.Object.BuiltIns.Node,
          Absinthe.Object.BuiltIns.PageInfo,
          Absinthe.Object.BuiltIns.Timestampable
        ],
        Utilities: [
          Absinthe.Object.Naming
        ]
      ]
    ]
  end
end
