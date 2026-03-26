defmodule Claptrap.Storage.Backends.Local do
  @moduledoc """
  Local filesystem implementation of `Claptrap.Storage.Adapter`.

  This backend stores each object as a regular file inside a designated
  root directory on the local filesystem. A key maps directly to a
  relative file path under that root. Keys containing subdirectory
  separators (e.g. `"subdir/file.bin"`) are supported; intermediate
  directories are created automatically on write.

  ## Configuration

  The backend reads a single key from the config map passed by
  `Claptrap.Storage`:

  - `:root_dir` — absolute path to the directory that acts as the
    storage root. The directory must exist at the time of the first
    write or list operation.

  Example application config:

      config :claptrap, Claptrap.Storage,
        backend: Claptrap.Storage.Backends.Local,
        root_dir: "/var/claptrap/storage"

  ## Path safety

  Every operation resolves the caller-supplied key to an absolute path
  using `Path.safe_relative/1` before touching the filesystem. If the
  key contains `..` components or is otherwise not a safe relative path,
  the function raises `ArgumentError` with a descriptive message. This
  prevents directory-traversal attacks even if a key that passed the
  facade's regex validation somehow contained a relative-escape sequence.

  The layout inside `:root_dir` looks like this:

      <root_dir>/
        artifact.txt
        report.json
        subdir/
          nested/
            file.bin

  ## Streaming reads

  `read/2` verifies that the file is accessible with a probe `File.open`
  call before constructing the stream, so that `:not_found` and other
  errors are surfaced eagerly at call time rather than lazily at first
  enumeration. The returned `Stream.resource/3` stream then re-opens the
  file for actual reading, yielding #{div(65_536, 1024)} KiB binary
  chunks until EOF, and closes the file handle when enumeration
  completes or is halted. This keeps memory usage proportional to a
  single chunk rather than to the size of the object.

  ## Error normalization

  `:enoent` from `File.rm/1` and `File.open/2` is translated to
  `:not_found` so that callers can rely on the uniform contract defined
  by `Claptrap.Storage.Adapter`. All other POSIX error atoms are
  forwarded as-is.
  """

  @behaviour Claptrap.Storage.Adapter

  @chunk_size 65_536

  defp safe_path!(root_dir, key) do
    case Path.safe_relative(key) do
      {:ok, safe_key} -> Path.join(root_dir, safe_key)
      :error -> raise ArgumentError, "key #{inspect(key)} escapes storage root"
    end
  end

  @doc """
  Writes `data` to a file at `<root_dir>/<key>`, creating intermediate
  directories as needed.

  `data` is consumed exactly once. Each element is written to the file
  in order using `IO.binwrite/2`. The file handle is always closed,
  even if an exception is raised during enumeration.

  Raises `ArgumentError` if the key would escape the storage root.
  Raises `File.Error` if the root directory does not exist or if the
  filesystem rejects the write.
  """
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

  @doc """
  Opens the file at `<root_dir>/<key>` and returns a lazy read stream.

  File accessibility is checked eagerly with a probe open so that
  `:not_found` (or another error) is returned at call time, before the
  caller attempts to enumerate the stream. The actual data is read in
  #{div(@chunk_size, 1024)} KiB chunks via `IO.binread/2`.

  Returns `{:ok, stream}` on success, `{:error, :not_found}` when the
  file does not exist, or `{:error, reason}` for other filesystem
  errors.

  Raises `ArgumentError` if the key would escape the storage root.
  """
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

  @doc """
  Removes the file at `<root_dir>/<key>`.

  Returns `:ok` on success, `{:error, :not_found}` when the file does
  not exist, or `{:error, reason}` for other filesystem errors (for
  example, `:eperm` or `:eisdir` if the key resolves to a directory).

  Raises `ArgumentError` if the key would escape the storage root.
  """
  @impl true
  def delete(key, %{root_dir: root_dir}) do
    path = safe_path!(root_dir, key)

    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns a sorted list of filenames in `:root_dir` that start with
  `prefix`.

  Only the immediate entries of the root directory are considered; the
  implementation uses `File.ls/1` and does not recurse into
  subdirectories. When `prefix` is `""` all entries are returned.

  Returns `{:ok, [key]}` on success or `{:error, reason}` if the root
  directory cannot be listed (for example, `{:error, :enoent}` when the
  directory does not exist).
  """
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

  @doc """
  Returns `{:ok, true}` when a file exists at `<root_dir>/<key>` and
  `{:ok, false}` otherwise.

  This call does not distinguish between a missing file and a missing
  directory component — both yield `{:ok, false}`. It delegates to
  `File.exists?/1`, which follows symbolic links.

  Raises `ArgumentError` if the key would escape the storage root.
  """
  @impl true
  def exists?(key, %{root_dir: root_dir}) do
    {:ok, File.exists?(safe_path!(root_dir, key))}
  end
end
