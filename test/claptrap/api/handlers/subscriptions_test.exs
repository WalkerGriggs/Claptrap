defmodule Claptrap.API.Handlers.SubscriptionsTest do
  use Claptrap.DataCase, async: true

  alias Claptrap.API.Plug, as: APIPlug
  alias Claptrap.Catalog

  @sink_attrs %{type: "webhook", name: "Hook", config: %{"url" => "https://example.com/hook"}}

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

  defp create_sink, do: Catalog.create_sink(@sink_attrs)

  describe "GET /api/v1/subscriptions" do
    test "returns empty list" do
      conn = call(:get, "/api/v1/subscriptions")
      assert conn.status == 200
      assert Jason.decode!(conn.resp_body) == []
    end

    test "returns subscriptions" do
      {:ok, sink} = create_sink()
      {:ok, _} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})

      conn = call(:get, "/api/v1/subscriptions")
      assert conn.status == 200
      assert [%{"tags" => ["elixir"]}] = Jason.decode!(conn.resp_body)
    end

    test "filters by sink_id" do
      {:ok, s1} = create_sink()
      {:ok, s2} = Catalog.create_sink(%{@sink_attrs | name: "Other"})
      {:ok, _} = Catalog.create_subscription(%{sink_id: s1.id, tags: ["a"]})
      {:ok, _} = Catalog.create_subscription(%{sink_id: s2.id, tags: ["b"]})

      conn = call(:get, "/api/v1/subscriptions?sink_id=#{s1.id}")
      subs = Jason.decode!(conn.resp_body)
      assert length(subs) == 1
      assert hd(subs)["sink_id"] == s1.id
    end
  end

  describe "POST /api/v1/subscriptions" do
    test "creates a subscription" do
      {:ok, sink} = create_sink()
      conn = call(:post, "/api/v1/subscriptions", %{"sink_id" => sink.id, "tags" => ["elixir"]})
      assert conn.status == 201
      body = Jason.decode!(conn.resp_body)
      assert body["sink_id"] == sink.id
      assert body["tags"] == ["elixir"]
    end

    test "returns 422 with invalid params" do
      conn = call(:post, "/api/v1/subscriptions", %{})
      assert conn.status == 422
      assert Jason.decode!(conn.resp_body)["errors"]
    end
  end

  describe "GET /api/v1/subscriptions/:id" do
    test "returns a subscription" do
      {:ok, sink} = create_sink()
      {:ok, sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})

      conn = call(:get, "/api/v1/subscriptions/#{sub.id}")
      assert conn.status == 200
      assert Jason.decode!(conn.resp_body)["id"] == sub.id
    end

    test "returns 404 for missing subscription" do
      conn = call(:get, "/api/v1/subscriptions/#{Ecto.UUID.generate()}")
      assert conn.status == 404
    end

    test "returns 400 for malformed UUID" do
      conn = call(:get, "/api/v1/subscriptions/not-a-uuid")
      assert conn.status == 400
    end
  end

  describe "DELETE /api/v1/subscriptions/:id" do
    test "deletes a subscription" do
      {:ok, sink} = create_sink()
      {:ok, sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})

      conn = call(:delete, "/api/v1/subscriptions/#{sub.id}")
      assert conn.status == 204
      assert Catalog.list_subscriptions() == []
    end

    test "returns 404 for missing subscription" do
      conn = call(:delete, "/api/v1/subscriptions/#{Ecto.UUID.generate()}")
      assert conn.status == 404
    end
  end
end
