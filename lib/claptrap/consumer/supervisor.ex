defmodule Claptrap.Consumer.Supervisor do
  @moduledoc "Supervises the Consumer subsystem: WorkerSupervisor and Coordinator."
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
