defmodule Claptrap.Repo do
  use Ecto.Repo,
    otp_app: :claptrap,
    adapter: Ecto.Adapters.Postgres

  use Paginator
end
