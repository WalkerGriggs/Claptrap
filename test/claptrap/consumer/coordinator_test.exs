defmodule Claptrap.Consumer.CoordinatorTest do
  use ExUnit.Case, async: false

  setup do
    start_supervised!(Claptrap.Consumer.Coordinator)
    :ok
  end

  describe "Consumer.Coordinator" do
    test "starts successfully" do
      assert Process.whereis(Claptrap.Consumer.Coordinator) |> is_pid()
    end

    test "receives tick messages" do
      pid = Process.whereis(Claptrap.Consumer.Coordinator)
      send(pid, :tick)
      :sys.get_state(pid)
      assert Process.alive?(pid)
    end
  end
end
