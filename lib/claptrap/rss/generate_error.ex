defmodule Claptrap.RSS.GenerateError do
  @moduledoc false

  @type t :: %__MODULE__{
          reason: atom(),
          path: [atom() | non_neg_integer()],
          message: String.t()
        }

  defexception [:reason, :path, :message]

  @impl true
  def message(%__MODULE__{message: message, path: nil}), do: message
  def message(%__MODULE__{message: message, path: []}), do: message

  def message(%__MODULE__{message: message, path: path}),
    do: "#{message} (at #{inspect(path)})"
end
