defmodule Claptrap.RSS.Validator do
  @moduledoc false

  alias Claptrap.RSS.ValidationError

  @spec validate(term()) :: {:error, [ValidationError.t()]}
  def validate(_feed) do
    {:error, [%ValidationError{message: "not implemented", path: [], rule: :not_implemented}]}
  end
end
