ExUnit.start()

# Ensure test database is set up
migrations_path = Path.join([:code.priv_dir(:social_network), "repo", "migrations"])
Ecto.Migrator.run(SocialNetwork.Repo, migrations_path, :up, all: true)

# Ensure the repo is in sandbox mode for tests
Ecto.Adapters.SQL.Sandbox.mode(SocialNetwork.Repo, :manual)
