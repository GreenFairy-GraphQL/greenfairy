defmodule SocialNetwork.MixProject do
  use Mix.Project

  def project do
    [
      app: :social_network,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger],
      mod: {SocialNetwork.Application, []}
    ]
  end

  defp deps do
    [
      {:green_fairy, path: "../.."},
      {:absinthe, "~> 1.7"},
      {:absinthe_plug, "~> 1.5"},
      {:absinthe_relay, "~> 1.5"},
      {:absinthe_phoenix, "~> 2.0"},
      {:phoenix_pubsub, "~> 2.1"},
      {:dataloader, "~> 2.0"},
      {:ecto_sql, "~> 3.10"},
      {:ecto_sqlite3, "~> 0.12"},
      {:plug_cowboy, "~> 2.6"},
      {:jason, "~> 1.4"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"]
    ]
  end
end
