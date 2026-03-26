defmodule Claptrap.StorageTest do
  use ExUnit.Case, async: false

  alias Claptrap.Storage

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "claptrap_storage_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)

    original_config = Application.get_env(:claptrap, Claptrap.Storage)

    Application.put_env(:claptrap, Claptrap.Storage,
      backend: Claptrap.Storage.Backends.Local,
      root_dir: tmp_dir
    )

    on_exit(fn ->
      if original_config do
        Application.put_env(:claptrap, Claptrap.Storage, original_config)
      else
        Application.delete_env(:claptrap, Claptrap.Storage)
      end

      File.rm_rf!(tmp_dir)
    end)

    %{tmp_dir: tmp_dir}
  end

  describe "round-trip" do
    test "write -> read -> exists? -> list -> delete cycle" do
      :ok = Storage.write("artifact.txt", ["hello ", "world"])

      {:ok, stream} = Storage.read("artifact.txt")
      assert Enum.join(stream) == "hello world"

      assert {:ok, true} = Storage.exists?("artifact.txt")
      assert {:ok, ["artifact.txt"]} = Storage.list()

      :ok = Storage.delete("artifact.txt")
      assert {:ok, false} = Storage.exists?("artifact.txt")
    end
  end

  describe "key validation rejects" do
    test "empty string" do
      assert_raise ArgumentError, fn -> Storage.write("", ["data"]) end
    end

    test "path traversal" do
      assert_raise ArgumentError, fn -> Storage.write("../etc/passwd", ["data"]) end
    end

    test "hidden file" do
      assert_raise ArgumentError, fn -> Storage.write(".hidden", ["data"]) end
    end

    test "absolute path" do
      assert_raise ArgumentError, fn -> Storage.write("/absolute", ["data"]) end
    end

    test "spaces" do
      assert_raise ArgumentError, fn -> Storage.write("has spaces", ["data"]) end
    end

    test "null bytes" do
      assert_raise ArgumentError, fn -> Storage.write("bad\0key", ["data"]) end
    end

    test "backslash" do
      assert_raise ArgumentError, fn -> Storage.write("back\\slash", ["data"]) end
    end
  end

  describe "prefix validation rejects" do
    test "dot prefix" do
      assert_raise ArgumentError, fn -> Storage.list(".") end
    end

    test "double dot prefix" do
      assert_raise ArgumentError, fn -> Storage.list("..") end
    end

    test "dot-leading prefix" do
      assert_raise ArgumentError, fn -> Storage.list(".hidden") end
    end
  end

  describe "prefix validation accepts" do
    test "empty string lists all" do
      :ok = Storage.write("test-file", ["data"])
      assert {:ok, ["test-file"]} = Storage.list("")
    end

    test "alphanumeric prefix" do
      :ok = Storage.write("abc123", ["data"])
      assert {:ok, ["abc123"]} = Storage.list("abc")
    end
  end

  describe "key validation accepts" do
    test "valid-key.txt" do
      :ok = Storage.write("valid-key.txt", ["data"])
      assert {:ok, true} = Storage.exists?("valid-key.txt")
    end

    test "abc123" do
      :ok = Storage.write("abc123", ["data"])
      assert {:ok, true} = Storage.exists?("abc123")
    end

    test "file_name.pdf" do
      :ok = Storage.write("file_name.pdf", ["data"])
      assert {:ok, true} = Storage.exists?("file_name.pdf")
    end

    test "A-Za-z0-9._-mixed" do
      :ok = Storage.write("A-Za-z0-9._-mixed", ["data"])
      assert {:ok, true} = Storage.exists?("A-Za-z0-9._-mixed")
    end
  end
end
