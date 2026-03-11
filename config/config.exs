import Config

config :claptrap,
  ecto_repos: [Claptrap.Repo]

config :claptrap, Claptrap.Repo,
  database: "claptrap_#{config_env()}",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true

import_config "#{config_env()}.exs"
