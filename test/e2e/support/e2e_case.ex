defmodule Claptrap.E2E.Case do
  @moduledoc false

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      import Claptrap.E2E.Case
      @moduletag :e2e
    end
  end

  setup do
    pid = Sandbox.start_owner!(Claptrap.Repo, shared: true)

    {:ok, agent} = Agent.start_link(fn -> [] end)

    on_exit(fn ->
      cleanup(agent)
      Sandbox.stop_owner(pid)
    end)

    {:ok, cleanup_agent: agent}
  end

  def base_url do
    {_, pid, _, _} =
      Claptrap.Supervisor
      |> Supervisor.which_children()
      |> Enum.find(fn {_, _, _, mods} -> mods == [Bandit] end)

    {:ok, {_addr, port}} = ThousandIsland.listener_info(pid)
    "http://localhost:#{port}"
  end

  def api_key do
    Application.get_env(:claptrap, :api_key)
  end

  def http_get(path) do
    resp = Req.request!(method: :get, url: base_url() <> path, headers: auth_headers())
    {resp.status, decode_body(resp)}
  end

  def http_post(path, body) do
    resp = Req.request!(method: :post, url: base_url() <> path, json: body, headers: auth_headers())

    {resp.status, decode_body(resp)}
  end

  def http_patch(path, body) do
    resp = Req.request!(method: :patch, url: base_url() <> path, json: body, headers: auth_headers())

    {resp.status, decode_body(resp)}
  end

  def http_delete(path) do
    resp = Req.request!(method: :delete, url: base_url() <> path, headers: auth_headers())
    {resp.status, decode_body(resp)}
  end

  def track_cleanup(%{cleanup_agent: agent}, path) do
    Agent.update(agent, &[path | &1])
  end

  defp cleanup(agent) do
    if Process.alive?(agent) do
      agent
      |> Agent.get(& &1)
      |> Enum.each(fn path ->
        Req.request!(method: :delete, url: base_url() <> path, headers: auth_headers())
      end)

      Agent.stop(agent)
    end
  end

  defp auth_headers do
    %{authorization: "Bearer #{api_key()}"}
  end

  defp decode_body(%{status: 204}), do: %{}

  defp decode_body(%{body: body}) when is_map(body), do: body

  defp decode_body(%{body: body}) when is_binary(body) and body != "" do
    Jason.decode!(body)
  end

  defp decode_body(_resp), do: %{}
end
