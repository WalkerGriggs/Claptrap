defmodule Claptrap.Producer.Router do
  @moduledoc "Routes ingested entries to matching sink workers via tag-based subscriptions."
  use GenServer
  require Logger

  alias Claptrap.Catalog
  alias Claptrap.PubSub, as: PS
  alias Claptrap.Registry, as: Reg

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    PS.subscribe(PS.topic_entries_new())
    bootstrap_workers()
    Logger.info("Producer.Router started")
    {:ok, %{}}
  end

  @impl true
  def handle_info({:entries_ingested, _source_id, entries}, state) do
    all_tags = entries |> Enum.flat_map(& &1.tags) |> Enum.uniq()

    if all_tags != [] do
      subscriptions = Catalog.subscriptions_for_tags(all_tags)
      route_entries(subscriptions, entries)
    end

    {:noreply, state}
  end

  def handle_info({:resource_changed, :sink, action, sink_id}, state) do
    Logger.debug("Producer.Router received resource_changed: #{action} for sink #{sink_id} (stub)")
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.warning("Producer.Router received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp bootstrap_workers do
    Catalog.list_sinks(enabled: true)
    |> Enum.each(fn sink ->
      case DynamicSupervisor.start_child(
             Claptrap.Producer.WorkerSupervisor,
             {Claptrap.Producer.Worker, sink.id}
           ) do
        {:ok, _pid} ->
          Logger.info("Started Producer.Worker for sink #{sink.id}")

        {:error, {:already_started, _pid}} ->
          :ok

        {:error, reason} ->
          Logger.error("Failed to start Producer.Worker for sink #{sink.id}: #{inspect(reason)}")
      end
    end)
  end

  defp route_entries(subscriptions, entries) do
    subscriptions
    |> group_entries_by_sink(entries)
    |> Enum.each(&deliver_to_worker/1)
  end

  defp group_entries_by_sink(subscriptions, entries) do
    entry_tag_sets = Map.new(entries, fn e -> {e.id, MapSet.new(e.tags)} end)

    Enum.reduce(subscriptions, %{}, fn sub, acc ->
      sub_tags = MapSet.new(sub.tags)

      matched =
        Enum.filter(entries, fn entry ->
          not MapSet.disjoint?(Map.fetch!(entry_tag_sets, entry.id), sub_tags)
        end)

      merge_matched(acc, sub.sink_id, matched)
    end)
  end

  defp merge_matched(acc, _sink_id, []), do: acc

  defp merge_matched(acc, sink_id, matched) do
    Map.update(acc, sink_id, matched, fn existing ->
      Enum.uniq_by(existing ++ matched, & &1.id)
    end)
  end

  defp deliver_to_worker({sink_id, matched_entries}) do
    case Reg.whereis(:sink_worker, sink_id) do
      :undefined ->
        Logger.warning("No worker for sink #{sink_id}, skipping delivery")

      pid when is_pid(pid) ->
        GenServer.cast(pid, {:deliver, matched_entries})
    end
  end
end
