defmodule Claptrap.E2E.EntriesTest do
  use Claptrap.E2E.Case, async: false

  @source_params %{
    "type" => "rss",
    "name" => "Entry Test Source",
    "config" => %{"url" => "https://example.com/feed"}
  }

  defp create_source(ctx) do
    {201, source} = http_post("/api/v1/sources", @source_params)
    track_cleanup(ctx, "/api/v1/sources/#{source["id"]}")
    source
  end

  defp entry_params(source_id, overrides \\ %{}) do
    Map.merge(
      %{
        "source_id" => source_id,
        "external_id" => "ext-#{System.unique_integer([:positive])}",
        "title" => "Test Entry",
        "status" => "unread",
        "tags" => ["elixir"]
      },
      overrides
    )
  end

  describe "POST /api/v1/entries" do
    test "creates an entry with valid params", ctx do
      source = create_source(ctx)

      params = %{
        "source_id" => source["id"],
        "external_id" => "ext-1",
        "title" => "Test Entry",
        "status" => "unread",
        "tags" => ["elixir"]
      }

      {status, body} = http_post("/api/v1/entries", params)

      assert status == 201

      assert %{
               "id" => id,
               "source_id" => source_id,
               "external_id" => "ext-1",
               "title" => "Test Entry",
               "status" => "unread",
               "tags" => ["elixir"]
             } = body

      assert is_binary(id)
      assert source_id == source["id"]
    end

    test "returns 422 with missing required fields", _ctx do
      {status, body} = http_post("/api/v1/entries", %{})

      assert status == 422
      assert %{"errors" => _} = body
    end

    test "returns 422 with invalid status value", ctx do
      source = create_source(ctx)

      params = %{
        "source_id" => source["id"],
        "external_id" => "ext-bad",
        "title" => "Bad Status",
        "status" => "invalid"
      }

      {status, body} = http_post("/api/v1/entries", params)

      assert status == 422
      assert %{"errors" => %{"status" => _}} = body
    end
  end

  describe "GET /api/v1/entries/:id" do
    test "returns an entry by id", ctx do
      source = create_source(ctx)
      {201, created} = http_post("/api/v1/entries", entry_params(source["id"]))

      {status, body} = http_get("/api/v1/entries/#{created["id"]}")

      assert status == 200
      assert body == created
    end

    test "returns 404 for nonexistent uuid", _ctx do
      {status, _body} = http_get("/api/v1/entries/00000000-0000-0000-0000-000000000000")

      assert status == 404
    end

    test "returns 400 for malformed id", _ctx do
      {status, _body} = http_get("/api/v1/entries/not-a-uuid")

      assert status == 400
    end
  end

  describe "GET /api/v1/entries" do
    test "returns list containing created entries", ctx do
      source = create_source(ctx)
      {201, created} = http_post("/api/v1/entries", entry_params(source["id"]))

      {status, body} = http_get("/api/v1/entries")

      assert status == 200
      assert %{"items" => items} = body
      assert Enum.any?(items, &(&1["id"] == created["id"]))
    end
  end

  describe "PATCH /api/v1/entries/:id" do
    test "updates entry status and GET confirms persistence", ctx do
      source = create_source(ctx)
      {201, created} = http_post("/api/v1/entries", entry_params(source["id"]))

      {status, body} = http_patch("/api/v1/entries/#{created["id"]}", %{"status" => "read"})

      assert status == 200
      assert body["status"] == "read"

      {200, fetched} = http_get("/api/v1/entries/#{created["id"]}")
      assert fetched["status"] == "read"
    end

    test "returns 422 with invalid status", ctx do
      source = create_source(ctx)
      {201, created} = http_post("/api/v1/entries", entry_params(source["id"]))

      {status, body} =
        http_patch("/api/v1/entries/#{created["id"]}", %{"status" => "deleted"})

      assert status == 422
      assert %{"errors" => %{"status" => _}} = body
    end
  end

  describe "status lifecycle" do
    test "transitions through unread -> in_progress -> read -> archived", ctx do
      source = create_source(ctx)

      {201, created} =
        http_post("/api/v1/entries", entry_params(source["id"], %{"status" => "unread"}))

      assert created["status"] == "unread"

      for next_status <- ["in_progress", "read", "archived"] do
        {status, body} =
          http_patch("/api/v1/entries/#{created["id"]}", %{"status" => next_status})

        assert status == 200
        assert body["status"] == next_status
      end
    end
  end

  describe "deduplication" do
    test "second POST with same (source_id, external_id) does not create a duplicate", ctx do
      source = create_source(ctx)

      params = %{
        "source_id" => source["id"],
        "external_id" => "dup-ext-1",
        "title" => "Dedup Entry",
        "status" => "unread",
        "tags" => ["elixir"]
      }

      {first_status, _first_body} = http_post("/api/v1/entries", params)
      assert first_status == 201

      {second_status, _second_body} = http_post("/api/v1/entries", params)
      assert second_status in [200, 201]

      {200, list_body} = http_get("/api/v1/entries")
      matching = Enum.filter(list_body["items"], &(&1["external_id"] == "dup-ext-1"))
      assert length(matching) == 1
    end
  end

  describe "GET /api/v1/entries pagination" do
    test "paginates with page_size and page_token", ctx do
      source = create_source(ctx)

      for i <- 1..3 do
        {201, _} =
          http_post(
            "/api/v1/entries",
            entry_params(source["id"], %{"external_id" => "page-ext-#{i}"})
          )
      end

      {200, page1} = http_get("/api/v1/entries?page_size=2")
      assert length(page1["items"]) == 2
      assert page1["next_page_token"]

      {200, page2} =
        http_get("/api/v1/entries?page_size=2&page_token=#{page1["next_page_token"]}")

      assert length(page2["items"]) == 1
      refute Map.has_key?(page2, "next_page_token")
    end
  end

  describe "cascade delete" do
    test "deleting a source removes its entries", ctx do
      source = create_source(ctx)

      for i <- 1..2 do
        {201, _} =
          http_post(
            "/api/v1/entries",
            entry_params(source["id"], %{"external_id" => "cascade-#{i}"})
          )
      end

      {200, before_delete} = http_get("/api/v1/entries")

      cascade_entries =
        Enum.filter(before_delete["items"], &(&1["source_id"] == source["id"]))

      assert length(cascade_entries) == 2

      {204, %{}} = http_delete("/api/v1/sources/#{source["id"]}")

      {200, after_delete} = http_get("/api/v1/entries")

      remaining =
        Enum.filter(after_delete["items"], &(&1["source_id"] == source["id"]))

      assert remaining == []
    end
  end
end
