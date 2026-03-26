defmodule Claptrap.Catalog.Server do
  @moduledoc """
  A minimal GenServer wrapper for catalog state.

  The server currently exists as a lightweight process that can be supervised
  and addressed by name. It exposes `list_sources/1` as a synchronous call, and
  the current callback implementation returns an empty list.

  This module is intentionally small in the current codebase and currently
  returns an empty list for `list_sources/1`.
  """
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
