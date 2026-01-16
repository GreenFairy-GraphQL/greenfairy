import Config

config :social_network, SocialNetwork.Repo,
  database: Path.expand("../social_network.db", Path.dirname(__ENV__.file)),
  pool_size: 5

config :social_network, ecto_repos: [SocialNetwork.Repo]

config :green_fairy, :generators,
  graphql_namespace: SocialNetworkWeb.GraphQL,
  domain_namespace: SocialNetwork,
  default_implements: [SocialNetworkWeb.GraphQL.Interfaces.Node],
  timestamps: true

# Import environment-specific config
import_config "#{config_env()}.exs"
