defmodule Claptrap.API.Handlers.SourcesTest do
  use Claptrap.DataCase, async: true

  @moduletag :integration
  @moduletag capture_log: true

  alias Claptrap.API.Plug, as: APIPlug
  alias Claptrap.Catalog

  @source_attrs %{type: "rss", name: "Feed", config: %{"url" => "https://example.com/feed"}}

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

  describe "GET /api/v1/sources" do
    test "returns empty list" do
      conn = call(:get, "/api/v1/sources")
      assert conn.status == 200
      assert %{"items" => []} = Jason.decode!(conn.resp_body)
    end

    test "returns sources" do
      {:ok, _} = Catalog.create_source(@source_attrs)
      conn = call(:get, "/api/v1/sources")
      assert conn.status == 200
      assert %{"items" => [%{"type" => "rss"}]} = Jason.decode!(conn.resp_body)
    end

    test "paginates with page_size and page_token" do
      for i <- 1..3 do
        {:ok, _} = Catalog.create_source(%{@source_attrs | name: "Feed #{i}"})
      end

      # First page
      conn = call(:get, "/api/v1/sources?page_size=2")
      body = Jason.decode!(conn.resp_body)
      assert length(body["items"]) == 2
      assert body["next_page_token"]

      # Second page
      conn = call(:get, "/api/v1/sources?page_size=2&page_token=#{body["next_page_token"]}")
      body = Jason.decode!(conn.resp_body)
      assert length(body["items"]) == 1
      refute Map.has_key?(body, "next_page_token")
    end
  end

  describe "POST /api/v1/sources" do
    test "creates a source with valid params" do
      conn =
        call(:post, "/api/v1/sources", %{
          "type" => "rss",
          "name" => "Feed",
          "config" => %{"url" => "https://example.com"}
        })

      assert conn.status == 201
      body = Jason.decode!(conn.resp_body)
      assert body["type"] == "rss"
      assert body["name"] == "Feed"
      refute Map.has_key?(body, "credentials")
    end

    test "returns 422 with invalid params" do
      conn = call(:post, "/api/v1/sources", %{})
      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert body["errors"]["type"]
      assert body["errors"]["name"]
      assert body["errors"]["config"]
    end
  end

  describe "GET /api/v1/sources/:id" do
    test "returns a source" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      conn = call(:get, "/api/v1/sources/#{source.id}")
      assert conn.status == 200
      assert Jason.decode!(conn.resp_body)["id"] == source.id
    end

    test "returns 404 for missing source" do
      conn = call(:get, "/api/v1/sources/#{Ecto.UUID.generate()}")
      assert conn.status == 404
    end

    test "returns 400 for malformed UUID" do
      conn = call(:get, "/api/v1/sources/not-a-uuid")
      assert conn.status == 400
    end
  end

  describe "PATCH /api/v1/sources/:id" do
    test "updates a source" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      conn = call(:patch, "/api/v1/sources/#{source.id}", %{"name" => "Updated"})
      assert conn.status == 200
      assert Jason.decode!(conn.resp_body)["name"] == "Updated"
    end

    test "returns 422 with invalid params" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      conn = call(:patch, "/api/v1/sources/#{source.id}", %{"name" => ""})
      assert conn.status == 422
    end
  end

  describe "DELETE /api/v1/sources/:id" do
    test "deletes a source" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      conn = call(:delete, "/api/v1/sources/#{source.id}")
      assert conn.status == 204
      assert Catalog.list_sources() == []
    end

    test "returns 404 for missing source" do
      conn = call(:delete, "/api/v1/sources/#{Ecto.UUID.generate()}")
      assert conn.status == 404
    end
  end
end
