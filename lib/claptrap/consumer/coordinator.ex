defmodule Claptrap.Consumer.Coordinator do
  @moduledoc "Periodically reconciles running consumer workers with catalog sources."
  use GenServer
  require Logger

  alias Claptrap.{Catalog, Consumer.Worker, Registry}

  @tick_interval :timer.seconds(30)
  @default_poll_interval :timer.minutes(15)

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Consumer.Coordinator started")
    bootstrap_workers()
    schedule_tick()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:tick, state) do
    sources = Catalog.list_sources(enabled: true)
    now = DateTime.utc_now()

    Enum.each(sources, fn source ->
      ensure_worker_running(source)

      if source_due?(source, now) do
        Worker.poll(source.id)
      end
    end)

    schedule_tick()
    {:noreply, state}
  end

  # Private

  defp bootstrap_workers do
    Catalog.list_sources(enabled: true)
    |> Enum.each(&ensure_worker_running/1)
  end

  defp ensure_worker_running(source) do
    case Registry.whereis(:source_worker, source.id) do
      :undefined ->
        DynamicSupervisor.start_child(
          Claptrap.Consumer.WorkerSupervisor,
          {Worker, source.id}
        )

      _pid ->
        :ok
    end
  end

  defp source_due?(%{last_consumed_at: nil}, _now), do: false

  defp source_due?(%{last_consumed_at: last_consumed_at}, now) do
    elapsed = DateTime.diff(now, last_consumed_at, :millisecond)
    elapsed >= @default_poll_interval
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_interval)
  end
end
