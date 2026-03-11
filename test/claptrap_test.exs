defmodule ClaptrapTest do
  use ExUnit.Case

  test "application starts successfully" do
    assert Process.whereis(Claptrap.Supervisor) != nil
  end

  test "repo is running" do
    assert Process.whereis(Claptrap.Repo) != nil
  end

  test "pubsub is running" do
    assert Process.whereis(Claptrap.PubSub) != nil ||
             Phoenix.PubSub.node_name(Claptrap.PubSub) != nil
  end
end
