defmodule Claptrap.Catalog.ServerTest do
  use ExUnit.Case, async: true

  alias Claptrap.Catalog.Server

  setup do
    {:ok, pid} = start_supervised(Server)
    %{pid: pid}
  end

  test "starts successfully", %{pid: pid} do
    assert Process.alive?(pid)
  end

  test "list_sources/0 returns empty list" do
    assert Server.list_sources() == []
  end
end
