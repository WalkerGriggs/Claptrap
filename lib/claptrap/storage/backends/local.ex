defmodule Claptrap.Storage.Backends.Local do
  @moduledoc """
  Filesystem-backed implementation of `Claptrap.Storage.Adapter`.

  Objects live under a single directory given by `root_dir` in the config map.
  Each storage key is joined under that root using `Path.safe_relative/1`. If
  the key is not a safe relative path (for example it contains `..` or
  separators that escape the root), the function raises `ArgumentError`. This
  is an extra guard in addition to the key format checks applied by
  `Claptrap.Storage`.

  ## Writing and reading

  `write/3` creates parent directories as needed, opens the destination file
  in binary mode, writes each chunk from the enumerable with `IO.binwrite/2`,
  and closes the file in an `after` block. An empty enumerable still creates
  an empty file.

  `read/2` returns `{:ok, stream}` where `stream` is a `Stream.resource/3`
  that reads the file in chunks of 65536 bytes. If the file is missing, the
  result is `{:error, :not_found}`. Other `File.open/2` failures are returned
  as `{:error, reason}`. Opening a path that is a directory yields an error
  such as `{:error, :eisdir}`.

  ## Listing

  `list/2` calls `File.ls/1` on `root_dir` only (not recursive). Returned
  names are filtered with `String.starts_with?/2` against the given prefix,
  sorted with `Enum.sort/1`, and returned as `{:ok, keys}`. Nested keys such
  as `"a/b/c"` create subdirectories on disk; listing still only enumerates
  the immediate entries in `root_dir`, so results reflect directory entries
  at that top level rather than every logical key path.

  ## Deletion and existence

  `delete/2` uses `File.rm/1`. A missing file becomes `{:error, :not_found}`.

  `exists?/2` returns `{:ok, true}` or `{:ok, false}` for the resolved path
  using `File.exists?/1` and does not treat a missing file as an error tuple.
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
