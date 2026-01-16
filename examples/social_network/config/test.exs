import Config

# Use a temporary file database for tests (SQLite in-memory has connection isolation issues)
config :social_network, SocialNetwork.Repo,
  database: Path.expand("../../test_social_network.db", __DIR__),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# Don't start HTTP server during tests
config :social_network, start_http: false

# Don't start subscriptions during tests
config :social_network, start_subscriptions: false

# Print only warnings and errors during test
config :logger, level: :warning
