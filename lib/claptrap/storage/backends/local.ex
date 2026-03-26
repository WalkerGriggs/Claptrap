defmodule Claptrap.Storage.Backends.Local do
  @moduledoc """
  Filesystem-backed storage adapter.

  This module implements `Claptrap.Storage.Adapter` by mapping
  storage keys directly to files inside a configurable root
  directory. It is the default backend used by `Claptrap.Storage`
  and is suitable for single-node deployments where network-
  attached or cloud object storage is not required.

  ## Configuration

  The adapter expects a single configuration key:

    * `:root_dir` — absolute path to the directory where blobs
      are stored. The directory is created automatically on
      write if it does not exist.

  Example (in `config/config.exs`):

      config :claptrap, Claptrap.Storage,
        backend: Claptrap.Storage.Backends.Local,
        root_dir: "priv/storage"

  ## Path safety

  Every operation resolves the storage key against the root
  directory using `Path.safe_relative/1`, which rejects path
  traversal attempts (for example, `"../etc/passwd"`). Keys that
  escape the root directory raise an `ArgumentError`. This
  prevents a malformed or malicious key from reading or writing
  files outside the storage root.

  Nested keys containing `/` separators (such as
  `"subdir/file.txt"`) are supported. Parent directories are
  created automatically during writes via `File.mkdir_p!/1`.

  ## Streaming

  Writes consume the incoming `Enumerable` of iodata chunks
  incrementally, writing each chunk to disk as it arrives. This
  avoids buffering the entire payload in memory.

  Reads return a lazy `Stream` that emits 64 KiB chunks
  (`@chunk_size`). The underlying file descriptor is opened when
  the stream is first consumed and closed automatically when the
  stream terminates or is halted, following the `Stream.resource/3`
  lifecycle.

  The read path verifies that the file can be opened before
  returning the stream. If the file does not exist, `{:error,
  :not_found}` is returned immediately rather than producing a
  stream that would fail on first consumption.

  ## Listing

  `list/2` returns the top-level entries in the root directory
  that match the given prefix. It does not recurse into
  subdirectories. Results are sorted alphabetically.
  """

  @behaviour Claptrap.Storage.Adapter

  @chunk_size 65_536

  defp safe_path!(root_dir, key) do
    case Path.safe_relative(key) do
      {:ok, safe_key} -> Path.join(root_dir, safe_key)
      :error -> raise ArgumentError, "key #{inspect(key)} escapes storage root"
    end
  end

  @impl true
  def write(key, data, %{root_dir: root_dir}) do
    path = safe_path!(root_dir, key)
    File.mkdir_p!(Path.dirname(path))
    file = File.open!(path, [:write, :binary])

    try do
      Enum.each(data, &IO.binwrite(file, &1))
      :ok
    after
      File.close(file)
    end
  end

  @impl true
  def read(key, %{root_dir: root_dir}) do
    path = safe_path!(root_dir, key)

    case File.open(path, [:read, :binary]) do
      {:ok, file} ->
        File.close(file)
        {:ok, file_stream(path)}

      {:error, :enoent} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp file_stream(path) do
    Stream.resource(
      fn -> File.open!(path, [:read, :binary]) end,
      fn file ->
        case IO.binread(file, @chunk_size) do
          :eof -> {:halt, file}
          {:error, reason} -> raise IO.StreamError, reason: reason
          data -> {[data], file}
        end
      end,
      fn file -> File.close(file) end
    )
  end

  @impl true
  def delete(key, %{root_dir: root_dir}) do
    path = safe_path!(root_dir, key)

    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def list(prefix, %{root_dir: root_dir}) do
    case File.ls(root_dir) do
      {:ok, entries} ->
        keys =
          entries
          |> Enum.filter(&String.starts_with?(&1, prefix))
          |> Enum.sort()

        {:ok, keys}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def exists?(key, %{root_dir: root_dir}) do
    {:ok, File.exists?(safe_path!(root_dir, key))}
  end
end
