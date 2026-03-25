import Config

config :claptrap,
  ecto_repos: [Claptrap.Repo]

config :claptrap, Claptrap.Repo,
  database: "claptrap_#{config_env()}",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true

config :claptrap, :firecrawl,
  api_key: nil,
  base_url: "https://api.firecrawl.dev"

config :claptrap, :extraction,
  formats: ["markdown"],
  adapters: %{
    "markdown" => Claptrap.Extractor.Adapters.Firecrawl,
    "html" => Claptrap.Extractor.Adapters.Firecrawl
  }

import_config "#{config_env()}.exs"
