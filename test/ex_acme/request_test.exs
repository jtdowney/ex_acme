defmodule ExAcme.RequestTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias ExAcme.Request

  describe "parse_retry_after/1" do
    test "parses valid integer seconds" do
      assert Request.parse_retry_after("120") == {:ok, 120}
      assert Request.parse_retry_after("0") == {:ok, 0}
      assert Request.parse_retry_after("999") == {:ok, 999}
    end

    test "returns error for negative seconds" do
      assert Request.parse_retry_after("-30") == :error
    end

    test "returns error for invalid integer format" do
      assert Request.parse_retry_after("60.5") == :error
      assert Request.parse_retry_after("abc") == :error
      assert Request.parse_retry_after("") == :error
      assert Request.parse_retry_after("60x") == :error
    end

    test "parses ISO8601 datetime format" do
      future_time = DateTime.utc_now() |> DateTime.add(300, :second) |> DateTime.to_iso8601()
      
      assert {:ok, seconds} = Request.parse_retry_after(future_time)
      assert seconds >= 299 and seconds <= 301
    end

    test "returns error for past datetime" do
      past_time = DateTime.utc_now() |> DateTime.add(-300, :second) |> DateTime.to_iso8601()
      
      assert Request.parse_retry_after(past_time) == :error
    end

    test "returns error for invalid datetime format" do
      assert Request.parse_retry_after("not-a-date") == :error
      assert Request.parse_retry_after("2025-13-01T12:00:00Z") == :error
    end
  end
end