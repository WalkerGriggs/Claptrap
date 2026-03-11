defmodule Claptrap.Consumer.Coordinator do
  @moduledoc "Periodically reconciles running consumer workers with catalog sources."
  use GenServer
  require Logger

  @tick_interval :timer.seconds(30)

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Consumer.Coordinator started")
    schedule_tick()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:tick, state) do
    Logger.debug("Consumer.Coordinator tick - no sources to poll yet (M3)")
    schedule_tick()
    {:noreply, state}
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_interval)
  end
end
