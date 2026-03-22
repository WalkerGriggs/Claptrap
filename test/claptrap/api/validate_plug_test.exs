defmodule Claptrap.API.ValidatePlugTest do
  use Claptrap.DataCase, async: true

  @moduletag :integration
  @moduletag capture_log: true

  alias Claptrap.API.Plug, as: APIPlug

  defp call(method, path, body \\ nil) do
    conn = Plug.Test.conn(method, path)

    conn =
      if body do
        conn
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Map.put(:body_params, body)
      else
        conn
      end

    APIPlug.call(conn, APIPlug.init([]))
  end

  describe "POST with missing required fields" do
    test "returns 422 for missing source fields" do
      conn = call(:post, "/api/v1/sources", %{})
      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert is_map(body["errors"])
      assert body["errors"]["type"]
      assert body["errors"]["name"]
      assert body["errors"]["config"]
    end

    test "returns 422 for missing sink fields" do
      conn = call(:post, "/api/v1/sinks", %{})
      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert is_map(body["errors"])
      assert body["errors"]["type"]
      assert body["errors"]["name"]
      assert body["errors"]["config"]
    end

    test "returns 422 for missing subscription fields" do
      conn = call(:post, "/api/v1/subscriptions", %{})
      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert is_map(body["errors"])
    end

    test "returns 422 for missing entry fields" do
      conn = call(:post, "/api/v1/entries", %{})
      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert is_map(body["errors"])
    end
  end

  describe "POST with wrong types" do
    test "returns 422 when type is not a string" do
      conn =
        call(:post, "/api/v1/sources", %{
          "type" => 123,
          "name" => "Feed",
          "config" => %{"url" => "https://example.com"}
        })

      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert is_map(body["errors"])
    end

    test "returns 422 when config is not an object" do
      conn =
        call(:post, "/api/v1/sources", %{
          "type" => "rss",
          "name" => "Feed",
          "config" => "not_an_object"
        })

      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert is_map(body["errors"])
    end
  end

  describe "GET requests pass through" do
    test "GET /api/v1/sources passes through without validation" do
      conn = call(:get, "/api/v1/sources")
      assert conn.status == 200
    end

    test "GET /api/v1/sinks passes through without validation" do
      conn = call(:get, "/api/v1/sinks")
      assert conn.status == 200
    end
  end

  describe "PATCH with valid partial body" do
    test "passes through with valid partial update" do
      {:ok, source} =
        Claptrap.Catalog.create_source(%{
          type: "rss",
          name: "Feed",
          config: %{"url" => "https://example.com/feed"}
        })

      conn = call(:patch, "/api/v1/sources/#{source.id}", %{"name" => "Updated"})
      assert conn.status == 200
      assert Jason.decode!(conn.resp_body)["name"] == "Updated"
    end
  end

  describe "POST with valid body" do
    test "passes through to handler" do
      conn =
        call(:post, "/api/v1/sources", %{
          "type" => "rss",
          "name" => "Feed",
          "config" => %{"url" => "https://example.com"}
        })

      assert conn.status == 201
    end
  end

  describe "DELETE requests pass through" do
    test "DELETE passes through without validation" do
      {:ok, source} =
        Claptrap.Catalog.create_source(%{
          type: "rss",
          name: "Feed",
          config: %{"url" => "https://example.com/feed"}
        })

      conn = call(:delete, "/api/v1/sources/#{source.id}")
      assert conn.status == 204
    end
  end
end
