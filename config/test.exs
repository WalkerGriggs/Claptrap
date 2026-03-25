import Config

config :claptrap, Claptrap.Repo,
  username: "postgres",
  password: "postgres",
  port: 5432,
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox

config :claptrap,
  api_key: "test-api-key",
  port: 0

config :logger, level: :warning

config :claptrap, Claptrap.Storage,
  backend: Claptrap.Storage.Backends.Local,
  root_dir: Path.join(System.tmp_dir!(), "claptrap_test_storage")
