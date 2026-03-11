defmodule Claptrap.Registry do
  @moduledoc """
  Process registry for {type, id} -> PID mappings.
  Types: :source_worker, :sink_worker, :catalog, etc.
  """

  def child_spec(_init_arg) do
    Registry.child_spec(
      keys: :unique,
      name: __MODULE__
    )
  end

  def via_tuple(type, id) do
    {:via, Registry, {__MODULE__, {type, id}}}
  end

  def whereis(type, id) do
    Registry.whereis_name({__MODULE__, {type, id}})
  end

  def register(type, id) do
    Registry.register_name({__MODULE__, {type, id}}, self())
  end
end
