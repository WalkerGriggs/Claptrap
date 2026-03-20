defmodule Claptrap.API.Handlers.EntriesTest do
  use Claptrap.DataCase, async: true

  @moduletag :integration
  @moduletag capture_log: true

  alias Claptrap.API.Plug, as: APIPlug
  alias Claptrap.Catalog

  @source_attrs %{type: "rss", name: "Feed", config: %{"url" => "https://example.com/feed"}}

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
      assert Jason.decode!(conn.resp_body) == []
    end

    test "returns entries" do
      {:ok, source} = create_source()
      {:ok, _} = create_entry(source.id)

      conn = call(:get, "/api/v1/entries")
      assert conn.status == 200
      assert [%{"title" => "Title"}] = Jason.decode!(conn.resp_body)
    end

    test "filters by status" do
      {:ok, source} = create_source()
      {:ok, _} = create_entry(source.id, %{status: "unread"})
      {:ok, _} = create_entry(source.id, %{status: "read"})

      conn = call(:get, "/api/v1/entries?status=unread")
      entries = Jason.decode!(conn.resp_body)
      assert length(entries) == 1
      assert hd(entries)["status"] == "unread"
    end

    test "filters by source_id" do
      {:ok, s1} = create_source()
      {:ok, s2} = Catalog.create_source(%{@source_attrs | name: "Other"})
      {:ok, _} = create_entry(s1.id)
      {:ok, _} = create_entry(s2.id)

      conn = call(:get, "/api/v1/entries?source_id=#{s1.id}")
      entries = Jason.decode!(conn.resp_body)
      assert length(entries) == 1
      assert hd(entries)["source_id"] == s1.id
    end

    test "supports limit" do
      {:ok, source} = create_source()
      for _ <- 1..5, do: {:ok, _} = create_entry(source.id)

      conn = call(:get, "/api/v1/entries?limit=2")
      entries = Jason.decode!(conn.resp_body)
      assert length(entries) == 2
    end

    test "ignores negative limit" do
      {:ok, source} = create_source()
      {:ok, _} = create_entry(source.id)

      conn = call(:get, "/api/v1/entries?limit=-1")
      assert conn.status == 200
      assert length(Jason.decode!(conn.resp_body)) == 1
    end

    test "ignores zero limit" do
      {:ok, source} = create_source()
      {:ok, _} = create_entry(source.id)

      conn = call(:get, "/api/v1/entries?limit=0")
      assert conn.status == 200
      assert length(Jason.decode!(conn.resp_body)) == 1
    end

    test "returns entries ordered by inserted_at desc by default" do
      {:ok, source} = create_source()
      {:ok, old} = create_entry(source.id, %{title: "Old"})
      # Ensure different inserted_at timestamps
      Process.sleep(10)
      {:ok, recent} = create_entry(source.id, %{title: "Recent"})

      conn = call(:get, "/api/v1/entries")
      entries = Jason.decode!(conn.resp_body)
      assert hd(entries)["id"] == recent.id
      assert List.last(entries)["id"] == old.id
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
