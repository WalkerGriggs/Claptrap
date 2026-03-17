defmodule Claptrap.Consumer.Worker do
  @moduledoc "GenServer that drives a single source through its consume cycle."

  use GenServer
  require Logger

  alias Claptrap.{Catalog, PubSub}

  @default_poll_interval :timer.minutes(15)
  @max_retries 5

  @adapter_map %{
    "rss" => Claptrap.Consumer.Adapters.RSS
  }

  # Public API

  def start_link(source_id) do
    GenServer.start_link(__MODULE__, source_id,
      name: Claptrap.Registry.via_tuple(:source_worker, source_id)
    )
  end

  def poll(source_id) do
    case Claptrap.Registry.whereis(:source_worker, source_id) do
      :undefined -> {:error, :not_found}
      pid -> send(pid, :poll)
    end
  end

  # GenServer callbacks

  @impl true
  def init(source_id) do
    source = Catalog.get_source!(source_id)
    adapter = resolve_adapter!(source.type)
    :ok = adapter.validate_config(source.config)

    state = %{
      source: source,
      adapter: adapter,
      poll_interval: @default_poll_interval,
      retry_count: 0,
      max_retries: @max_retries
    }

    send(self(), :poll)
    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    state = %{state | retry_count: 0}
    do_consume(state, :poll)
  end

  @impl true
  def handle_info(:retry, state) do
    do_consume(state, :retry)
  end

  # Private

  defp do_consume(%{source: source, adapter: adapter} = state, _trigger) do
    case adapter.fetch(source) do
      {:ok, raw_items} ->
        new_entries = persist_entries(raw_items, source)

        if new_entries != [] do
          PubSub.broadcast(PubSub.topic_entries_new(), {:entries_ingested, source.id, new_entries})
        end

        {:ok, updated_source} = Catalog.update_source(source, %{last_consumed_at: DateTime.utc_now()})

        schedule_poll(state.poll_interval)
        {:noreply, %{state | source: updated_source, retry_count: 0}}

      {:error, reason} ->
        handle_fetch_error(state, reason)
    end
  end

  defp persist_entries(raw_items, source) do
    raw_items
    |> Enum.map(fn attrs ->
      attrs
      |> Map.put(:source_id, source.id)
      |> Map.put(:status, attrs[:status] || "unread")
      |> merge_source_tags(source.tags)
    end)
    |> Enum.flat_map(fn attrs ->
      case Catalog.create_entry(attrs) do
        {:ok, %{id: nil}} -> []
        {:ok, entry} -> [entry]
        {:error, _} -> []
      end
    end)
  end

  defp merge_source_tags(attrs, []), do: attrs

  defp merge_source_tags(attrs, source_tags) do
    existing = attrs[:tags] || []
    Map.put(attrs, :tags, Enum.uniq(existing ++ source_tags))
  end

  defp handle_fetch_error(%{retry_count: count, max_retries: max} = state, reason)
       when count < max do
    delay = min(500 * Integer.pow(2, count) + :rand.uniform(100), 30_000)

    Logger.warning(
      "Consumer.Worker fetch failed for source #{state.source.id} " <>
        "(attempt #{count + 1}/#{max}): #{inspect(reason)}. Retrying in #{delay}ms."
    )

    Process.send_after(self(), :retry, delay)
    {:noreply, %{state | retry_count: count + 1}}
  end

  defp handle_fetch_error(%{retry_count: count, max_retries: max} = state, reason) do
    Logger.error(
      "Consumer.Worker fetch failed for source #{state.source.id} " <>
        "after #{count}/#{max} retries: #{inspect(reason)}. Resuming normal schedule."
    )

    schedule_poll(state.poll_interval)
    {:noreply, %{state | retry_count: 0}}
  end

  defp schedule_poll(interval) do
    Process.send_after(self(), :poll, interval)
  end

  defp resolve_adapter!(type) do
    case Map.fetch(@adapter_map, type) do
      {:ok, mod} -> mod
      :error -> raise ArgumentError, "unknown source type: #{inspect(type)}"
    end
  end
end
