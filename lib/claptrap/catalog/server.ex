defmodule Claptrap.Catalog.Server do
  @moduledoc false
  use GenServer
  require Logger

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def list_sources do
    GenServer.call(__MODULE__, :list_sources)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Catalog.Server started")
    {:ok, %{}}
  end

  @impl true
  def handle_call(:list_sources, _from, state) do
    {:reply, [], state}
  end
end
