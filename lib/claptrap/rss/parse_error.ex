defmodule Claptrap.RSS.ParseError do
  @moduledoc false

  @type t :: %__MODULE__{
          reason: atom(),
          line: non_neg_integer() | nil,
          column: non_neg_integer() | nil,
          message: String.t()
        }

  defexception [:reason, :line, :column, :message]

  @impl true
  def message(%__MODULE__{message: message, line: nil}), do: message

  def message(%__MODULE__{message: message, line: line, column: nil}),
    do: "#{message} (line #{line})"

  def message(%__MODULE__{message: message, line: line, column: column}),
    do: "#{message} (line #{line}, column #{column})"
end
