defmodule Claptrap.Producer.Adapters.RssUri do
  @moduledoc """
  URI helpers for RSS producer adapter serialization rules.
  """

  @scheme_regex ~r/^[A-Za-z][A-Za-z0-9+.-]*$/

  @spec valid_with_scheme?(String.t()) :: boolean()
  def valid_with_scheme?(value) when is_binary(value) do
    case URI.new(value) do
      {:ok, %URI{scheme: scheme}} when is_binary(scheme) ->
        Regex.match?(@scheme_regex, scheme)

      _ ->
        false
    end
  end

  def valid_with_scheme?(_), do: false
end
