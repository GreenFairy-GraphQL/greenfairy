import Config

# Runtime configuration for production
if config_env() == :prod do
  config :social_network, SocialNetwork.Repo,
    database: System.get_env("DATABASE_PATH") || "social_network.db",
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")
end
