defmodule Claptrap.Catalog.Server do
  @moduledoc false
  use GenServer
  require Logger

  def start_link(init_arg) do
    name = Keyword.get(init_arg, :name, __MODULE__)
    GenServer.start_link(__MODULE__, init_arg, name: name)
  end

  def list_sources(server \\ __MODULE__) do
    GenServer.call(server, :list_sources)
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
