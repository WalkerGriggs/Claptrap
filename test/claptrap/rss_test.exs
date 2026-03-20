defmodule Claptrap.RSSTest do
  use ExUnit.Case, async: true

  alias Claptrap.RSS
  alias Claptrap.RSS.{Feed, GenerateError, ParseError}

  @feed %Feed{title: "Test", link: "https://example.com", description: "A test feed"}

  describe "parse!/2" do
    test "raises ParseError when given invalid input" do
      assert_raise ParseError, fn ->
        RSS.parse!("<not-rss/>")
      end
    end
  end

  describe "generate!/2" do
    test "raises GenerateError for invalid feeds" do
      assert_raise GenerateError, fn ->
        RSS.generate!(@feed)
      end
    end
  end

  describe "parse/2" do
    test "returns {:error, %ParseError{}} for invalid input" do
      assert {:error, %ParseError{}} = RSS.parse("<not-rss/>")
    end
  end

  describe "generate/2" do
    test "returns {:error, %GenerateError{}} for stubbed input" do
      assert {:error, %GenerateError{}} = RSS.generate(@feed)
    end
  end

  describe "validate/1" do
    test "returns :ok for a valid feed" do
      assert :ok = RSS.validate(@feed)
    end

    test "returns {:error, errors} for an invalid feed" do
      bad_feed = %{@feed | title: ""}
      assert {:error, errors} = RSS.validate(bad_feed)
      assert is_list(errors)
    end
  end
end
