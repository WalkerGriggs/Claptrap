defmodule Claptrap.RSS.Validator do
  @moduledoc false

  alias Claptrap.RSS.{Feed, ValidationError}

  @spec validate(Feed.t()) :: :ok | {:error, [ValidationError.t()]}
  def validate(_feed) do
    Process.get(
      {__MODULE__, :impl},
      {:error, [%ValidationError{message: "not implemented", path: [], rule: :not_implemented}]}
    )
  end
end
