import Config

config :claptrap, Claptrap.Repo,
  username: "postgres",
  password: "postgres",
  port: 5432,
  pool_size: 10

config :logger, level: :debug
