defmodule Claptrap.PubSubTest do
  use ExUnit.Case, async: true

  alias Claptrap.PubSub

  describe "topic helpers" do
    test "returns entries:new topic" do
      assert PubSub.topic_entries_new() == "entries:new"
    end

    test "returns catalog:changed topic" do
      assert PubSub.topic_catalog_changed() == "catalog:changed"
    end
  end

  describe "subscribe/1 and broadcast/2" do
    test "delivers messages to subscribers" do
      topic = "test:#{System.unique_integer([:positive])}"

      :ok = PubSub.subscribe(topic)
      :ok = PubSub.broadcast(topic, {:ping, :hello})

      assert_receive {:ping, :hello}
    end

    test "does not deliver messages to non-subscribers" do
      topic = "test:#{System.unique_integer([:positive])}"

      :ok = PubSub.broadcast(topic, {:ping, :missed})

      refute_receive {:ping, :missed}, 50
    end
  end

  describe "broadcast!/2" do
    test "delivers messages to subscribers" do
      topic = "test:#{System.unique_integer([:positive])}"

      :ok = PubSub.subscribe(topic)
      :ok = PubSub.broadcast!(topic, {:ping, :bang})

      assert_receive {:ping, :bang}
    end
  end
end
