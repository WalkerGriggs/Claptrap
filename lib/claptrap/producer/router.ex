defmodule Claptrap.Producer.Router do
  @moduledoc """
  Routes ingested entry batches to the appropriate Producer.Workers.

  Subscribes to the `entries:new` PubSub topic. On receipt, looks up matching
  subscriptions from the Catalog and dispatches per-entry-filtered batches to
  each sink's worker.
  """

  use GenServer
  require Logger

  alias Claptrap.{Catalog, PubSub}
  alias Claptrap.Registry

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    PubSub.subscribe(PubSub.topic_entries_new())

    sinks = Catalog.list_sinks(enabled: true)

    sink_workers =
      Enum.reduce(sinks, %{}, fn sink, acc ->
        case start_worker(sink.id) do
          {:ok, pid} ->
            Map.put(acc, sink.id, pid)

          {:error, reason} ->
            Logger.warning("Router failed to start worker for sink #{sink.id}: #{inspect(reason)}")
            acc
        end
      end)

    Logger.info("Producer.Router started, bootstrapped #{map_size(sink_workers)} sink workers")
    {:ok, %{sink_workers: sink_workers}}
  end

  @impl true
  def handle_info({:entries_ingested, _source_id, entries}, state) do
    all_tags = entries |> Enum.flat_map(& &1.tags) |> Enum.uniq()
    subscriptions = Catalog.subscriptions_for_tags(all_tags)

    subscriptions
    |> Enum.group_by(& &1.sink_id)
    |> Enum.each(fn {sink_id, subs} ->
      matched = entries_matching_subscriptions(entries, subs)

      if matched != [] do
        dispatch(sink_id, matched)
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:resource_changed, :sink, _action, _sink_id} = msg, state) do
    Logger.debug("Producer.Router received resource_changed (unhandled): #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("Producer.Router received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private

  defp entries_matching_subscriptions(entries, subscriptions) do
    sub_tag_sets = Enum.map(subscriptions, &MapSet.new(&1.tags))

    Enum.filter(entries, fn entry ->
      entry_tags = MapSet.new(entry.tags)

      Enum.any?(sub_tag_sets, fn sub_tags ->
        not MapSet.disjoint?(entry_tags, sub_tags)
      end)
    end)
  end

  defp dispatch(sink_id, entries) do
    case Registry.whereis(:sink_worker, sink_id) do
      :undefined ->
        Logger.warning("Producer.Router: no worker found for sink #{sink_id}, dropping batch")

      pid ->
        GenServer.cast(pid, {:deliver, entries})
    end
  end

  defp start_worker(sink_id) do
    DynamicSupervisor.start_child(
      Claptrap.Producer.WorkerSupervisor,
      {Claptrap.Producer.Worker, sink_id}
    )
  end
end
