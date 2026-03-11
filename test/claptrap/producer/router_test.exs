defmodule Claptrap.Producer.RouterTest do
  use ExUnit.Case, async: false

  setup do
    start_supervised!(Claptrap.Producer.Router)
    :ok
  end

  describe "Producer.Router" do
    test "starts successfully" do
      assert Process.whereis(Claptrap.Producer.Router) |> is_pid()
    end

    test "handles entries_ingested messages" do
      pid = Process.whereis(Claptrap.Producer.Router)
      send(pid, {:entries_ingested, "source-1", []})
      :sys.get_state(pid)
      assert Process.alive?(pid)
    end
  end
end
