defmodule Claptrap.E2E.SourcesTest do
  use Claptrap.E2E.Case, async: false

  @valid_params %{
    "type" => "rss",
    "name" => "Test Feed",
    "config" => %{"url" => "https://example.com/feed"}
  }

  describe "POST /api/v1/sources" do
    test "creates a source with valid params", ctx do
      {status, body} = http_post("/api/v1/sources", @valid_params)
      track_cleanup(ctx, "/api/v1/sources/#{body["id"]}")

      assert status == 201

      assert %{
               "id" => id,
               "type" => "rss",
               "name" => "Test Feed",
               "config" => %{"url" => "https://example.com/feed"}
             } = body

      assert is_binary(id)
      refute Map.has_key?(body, "credentials")
    end

    test "returns 422 with invalid params" do
      {status, body} = http_post("/api/v1/sources", %{})

      assert status == 422
      assert %{"errors" => %{"type" => _, "name" => _, "config" => _}} = body
    end
  end

  describe "GET /api/v1/sources/:id" do
    test "returns a source by id", ctx do
      {201, created} = http_post("/api/v1/sources", @valid_params)
      track_cleanup(ctx, "/api/v1/sources/#{created["id"]}")

      {status, body} = http_get("/api/v1/sources/#{created["id"]}")

      assert status == 200
      assert body == created
    end

    test "returns 404 for nonexistent uuid" do
      {status, _body} = http_get("/api/v1/sources/00000000-0000-0000-0000-000000000000")

      assert status == 404
    end

    test "returns 400 for malformed id" do
      {status, _body} = http_get("/api/v1/sources/not-a-uuid")

      assert status == 400
    end
  end

  describe "GET /api/v1/sources" do
    test "returns list containing created source", ctx do
      {201, created} = http_post("/api/v1/sources", @valid_params)
      track_cleanup(ctx, "/api/v1/sources/#{created["id"]}")

      {status, body} = http_get("/api/v1/sources")

      assert status == 200
      assert %{"items" => items} = body
      assert Enum.any?(items, &(&1 == created))
    end

    test "returns empty list when no sources exist" do
      {status, body} = http_get("/api/v1/sources")

      assert status == 200
      assert %{"items" => []} = body
    end
  end

  describe "PATCH /api/v1/sources/:id" do
    test "updates a source name", ctx do
      {201, created} = http_post("/api/v1/sources", @valid_params)
      track_cleanup(ctx, "/api/v1/sources/#{created["id"]}")

      {status, body} = http_patch("/api/v1/sources/#{created["id"]}", %{"name" => "Updated Name"})

      assert status == 200
      assert body["name"] == "Updated Name"
      assert body["id"] == created["id"]

      {200, fetched} = http_get("/api/v1/sources/#{created["id"]}")
      assert fetched == body
    end

    test "returns 422 with invalid params", ctx do
      {201, created} = http_post("/api/v1/sources", @valid_params)
      track_cleanup(ctx, "/api/v1/sources/#{created["id"]}")

      {status, _body} = http_patch("/api/v1/sources/#{created["id"]}", %{"name" => ""})

      assert status == 422
    end
  end

  describe "DELETE /api/v1/sources/:id" do
    test "deletes a source and subsequent GET returns 404", ctx do
      {201, created} = http_post("/api/v1/sources", @valid_params)
      track_cleanup(ctx, "/api/v1/sources/#{created["id"]}")

      {status, body} = http_delete("/api/v1/sources/#{created["id"]}")

      assert status == 204
      assert body == %{}

      {404, _} = http_get("/api/v1/sources/#{created["id"]}")
    end

    test "returns 404 for nonexistent uuid" do
      {status, _body} = http_delete("/api/v1/sources/00000000-0000-0000-0000-000000000000")

      assert status == 404
    end
  end

  describe "GET /api/v1/sources pagination" do
    test "paginates with page_size and page_token", ctx do
      ids =
        for i <- 1..3 do
          {201, created} =
            http_post("/api/v1/sources", %{@valid_params | "name" => "Feed #{i}"})

          track_cleanup(ctx, "/api/v1/sources/#{created["id"]}")
          created["id"]
        end

      assert length(ids) == 3

      {200, page1} = http_get("/api/v1/sources?page_size=2")
      assert length(page1["items"]) == 2
      assert page1["next_page_token"]

      {200, page2} = http_get("/api/v1/sources?page_size=2&page_token=#{page1["next_page_token"]}")
      assert length(page2["items"]) == 1
      refute Map.has_key?(page2, "next_page_token")
    end
  end
end
