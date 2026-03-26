defmodule Claptrap.Extractor.Supervisor do
  @moduledoc """
  Supervision root for the extractor subsystem.

  Child processes:

  1. `Claptrap.Extractor.TaskSupervisor`
     - Supervises short-lived extraction tasks started by the router.
  2. `Claptrap.Extractor.Router`
     - Subscribes to entry ingestion events and dispatches extraction work.

  The supervisor uses `:rest_for_one` ordering. This encodes the dependency that
  the router expects the task supervisor to exist. If the task supervisor is
  restarted, the router is restarted after it so future dispatches always target
  a live task supervisor.
  """
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Task.Supervisor, name: Claptrap.Extractor.TaskSupervisor},
      Claptrap.Extractor.Router
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
