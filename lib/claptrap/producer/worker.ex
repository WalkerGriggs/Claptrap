defmodule Claptrap.Producer.Worker do
  @moduledoc """
  One GenServer per enabled sink. Receives entry batches from the Router,
  calls the appropriate adapter, and retries on failure with exponential backoff.
  """

  use GenServer
  require Logger

  alias Claptrap.Catalog
  alias Claptrap.Registry

  @max_attempts 5
  @max_backoff_ms 30_000

  # Public API

  def start_link(sink_id) do
    GenServer.start_link(__MODULE__, sink_id, name: Registry.via_tuple(:sink_worker, sink_id))
  end

  def deliver(sink_id, entries) do
    case Registry.whereis(:sink_worker, sink_id) do
      :undefined -> {:error, :not_found}
      pid -> GenServer.cast(pid, {:deliver, entries})
    end
  end

  # GenServer callbacks

  @impl true
  def init(sink_id) do
    sink = Catalog.get_sink!(sink_id)

    case adapter_for_type(sink.type) do
      {:ok, adapter} ->
        state = %{
          sink: sink,
          adapter: adapter,
          queue: :queue.new(),
          retry_count: 0,
          retry_timer: nil
        }

        state = maybe_materialize_on_start(state)
        {:ok, state}

      {:error, reason} ->
        Logger.error("Producer.Worker failed to start for sink #{sink_id}: #{reason}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_cast({:deliver, entries}, state) do
    state = attempt_delivery(entries, 0, state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:retry, state) do
    state = %{state | retry_timer: nil}

    case :queue.out(state.queue) do
      {:empty, _} ->
        {:noreply, state}

      {{:value, {entries, attempt}}, rest_queue} ->
        state = %{state | queue: rest_queue}
        state = attempt_delivery(entries, attempt, state)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:resource_changed, _resource_type, _action, _id} = msg, state) do
    Logger.debug("Producer.Worker received resource_changed (unhandled): #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("Producer.Worker received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private

  defp maybe_materialize_on_start(%{adapter: adapter, sink: sink} = state) do
    adapter.materialize(sink, [])
    state
  end

  defp attempt_delivery(entries, attempt, state) do
    %{sink: sink, adapter: adapter} = state

    :telemetry.span(
      [:claptrap, :producer, :delivery],
      %{sink_id: sink.id, entry_count: length(entries)},
      fn ->
        result = do_deliver(adapter, sink, entries)
        {result, %{sink_id: sink.id, entry_count: length(entries), status: result_status(result)}}
      end
    )
    |> case do
      :ok ->
        %{state | retry_count: 0}

      {:error, reason} ->
        handle_delivery_failure(entries, attempt, reason, state)
    end
  end

  defp do_deliver(adapter, sink, entries) do
    case adapter.mode() do
      :push -> adapter.push(sink, entries)
      :pull -> adapter.materialize(sink, entries)
    end
  end

  defp handle_delivery_failure(entries, attempt, reason, state) do
    next_attempt = attempt + 1

    if next_attempt >= @max_attempts do
      Logger.error(
        "Producer.Worker delivery exhausted for sink #{state.sink.id} after #{next_attempt} attempts: #{inspect(reason)}"
      )

      state
    else
      :telemetry.execute(
        [:claptrap, :producer, :retry],
        %{count: 1},
        %{sink_id: state.sink.id, attempt: next_attempt}
      )

      delay = min(500 * Integer.pow(2, attempt) + :rand.uniform(100), @max_backoff_ms)
      timer = Process.send_after(self(), :retry, delay)
      queue = :queue.in({entries, next_attempt}, state.queue)

      Logger.warning(
        "Producer.Worker delivery failed for sink #{state.sink.id} (attempt #{next_attempt}/#{@max_attempts}), retrying in #{delay}ms: #{inspect(reason)}"
      )

      %{state | queue: queue, retry_count: next_attempt, retry_timer: timer}
    end
  end

  defp result_status(:ok), do: :ok
  defp result_status({:error, _}), do: :error

  defp adapter_for_type("rss_feed"), do: {:ok, Claptrap.Producer.Adapters.RssFeed}

  defp adapter_for_type(other),
    do: {:error, "unknown sink type: #{other}"}
end
