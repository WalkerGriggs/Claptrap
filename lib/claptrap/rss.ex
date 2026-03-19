defmodule Claptrap.RSS do
  @moduledoc false

  # Dialyzer warnings suppressed because Parser, Generator, and Validator are
  # stubs that only return errors. Remove when real implementations land.
  @dialyzer [
    {:nowarn_function, parse: 1},
    {:nowarn_function, parse: 2},
    {:nowarn_function, parse!: 1},
    {:nowarn_function, parse!: 2},
    {:nowarn_function, generate: 1},
    {:nowarn_function, generate: 2},
    {:nowarn_function, generate!: 1},
    {:nowarn_function, generate!: 2},
    {:nowarn_function, validate: 1}
  ]

  alias Claptrap.RSS.{Feed, Generator, Parser, Validator}
  alias Claptrap.RSS.{GenerateError, ParseError, ValidationError}

  @spec parse(binary(), keyword()) :: {:ok, Feed.t()} | {:error, ParseError.t()}
  def parse(xml, opts \\ []) do
    Parser.parse(xml, opts)
  end

  @spec parse!(binary(), keyword()) :: Feed.t()
  def parse!(xml, opts \\ []) do
    parse(xml, opts)
    |> then(fn
      {:ok, feed} -> feed
      {:error, error} -> raise error
    end)
  end

  @spec generate(Feed.t(), keyword()) :: {:ok, binary()} | {:error, GenerateError.t()}
  def generate(feed, opts \\ []) do
    Generator.generate(feed, opts)
  end

  @spec generate!(Feed.t(), keyword()) :: binary()
  def generate!(feed, opts \\ []) do
    generate(feed, opts)
    |> then(fn
      {:ok, xml} -> xml
      {:error, error} -> raise error
    end)
  end

  @spec validate(Feed.t()) :: :ok | {:error, [ValidationError.t()]}
  def validate(feed) do
    Validator.validate(feed)
  end
end
