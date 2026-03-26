defmodule Claptrap.Consumer.Supervisor do
  @moduledoc """
  Owns the Consumer supervision subtree.

  This supervisor starts and monitors the two long-lived processes that make up
  consumer orchestration:

    * `Claptrap.Consumer.WorkerSupervisor` manages one worker per source.
    * `Claptrap.Consumer.Coordinator` reconciles enabled catalog sources with
      running workers.

  The child order and restart strategy are intentional. The
  `WorkerSupervisor` starts first, then the `Coordinator`. The strategy is
  `:rest_for_one`, so if the worker supervisor crashes and is restarted, the
  coordinator is restarted afterward. This ensures the coordinator does not
  continue running with stale assumptions about worker topology.
  """
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: Claptrap.Consumer.WorkerSupervisor},
      Claptrap.Consumer.Coordinator
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
