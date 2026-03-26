defmodule Claptrap.Producer.Supervisor do
  @moduledoc """
  Top-level supervisor for the producer subsystem.

  This supervisor starts and manages two producer children:

  - `Claptrap.Producer.WorkerSupervisor` (`DynamicSupervisor`) which owns one
    worker process per sink.
  - `Claptrap.Producer.Router` (`GenServer`) which subscribes to entry events
    and dispatches matching entries to sink workers.

  Before child startup, the supervisor creates the named ETS table
  `:claptrap_rss_feeds`. The RSS feed adapter uses this table to store
  materialized XML for pull-mode RSS sinks.

  Child order and restart strategy are intentional:

      Producer.Supervisor (:rest_for_one)
      ├─ Producer.WorkerSupervisor (:one_for_one)
      └─ Producer.Router

  With `:rest_for_one`, if `WorkerSupervisor` crashes, `Router` is restarted
  after it. This keeps the router from holding stale assumptions about worker
  topology after a worker subtree reset.
  """
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
