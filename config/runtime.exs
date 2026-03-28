import Config

must_get = fn name ->
  System.get_env(name) || raise "#{name} environment variable is not set"
end

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
  db_host = must_get.("DATABASE_HOST")

  config :claptrap, Claptrap.Repo,
    database: must_get.("DATABASE"),
    hostname: db_host,
    port: String.to_integer(System.get_env("DATABASE_PORT") || "5432"),
    username: must_get.("DATABASE_USERNAME"),
    password: must_get.("DATABASE_PASSWORD"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    ssl: [
      verify: :verify_peer,
      cacertfile: CAStore.file_path(),
      server_name_indication: String.to_charlist(db_host),
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ]

  config :claptrap, api_key: must_get.("CLAPTRAP_API_KEY")

  config :claptrap, :firecrawl,
    api_key: must_get.("FIRECRAWL_API_KEY"),
    base_url: System.get_env("FIRECRAWL_BASE_URL", "https://api.firecrawl.dev")
end
