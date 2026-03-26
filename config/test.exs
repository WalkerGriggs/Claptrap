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

config :claptrap, :firecrawl,
  api_key: "test-api-key",
  base_url: "http://localhost"

config :claptrap, :extraction,
  formats: ["markdown"],
  adapters: %{
    "markdown" => Claptrap.Extractor.Adapters.Firecrawl
  }

config :logger, level: :warning
