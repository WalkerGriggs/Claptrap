defmodule Claptrap.RSS.ErrorTest do
  use ExUnit.Case, async: true

  alias Claptrap.RSS.GenerateError
  alias Claptrap.RSS.ParseError
  alias Claptrap.RSS.ValidationError

  describe "ParseError" do
    test "can be raised and rescued" do
      assert_raise ParseError, fn ->
        raise ParseError, reason: :invalid_xml, message: "invalid XML"
      end
    end

    test "message/1 returns message when no location" do
      error = %ParseError{reason: :invalid_xml, message: "invalid XML"}
      assert Exception.message(error) == "invalid XML"
    end

    test "message/1 includes line when present" do
      error = %ParseError{reason: :invalid_xml, line: 42, message: "invalid XML"}
      assert Exception.message(error) == "invalid XML (line 42)"
    end

    test "message/1 includes line and column when both present" do
      error = %ParseError{reason: :invalid_xml, line: 42, column: 7, message: "invalid XML"}
      assert Exception.message(error) == "invalid XML (line 42, column 7)"
    end
  end

  describe "GenerateError" do
    test "can be raised and rescued" do
      assert_raise GenerateError, fn ->
        raise GenerateError, reason: :validation_failed, message: "validation failed"
      end
    end

    test "message/1 returns message when no path" do
      error = %GenerateError{reason: :encoding_error, message: "encoding error"}
      assert Exception.message(error) == "encoding error"
    end

    test "message/1 includes path when present" do
      error = %GenerateError{
        reason: :validation_failed,
        path: [:items, 0, :enclosure, :url],
        message: "validation failed"
      }

      assert Exception.message(error) == "validation failed (at [:items, 0, :enclosure, :url])"
    end
  end

  describe "ValidationError" do
    test "struct can be created with all required fields" do
      error = %ValidationError{
        message: "field is required",
        path: [:items, 3, :enclosure, :length],
        rule: :required
      }

      assert error.message == "field is required"
      assert error.path == [:items, 3, :enclosure, :length]
      assert error.rule == :required
    end

    test "raises when missing required fields" do
      assert_raise ArgumentError, fn ->
        struct!(ValidationError, %{})
      end

      assert_raise ArgumentError, fn ->
        struct!(ValidationError, %{message: "oops"})
      end

      assert_raise ArgumentError, fn ->
        struct!(ValidationError, %{message: "oops", path: []})
      end
    end
  end
end
