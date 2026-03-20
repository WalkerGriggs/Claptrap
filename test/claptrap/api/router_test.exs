defmodule Claptrap.API.RouterTest do
  use Claptrap.DataCase, async: true

  @moduletag :integration
  @moduletag capture_log: true

  alias Claptrap.API.Plug, as: APIPlug

  defp call(method, path) do
    method
    |> Plug.Test.conn(path)
    |> APIPlug.call(APIPlug.init([]))
  end

  describe "GET /health" do
    test "returns 200 ok" do
      conn = call(:get, "/health")
      assert conn.status == 200
      assert Jason.decode!(conn.resp_body) == %{"status" => "ok"}
    end
  end

  describe "GET /ready" do
    test "returns 200 ready when database is reachable" do
      conn = call(:get, "/ready")
      assert conn.status == 200
      assert Jason.decode!(conn.resp_body) == %{"status" => "ready"}
    end
  end

  describe "unknown routes" do
    test "returns 404 for unmatched paths" do
      conn = call(:get, "/nonexistent")
      assert conn.status == 404
      assert Jason.decode!(conn.resp_body) == %{"error" => "not found"}
    end
  end
end
