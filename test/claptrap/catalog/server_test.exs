defmodule Claptrap.Catalog.ServerTest do
  use ExUnit.Case, async: true

  alias Claptrap.Catalog.Server

  setup context do
    child_spec = %{
      id: context.test,
      start: {Server, :start_link, [[name: context.test]]}
    }

    pid = start_supervised!(child_spec)
    %{pid: pid, server: context.test}
  end

  test "starts successfully", %{pid: pid} do
    assert Process.alive?(pid)
  end

  test "list_sources/1 returns empty list", %{server: server} do
    assert Server.list_sources(server) == []
  end
end
