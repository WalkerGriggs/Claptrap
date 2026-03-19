defmodule Claptrap.RSS do
  @moduledoc false

  alias Claptrap.RSS.{Feed, Generator, Parser, Validator}
  alias Claptrap.RSS.{GenerateError, ParseError, ValidationError}

  @spec parse(binary(), keyword()) :: {:ok, Feed.t()} | {:error, ParseError.t()}
  def parse(xml, opts \\ []) do
    Parser.parse(xml, opts)
  end

  @spec parse!(binary(), keyword()) :: Feed.t()
  def parse!(xml, opts \\ []) do
    xml |> parse(opts) |> unwrap!()
  end

  @spec generate(Feed.t(), keyword()) :: {:ok, binary()} | {:error, GenerateError.t()}
  def generate(feed, opts \\ []) do
    Generator.generate(feed, opts)
  end

  @spec generate!(Feed.t(), keyword()) :: binary()
  def generate!(feed, opts \\ []) do
    feed |> generate(opts) |> unwrap!()
  end

  @spec validate(Feed.t()) :: :ok | {:error, [ValidationError.t()]}
  def validate(feed) do
    Validator.validate(feed)
  end

  @spec unwrap!({:ok, value} | {:error, Exception.t()}) :: value when value: var
  defp unwrap!({:ok, value}), do: value
  defp unwrap!({:error, error}), do: raise(error)
end
