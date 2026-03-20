defmodule Claptrap.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Claptrap.Repo,
      {Registry, keys: :unique, name: Claptrap.Registry},
      {Phoenix.PubSub, name: Claptrap.PubSub},
      Claptrap.Consumer.Supervisor,
      Claptrap.Producer.Supervisor,
      {Bandit, plug: Claptrap.API.Router, port: port()}
    ]

    opts = [strategy: :one_for_one, name: Claptrap.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp port do
    String.to_integer(System.get_env("PORT") || "4000")
  end
end
