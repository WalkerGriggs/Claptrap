defmodule Claptrap.API.Handlers.SinksTest do
  use Claptrap.DataCase, async: true

  @moduletag :integration
  @moduletag capture_log: true

  alias Claptrap.API.Plug, as: APIPlug
  alias Claptrap.Catalog

  @sink_attrs %{type: "webhook", name: "Hook", config: %{"url" => "https://example.com/hook"}}

  defp call(method, path, body \\ nil) do
    conn =
      Plug.Test.conn(method, path)
      |> Plug.Conn.put_req_header("authorization", "Bearer test-api-key")

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

  describe "GET /api/v1/sinks" do
    test "returns empty list" do
      conn = call(:get, "/api/v1/sinks")
      assert conn.status == 200
      assert %{"items" => []} = Jason.decode!(conn.resp_body)
    end

    test "returns sinks" do
      {:ok, _} = Catalog.create_sink(@sink_attrs)
      conn = call(:get, "/api/v1/sinks")
      assert conn.status == 200
      assert %{"items" => [%{"type" => "webhook"}]} = Jason.decode!(conn.resp_body)
    end

    test "paginates with page_size and page_token" do
      for i <- 1..3 do
        {:ok, _} = Catalog.create_sink(%{@sink_attrs | name: "Hook #{i}"})
      end

      conn = call(:get, "/api/v1/sinks?page_size=2")
      body = Jason.decode!(conn.resp_body)
      assert length(body["items"]) == 2
      assert body["next_page_token"]

      conn = call(:get, "/api/v1/sinks?page_size=2&page_token=#{body["next_page_token"]}")
      body = Jason.decode!(conn.resp_body)
      assert length(body["items"]) == 1
      refute Map.has_key?(body, "next_page_token")
    end
  end

  describe "POST /api/v1/sinks" do
    test "creates a sink with valid params" do
      conn =
        call(:post, "/api/v1/sinks", %{
          "type" => "webhook",
          "name" => "Hook",
          "config" => %{"url" => "https://example.com"}
        })

      assert conn.status == 201
      body = Jason.decode!(conn.resp_body)
      assert body["type"] == "webhook"
      refute Map.has_key?(body, "credentials")
    end

    test "returns 422 with invalid params" do
      conn = call(:post, "/api/v1/sinks", %{})
      assert conn.status == 422
      assert Jason.decode!(conn.resp_body)["errors"]
    end
  end

  describe "GET /api/v1/sinks/:id" do
    test "returns a sink" do
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      conn = call(:get, "/api/v1/sinks/#{sink.id}")
      assert conn.status == 200
      assert Jason.decode!(conn.resp_body)["id"] == sink.id
    end

    test "returns 404 for missing sink" do
      conn = call(:get, "/api/v1/sinks/#{Ecto.UUID.generate()}")
      assert conn.status == 404
    end

    test "returns 400 for malformed UUID" do
      conn = call(:get, "/api/v1/sinks/not-a-uuid")
      assert conn.status == 400
    end
  end

  describe "PATCH /api/v1/sinks/:id" do
    test "updates a sink" do
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      conn = call(:patch, "/api/v1/sinks/#{sink.id}", %{"name" => "Updated"})
      assert conn.status == 200
      assert Jason.decode!(conn.resp_body)["name"] == "Updated"
    end

    test "returns 422 with invalid params" do
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      conn = call(:patch, "/api/v1/sinks/#{sink.id}", %{"name" => ""})
      assert conn.status == 422
    end
  end

  describe "DELETE /api/v1/sinks/:id" do
    test "deletes a sink" do
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      conn = call(:delete, "/api/v1/sinks/#{sink.id}")
      assert conn.status == 204
      assert Catalog.list_sinks() == []
    end

    test "returns 404 for missing sink" do
      conn = call(:delete, "/api/v1/sinks/#{Ecto.UUID.generate()}")
      assert conn.status == 404
    end
  end
end
