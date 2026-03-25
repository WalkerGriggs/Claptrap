import Config

config :claptrap,
  ecto_repos: [Claptrap.Repo]

config :claptrap, Claptrap.Repo,
  database: "claptrap_#{config_env()}",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true

config :claptrap, Claptrap.Storage,
  backend: Claptrap.Storage.Backends.Local,
  root_dir: Path.join(File.cwd!(), "priv/storage")

import_config "#{config_env()}.exs"
