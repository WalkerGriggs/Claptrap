defmodule Claptrap.Pagination do
  @moduledoc false

  @default_page_size 25
  @max_page_size 100

  @doc """
  Extracts pagination options from query params.
  Returns keyword list with :after and :limit.
  """
  def params_to_opts(query_params) do
    [paginate: true]
    |> put_page_size(query_params["page_size"])
    |> put_page_token(query_params["page_token"])
  end

  @doc """
  Converts a Paginator.Page into an AIP-158 style
  response envelope.
  """
  def to_response(%Paginator.Page{} = page) do
    response = %{items: page.entries}

    case page.metadata.after do
      nil -> response
      cursor -> Map.put(response, :next_page_token, cursor)
    end
  end

  defp put_page_size(opts, nil),
    do: Keyword.put(opts, :limit, @default_page_size)

  defp put_page_size(opts, value) do
    case Integer.parse(value) do
      {size, ""} when size > 0 ->
        Keyword.put(opts, :limit, min(size, @max_page_size))

      _ ->
        Keyword.put(opts, :limit, @default_page_size)
    end
  end

  defp put_page_token(opts, nil), do: opts
  defp put_page_token(opts, ""), do: opts

  defp put_page_token(opts, token),
    do: Keyword.put(opts, :after, token)
end
