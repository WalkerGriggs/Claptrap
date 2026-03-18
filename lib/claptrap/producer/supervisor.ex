defmodule Claptrap.Producer.Supervisor do
  @moduledoc "Supervises the Producer subsystem: WorkerSupervisor and Router."
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    :ets.new(:claptrap_rss_feeds, [:named_table, :public, :set, read_concurrency: true])

    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: Claptrap.Producer.WorkerSupervisor},
      Claptrap.Producer.Router
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
