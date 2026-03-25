import Config

if db_host = System.get_env("DATABASE_HOSTNAME") do
  config :claptrap, Claptrap.Repo, hostname: db_host
end

if config_env() == :test do
  if url = System.get_env("DATABASE_URL") do
    config :claptrap, Claptrap.Repo,
      url: url,
      pool: Ecto.Adapters.SQL.Sandbox
  end
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "DATABASE_URL environment variable is not set"

  config :claptrap, Claptrap.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  api_key =
    System.get_env("CLAPTRAP_API_KEY") ||
      raise "CLAPTRAP_API_KEY environment variable is not set"

  config :claptrap, api_key: api_key

  config :claptrap, :firecrawl,
    api_key: System.fetch_env!("FIRECRAWL_API_KEY"),
    base_url: System.get_env("FIRECRAWL_BASE_URL", "https://api.firecrawl.dev")
end
