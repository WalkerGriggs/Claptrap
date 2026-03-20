defmodule Claptrap.DataCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Claptrap.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
    end
  end

  alias Ecto.Adapters.SQL.Sandbox

  setup tags do
    pid = Sandbox.start_owner!(Claptrap.Repo, shared: !tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
    {:ok, sandbox_owner: pid}
  end

  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
