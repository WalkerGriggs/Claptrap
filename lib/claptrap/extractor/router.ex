defmodule Claptrap.Extractor.Router do
  @moduledoc false
  use GenServer
  require Logger

  alias Claptrap.Extractor.Pipeline
  alias Claptrap.PubSub, as: PS

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    PS.subscribe(PS.topic_entries_new())

    config = Application.get_env(:claptrap, :extraction, %{})
    formats = config[:formats] || []
    adapters = config[:adapters] || %{}

    if formats == [] do
      Logger.info("Extractor.Router started with extraction disabled (no formats configured)")
    else
      Logger.info("Extractor.Router started, formats=#{inspect(formats)}")
    end

    {:ok, %{formats: formats, config: %{adapters: adapters, formats: formats}}}
  end

  @impl true
  def handle_info({:entries_ingested, _source_id, entries}, %{formats: []} = state) do
    Logger.debug("Extractor.Router: skipping #{length(entries)} entries (extraction disabled)")
    {:noreply, state}
  end

  def handle_info({:entries_ingested, _source_id, entries}, state) do
    extractable = Enum.filter(entries, &(&1.url != nil && &1.url != ""))

    Logger.debug("Extractor.Router: dispatching extraction for #{length(extractable)}/#{length(entries)} entries")

    for entry <- extractable do
      Task.Supervisor.start_child(
        Claptrap.Extractor.TaskSupervisor,
        fn -> Pipeline.extract_and_store(entry, state.formats, state.config) end
      )
    end

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.warning("Extractor.Router received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end
end
