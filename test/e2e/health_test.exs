defmodule Claptrap.E2E.HealthTest do
  use Claptrap.E2E.Case

  describe "GET /health" do
    test "returns 200 with ok status" do
      {status, body} = http_get("/health")
      assert status == 200
      assert body == %{"status" => "ok"}
    end
  end

  describe "GET /ready" do
    test "returns 200 when database is reachable" do
      {status, body} = http_get("/ready")
      assert status == 200
      assert body == %{"status" => "ready"}
    end
  end

  describe "unknown routes" do
    test "returns 404 for unmatched paths" do
      {status, body} = http_get("/nonexistent")
      assert status == 404
      assert body == %{"error" => "not found"}
    end
  end
end
