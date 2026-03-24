defmodule Claptrap.API.AuthTest do
  use Claptrap.DataCase, async: true

  @moduletag :integration
  @moduletag capture_log: true

  alias Claptrap.API.Plug, as: APIPlug

  defp call(method, path, headers \\ []) do
    conn = Plug.Test.conn(method, path)

    conn =
      Enum.reduce(headers, conn, fn {key, value}, acc ->
        Plug.Conn.put_req_header(acc, key, value)
      end)

    APIPlug.call(conn, APIPlug.init([]))
  end

  describe "authentication" do
    test "returns 401 without authorization header" do
      conn = call(:get, "/api/v1/sources")
      assert conn.status == 401
      assert %{"error" => "unauthorized"} = Jason.decode!(conn.resp_body)
    end

    test "returns 401 with invalid key" do
      conn = call(:get, "/api/v1/sources", [{"authorization", "Bearer wrong-key"}])
      assert conn.status == 401
      assert %{"error" => "unauthorized"} = Jason.decode!(conn.resp_body)
    end

    test "returns 401 with malformed authorization header" do
      conn = call(:get, "/api/v1/sources", [{"authorization", "Token test-api-key"}])
      assert conn.status == 401
      assert %{"error" => "unauthorized"} = Jason.decode!(conn.resp_body)
    end

    test "passes through with valid bearer token" do
      conn = call(:get, "/api/v1/sources", [{"authorization", "Bearer test-api-key"}])
      assert conn.status == 200
    end

    test "returns 401 when api_key is configured as empty string" do
      original = Application.get_env(:claptrap, :api_key)

      try do
        Application.put_env(:claptrap, :api_key, "")
        conn = call(:get, "/api/v1/sources", [{"authorization", "Bearer "}])
        assert conn.status == 401
        assert %{"error" => "unauthorized"} = Jason.decode!(conn.resp_body)
      after
        Application.put_env(:claptrap, :api_key, original)
      end
    end
  end

  describe "exempt paths" do
    test "/health bypasses auth" do
      conn = call(:get, "/health")
      assert conn.status == 200
      assert %{"status" => "ok"} = Jason.decode!(conn.resp_body)
    end

    test "/ready bypasses auth" do
      conn = call(:get, "/ready")
      assert conn.status in [200, 503]
    end
  end
end
