defmodule Claptrap.Storage.Backends.Local do
  @moduledoc false

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
        {:ok, file_stream(file)}

      {:error, :enoent} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp file_stream(file) do
    Stream.resource(
      fn -> file end,
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
