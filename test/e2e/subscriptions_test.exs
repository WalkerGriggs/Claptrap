defmodule Claptrap.E2E.SubscriptionsTest do
  use Claptrap.E2E.Case, async: false

  @sink_params %{
    "type" => "rss",
    "name" => "Subscription Test Sink",
    "config" => %{"description" => "Test feed"}
  }

  defp create_sink(ctx, opts \\ []) do
    name = Keyword.get(opts, :name, @sink_params["name"])
    params = %{@sink_params | "name" => name}
    {201, sink} = http_post("/api/v1/sinks", params)
    track_cleanup(ctx, "/api/v1/sinks/#{sink["id"]}")
    sink
  end

  defp create_subscription(ctx, sink_id, tags) do
    params = %{"sink_id" => sink_id, "tags" => tags}
    {201, subscription} = http_post("/api/v1/subscriptions", params)
    track_cleanup(ctx, "/api/v1/subscriptions/#{subscription["id"]}")
    subscription
  end

  describe "POST /api/v1/subscriptions" do
    test "creates a subscription with valid params", ctx do
      sink = create_sink(ctx)
      {status, body} = http_post("/api/v1/subscriptions", %{"sink_id" => sink["id"], "tags" => ["elixir", "otp"]})
      track_cleanup(ctx, "/api/v1/subscriptions/#{body["id"]}")

      assert status == 201

      assert %{
               "id" => id,
               "sink_id" => sink_id,
               "tags" => ["elixir", "otp"]
             } = body

      assert is_binary(id)
      assert sink_id == sink["id"]
    end

    test "returns 422 with missing sink_id" do
      {status, body} = http_post("/api/v1/subscriptions", %{"tags" => ["elixir"]})

      assert status == 422
      assert %{"errors" => errors} = body
      assert Map.has_key?(errors, "sink_id")
    end

    test "returns 422 with missing tags" do
      {status, body} = http_post("/api/v1/subscriptions", %{})

      assert status == 422
      assert %{"errors" => _} = body
    end
  end

  describe "GET /api/v1/subscriptions/:id" do
    test "returns a subscription by id", ctx do
      sink = create_sink(ctx)
      subscription = create_subscription(ctx, sink["id"], ["elixir", "otp"])

      {status, body} = http_get("/api/v1/subscriptions/#{subscription["id"]}")

      assert status == 200
      assert body == subscription
    end

    test "returns 404 for nonexistent uuid" do
      {status, _body} = http_get("/api/v1/subscriptions/00000000-0000-0000-0000-000000000000")

      assert status == 404
    end

    test "returns 400 for malformed id" do
      {status, _body} = http_get("/api/v1/subscriptions/not-a-uuid")

      assert status == 400
    end
  end

  describe "GET /api/v1/subscriptions" do
    test "returns list containing created subscription", ctx do
      sink = create_sink(ctx)
      subscription = create_subscription(ctx, sink["id"], ["elixir"])

      {status, body} = http_get("/api/v1/subscriptions")

      assert status == 200
      assert %{"items" => items} = body
      assert Enum.any?(items, &(&1 == subscription))
    end
  end

  describe "DELETE /api/v1/subscriptions/:id" do
    test "deletes a subscription and subsequent GET returns 404", ctx do
      sink = create_sink(ctx)
      subscription = create_subscription(ctx, sink["id"], ["elixir"])

      {status, body} = http_delete("/api/v1/subscriptions/#{subscription["id"]}")

      assert status == 204
      assert body == %{}

      {404, _} = http_get("/api/v1/subscriptions/#{subscription["id"]}")
    end
  end

  describe "cascade delete (sink deletion removes subscriptions)" do
    test "deleting a sink cascades to its subscriptions", ctx do
      sink = create_sink(ctx)

      params = %{"sink_id" => sink["id"], "tags" => ["cascade-test"]}
      {201, subscription} = http_post("/api/v1/subscriptions", params)

      {204, _} = http_delete("/api/v1/sinks/#{sink["id"]}")

      {404, _} = http_get("/api/v1/subscriptions/#{subscription["id"]}")
    end
  end

  describe "GET /api/v1/subscriptions pagination" do
    test "paginates with page_size and page_token", ctx do
      sink = create_sink(ctx)

      for tags <- [["alpha"], ["beta"], ["gamma"]] do
        create_subscription(ctx, sink["id"], tags)
      end

      {200, page1} = http_get("/api/v1/subscriptions?page_size=2")
      assert length(page1["items"]) == 2
      assert page1["next_page_token"]

      {200, page2} = http_get("/api/v1/subscriptions?page_size=2&page_token=#{page1["next_page_token"]}")

      assert length(page2["items"]) == 1
      refute Map.has_key?(page2, "next_page_token")
    end
  end
end
