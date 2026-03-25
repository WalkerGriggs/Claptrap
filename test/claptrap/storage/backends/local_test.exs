defmodule Claptrap.Storage.Backends.LocalTest do
  use ExUnit.Case, async: true

  alias Claptrap.Storage.Backends.Local

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "claptrap_local_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    %{config: %{root_dir: tmp_dir}, tmp_dir: tmp_dir}
  end

  describe "write/3" do
    test "chunks written match file contents", %{config: config, tmp_dir: tmp_dir} do
      :ok = Local.write("hello.txt", ["hello ", "world"], config)
      assert File.read!(Path.join(tmp_dir, "hello.txt")) == "hello world"
    end

    test "empty enumerable creates empty file", %{config: config, tmp_dir: tmp_dir} do
      :ok = Local.write("empty.txt", [], config)
      assert File.read!(Path.join(tmp_dir, "empty.txt")) == ""
    end

    test "error when root_dir is missing" do
      config = %{root_dir: "/nonexistent_#{:erlang.unique_integer([:positive])}"}
      assert_raise File.Error, fn -> Local.write("test.txt", ["data"], config) end
    end
  end

  describe "read/2" do
    test "round-trip write and read via stream", %{config: config} do
      :ok = Local.write("roundtrip.txt", ["foo", "bar"], config)
      {:ok, stream} = Local.read("roundtrip.txt", config)
      assert Enum.join(stream) == "foobar"
    end

    test "stream is lazy and produces correct data for multi-chunk file", %{config: config} do
      chunk = String.duplicate("x", 65_536)
      :ok = Local.write("big.bin", [chunk, chunk], config)
      {:ok, stream} = Local.read("big.bin", config)
      result = Enum.to_list(stream)
      assert IO.iodata_to_binary(result) == String.duplicate("x", 131_072)
    end

    test "not_found for missing key", %{config: config} do
      assert {:error, :not_found} = Local.read("missing.txt", config)
    end
  end

  describe "delete/2" do
    test "removes file", %{config: config, tmp_dir: tmp_dir} do
      File.write!(Path.join(tmp_dir, "delete_me.txt"), "data")
      :ok = Local.delete("delete_me.txt", config)
      refute File.exists?(Path.join(tmp_dir, "delete_me.txt"))
    end

    test "not_found for missing key", %{config: config} do
      assert {:error, :not_found} = Local.delete("ghost.txt", config)
    end
  end

  describe "list/2" do
    test "all keys returned", %{config: config, tmp_dir: tmp_dir} do
      File.write!(Path.join(tmp_dir, "a.txt"), "")
      File.write!(Path.join(tmp_dir, "b.txt"), "")
      {:ok, keys} = Local.list("", config)
      assert keys == ["a.txt", "b.txt"]
    end

    test "prefix filtering works", %{config: config, tmp_dir: tmp_dir} do
      File.write!(Path.join(tmp_dir, "report-1.txt"), "")
      File.write!(Path.join(tmp_dir, "report-2.txt"), "")
      File.write!(Path.join(tmp_dir, "other.txt"), "")
      {:ok, keys} = Local.list("report", config)
      assert keys == ["report-1.txt", "report-2.txt"]
    end

    test "empty dir returns empty list", %{config: config} do
      {:ok, keys} = Local.list("", config)
      assert keys == []
    end
  end

  describe "exists?/2" do
    test "true for existing key", %{config: config, tmp_dir: tmp_dir} do
      File.write!(Path.join(tmp_dir, "exists.txt"), "data")
      assert {:ok, true} = Local.exists?("exists.txt", config)
    end

    test "false for missing key", %{config: config} do
      assert {:ok, false} = Local.exists?("nope.txt", config)
    end
  end
end
