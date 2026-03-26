defmodule Claptrap.Catalog.Supervisor do
  @moduledoc """
  Supervisor for catalog-owned processes.
  
  This supervisor starts `Claptrap.Catalog.Server` under a `:one_for_one`
  strategy. If the server terminates, only that child is restarted.
  """
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      Claptrap.Catalog.Server
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
