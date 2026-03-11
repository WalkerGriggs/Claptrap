defmodule Claptrap.Producer.Router do
  use GenServer
  require Logger

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Producer.Router started")
    {:ok, %{}}
  end

  @impl true
  def handle_info({:entries_ingested, _source_id, _entries}, state) do
    Logger.debug("Router received entries (stub - no sinks yet, M4)")
    {:noreply, state}
  end
end
