defmodule Claptrap.Storage.Backends.Local do
  @moduledoc """
  Local filesystem storage backend for `Claptrap.Storage`.

  This backend stores each key beneath a configured `root_dir` on the host
  filesystem. It is the backend currently configured for the application in
  this repository, which means the public `Claptrap.Storage` API ultimately
  delegates here after performing its own validation.

  ## Configuration

  The backend expects a configuration map with:

  * `:root_dir` - the filesystem directory that acts as the storage root

  Every operation resolves the requested key relative to that root and uses
  `Path.safe_relative/1` to reject keys that would escape it.

  ## Implemented behavior

  This backend provides byte-oriented file storage with lazy reads:

  * `write/3` creates parent directories as needed and writes each chunk from
    the provided enumerable in order
  * `read/2` returns a lazy stream that reopens the file and yields binary
    chunks of up to 65,536 bytes
  * `delete/2` removes a single filesystem entry
  * `exists?/2` checks whether the resolved path exists
  * `list/2` lists and sorts entries directly under `root_dir`, then filters
    them by string prefix

  ## Important limitations of the current implementation

  The backend is more permissive than the public `Claptrap.Storage` facade.
  When called directly, it accepts nested keys like `subdir/file.txt` and
  will create the needed directories on write.

  Listing is intentionally much narrower than writing:

  * `list/2` is not recursive
  * it only inspects the immediate children of `root_dir`
  * returned values are the names reported by `File.ls/1`, so nested files are
    not surfaced as full storage keys

  In practice, that means direct backend callers can write nested paths, but
  `list/2` will only ever return top-level entries such as filenames or
  directory names.

  ## Error handling

  The backend normalizes some filesystem failures and passes others through:

  * missing files on `read/2` and `delete/2` are returned as
    `{:error, :not_found}`
  * other `File` errors are returned as `{:error, reason}`
  * path escape attempts raise `ArgumentError`
  * `write/3` uses bang functions for directory creation and file opening, so
    setup failures raise rather than returning tagged tuples
  * stream consumption errors during `read/2` raise `IO.StreamError`
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
