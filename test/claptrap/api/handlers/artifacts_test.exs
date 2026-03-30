defmodule Claptrap.API.Handlers.ArtifactsTest do
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

  defp create_entry(source_id) do
    Catalog.create_entry(%{
      source_id: source_id,
      external_id: "ext-#{System.unique_integer([:positive])}",
      title: "Title",
      status: "unread"
    })
  end

  defp create_artifact(entry_id, overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          entry_id: entry_id,
          format: "markdown",
          extractor: "test"
        },
        overrides
      )

    Catalog.create_artifact(attrs)
  end

  describe "GET /api/v1/artifacts" do
    test "returns empty list" do
      conn = call(:get, "/api/v1/artifacts")
      assert conn.status == 200
      assert %{"items" => []} = Jason.decode!(conn.resp_body)
    end

    test "returns artifacts" do
      {:ok, source} = create_source()
      {:ok, entry} = create_entry(source.id)
      {:ok, _} = create_artifact(entry.id)

      conn = call(:get, "/api/v1/artifacts")
      assert conn.status == 200

      assert %{"items" => [%{"format" => "markdown", "extractor" => "test"}]} =
               Jason.decode!(conn.resp_body)
    end

    test "filters by entry_id" do
      {:ok, source} = create_source()
      {:ok, entry1} = create_entry(source.id)
      {:ok, entry2} = create_entry(source.id)
      {:ok, _} = create_artifact(entry1.id)
      {:ok, _} = create_artifact(entry2.id)

      conn = call(:get, "/api/v1/artifacts?entry_id=#{entry1.id}")
      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body["items"]) == 1
      assert hd(body["items"])["entry_id"] == entry1.id
    end

    test "paginates with page_size and page_token" do
      {:ok, source} = create_source()
      {:ok, entry} = create_entry(source.id)

      for fmt <- ["markdown", "html", "pdf"] do
        {:ok, _} = create_artifact(entry.id, %{format: fmt})
      end

      conn = call(:get, "/api/v1/artifacts?page_size=2")
      body = Jason.decode!(conn.resp_body)
      assert length(body["items"]) == 2
      assert body["next_page_token"]

      conn = call(:get, "/api/v1/artifacts?page_size=2&page_token=#{body["next_page_token"]}")
      body = Jason.decode!(conn.resp_body)
      assert length(body["items"]) == 1
      refute Map.has_key?(body, "next_page_token")
    end
  end

  describe "POST /api/v1/artifacts" do
    test "creates an artifact with valid params" do
      {:ok, source} = create_source()
      {:ok, entry} = create_entry(source.id)

      body = %{
        "entry_id" => entry.id,
        "format" => "html",
        "extractor" => "firecrawl",
        "content" => "<p>Hello</p>",
        "content_type" => "text/html",
        "byte_size" => 12
      }

      conn = call(:post, "/api/v1/artifacts", body)
      assert conn.status == 201

      resp = Jason.decode!(conn.resp_body)

      assert %{
               "id" => _,
               "entry_id" => _,
               "format" => "html",
               "extractor" => "firecrawl",
               "content" => "<p>Hello</p>",
               "content_type" => "text/html",
               "byte_size" => 12,
               "metadata" => nil,
               "inserted_at" => _,
               "updated_at" => _
             } = resp
    end

    test "returns 422 with missing required fields" do
      conn = call(:post, "/api/v1/artifacts", %{})
      assert conn.status == 422

      resp = Jason.decode!(conn.resp_body)
      assert resp["errors"]
    end

    test "returns 422 with invalid format value" do
      {:ok, source} = create_source()
      {:ok, entry} = create_entry(source.id)

      body = %{
        "entry_id" => entry.id,
        "format" => "invalid",
        "extractor" => "test"
      }

      conn = call(:post, "/api/v1/artifacts", body)
      assert conn.status == 422

      resp = Jason.decode!(conn.resp_body)
      assert resp["errors"]["format"]
    end
  end

  describe "GET /api/v1/artifacts/:id" do
    test "returns an artifact" do
      {:ok, source} = create_source()
      {:ok, entry} = create_entry(source.id)
      {:ok, artifact} = create_artifact(entry.id, %{content: "# Hello", content_type: "text/markdown"})

      conn = call(:get, "/api/v1/artifacts/#{artifact.id}")
      assert conn.status == 200

      resp = Jason.decode!(conn.resp_body)

      assert %{
               "id" => _,
               "entry_id" => _,
               "format" => "markdown",
               "content" => "# Hello",
               "content_type" => "text/markdown",
               "extractor" => "test",
               "inserted_at" => _,
               "updated_at" => _
             } = resp
    end

    test "returns 404 for missing artifact" do
      conn = call(:get, "/api/v1/artifacts/#{Ecto.UUID.generate()}")
      assert conn.status == 404
    end

    test "returns 400 for malformed UUID" do
      conn = call(:get, "/api/v1/artifacts/not-a-uuid")
      assert conn.status == 400
    end
  end

  describe "DELETE /api/v1/artifacts/:id" do
    test "deletes an artifact" do
      {:ok, source} = create_source()
      {:ok, entry} = create_entry(source.id)
      {:ok, artifact} = create_artifact(entry.id)

      conn = call(:delete, "/api/v1/artifacts/#{artifact.id}")
      assert conn.status == 204
      assert conn.resp_body == ""

      conn = call(:get, "/api/v1/artifacts/#{artifact.id}")
      assert conn.status == 404
    end

    test "returns 404 for missing artifact" do
      conn = call(:delete, "/api/v1/artifacts/#{Ecto.UUID.generate()}")
      assert conn.status == 404
    end
  end
end
