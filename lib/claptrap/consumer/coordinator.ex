defmodule Claptrap.Consumer.Coordinator do
  @moduledoc "Periodically reconciles running consumer workers with catalog sources."
  use GenServer
  require Logger

  alias Claptrap.Catalog
  alias Claptrap.Consumer.Worker
  alias Claptrap.Registry

  @tick_interval :timer.seconds(30)

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(init_arg) do
    opts = if is_list(init_arg), do: init_arg, else: []

    Logger.info("Consumer.Coordinator started")
    schedule_tick()

    {:ok,
     %{
       list_sources_fun: Keyword.get(opts, :list_sources_fun, &Catalog.list_sources/1)
     }, {:continue, :bootstrap}}
  end

  @impl true
  def handle_continue(:bootstrap, state) do
    reconcile_workers_safely(state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:tick, state) do
    reconcile_workers_safely(state)
    schedule_tick()
    {:noreply, state}
  end

  defp reconcile_workers(state) do
    state.list_sources_fun.(enabled: true)
    |> Enum.each(&ensure_worker_running/1)
  end

  defp reconcile_workers_safely(state) do
    reconcile_workers(state)
  rescue
    exception ->
      Logger.warning("Consumer.Coordinator reconciliation failed: #{Exception.message(exception)}")
  catch
    :exit, reason ->
      Logger.warning("Consumer.Coordinator reconciliation exited: #{inspect(reason)}")
  end

  defp ensure_worker_running(source) do
    case Registry.whereis(:source_worker, source.id) do
      pid when is_pid(pid) ->
        :ok

      _ ->
        case DynamicSupervisor.start_child(
               Claptrap.Consumer.WorkerSupervisor,
               {Worker, source_id: source.id}
             ) do
          {:ok, _pid} ->
            :ok

          {:error, {:already_started, _pid}} ->
            :ok

          {:error, reason} ->
            Logger.error("Consumer.Coordinator failed to start worker for source=#{source.id}: #{inspect(reason)}")

            {:error, reason}
        end
    end
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_interval)
  end
end
