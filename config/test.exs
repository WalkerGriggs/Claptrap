import Config

config :claptrap, Claptrap.Repo,
  username: "postgres",
  password: "postgres",
  port: 5432,
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox

config :claptrap, api_key: "test-api-key"

config :logger, level: :warning
