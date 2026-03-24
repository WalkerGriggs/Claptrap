defmodule Claptrap.API.Handlers.EntriesTest do
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

  defp create_source, do: Catalog.create_source(@source_attrs)

  defp create_entry(source_id, overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          source_id: source_id,
          external_id: "ext-#{System.unique_integer([:positive])}",
          title: "Title",
          status: "unread"
        },
        overrides
      )

    Catalog.create_entry(attrs)
  end

  describe "GET /api/v1/entries" do
    test "returns empty list" do
      conn = call(:get, "/api/v1/entries")
      assert conn.status == 200
      assert %{"items" => []} = Jason.decode!(conn.resp_body)
    end

    test "returns entries" do
      {:ok, source} = create_source()
      {:ok, _} = create_entry(source.id)

      conn = call(:get, "/api/v1/entries")
      assert conn.status == 200
      assert %{"items" => [%{"title" => "Title"}]} = Jason.decode!(conn.resp_body)
    end

    test "paginates with page_size and page_token" do
      {:ok, source} = create_source()
      for _ <- 1..3, do: {:ok, _} = create_entry(source.id)

      # First page
      conn = call(:get, "/api/v1/entries?page_size=2")
      body = Jason.decode!(conn.resp_body)
      assert length(body["items"]) == 2
      assert body["next_page_token"]

      # Second page exhausts results
      conn = call(:get, "/api/v1/entries?page_size=2&page_token=#{body["next_page_token"]}")
      body = Jason.decode!(conn.resp_body)
      assert length(body["items"]) == 1
      refute Map.has_key?(body, "next_page_token")
    end
  end

  describe "POST /api/v1/entries" do
    test "creates an entry with valid params" do
      {:ok, source} = create_source()

      body = %{
        "source_id" => source.id,
        "external_id" => "ext-1",
        "title" => "New Entry",
        "status" => "unread"
      }

      conn = call(:post, "/api/v1/entries", body)
      assert conn.status == 201

      resp = Jason.decode!(conn.resp_body)
      assert resp["title"] == "New Entry"
      assert resp["source_id"] == source.id
      assert resp["id"]
    end

    test "returns 422 with missing required fields" do
      conn = call(:post, "/api/v1/entries", %{})
      assert conn.status == 422

      resp = Jason.decode!(conn.resp_body)
      assert resp["errors"]
    end

    test "returns 422 with invalid status value" do
      {:ok, source} = create_source()

      body = %{
        "source_id" => source.id,
        "external_id" => "ext-1",
        "title" => "Bad Status",
        "status" => "invalid"
      }

      conn = call(:post, "/api/v1/entries", body)
      assert conn.status == 422

      resp = Jason.decode!(conn.resp_body)
      assert resp["errors"]["status"]
    end
  end

  describe "GET /api/v1/entries/:id" do
    test "returns an entry" do
      {:ok, source} = create_source()
      {:ok, entry} = create_entry(source.id)

      conn = call(:get, "/api/v1/entries/#{entry.id}")
      assert conn.status == 200
      assert Jason.decode!(conn.resp_body)["id"] == entry.id
    end

    test "returns 404 for missing entry" do
      conn = call(:get, "/api/v1/entries/#{Ecto.UUID.generate()}")
      assert conn.status == 404
    end

    test "returns 400 for malformed UUID" do
      conn = call(:get, "/api/v1/entries/not-a-uuid")
      assert conn.status == 400
    end
  end

  describe "PATCH /api/v1/entries/:id" do
    test "updates an entry" do
      {:ok, source} = create_source()
      {:ok, entry} = create_entry(source.id)

      conn = call(:patch, "/api/v1/entries/#{entry.id}", %{"status" => "read"})
      assert conn.status == 200
      assert Jason.decode!(conn.resp_body)["status"] == "read"
    end

    test "returns 422 with invalid status" do
      {:ok, source} = create_source()
      {:ok, entry} = create_entry(source.id)

      conn = call(:patch, "/api/v1/entries/#{entry.id}", %{"status" => "invalid"})
      assert conn.status == 422
    end

    test "returns 404 for missing entry" do
      conn = call(:patch, "/api/v1/entries/#{Ecto.UUID.generate()}", %{"status" => "read"})
      assert conn.status == 404
    end
  end
end
