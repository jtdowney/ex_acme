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
      assert_in_delta seconds, 300, 5
    end

    test "returns zero for past datetime" do
      past_time = DateTime.utc_now() |> DateTime.add(-300, :second) |> DateTime.to_iso8601()

      assert Request.parse_retry_after(past_time) == {:ok, 0}
    end

    test "parses RFC 7231 HTTP-date format" do
      # Test RFC 1123 format (preferred)
      future_time = DateTime.add(DateTime.utc_now(), 240, :second)
      rfc1123_date = Calendar.strftime(future_time, "%a, %d %b %Y %H:%M:%S GMT")

      assert {:ok, seconds} = Request.parse_retry_after(rfc1123_date)
      assert_in_delta seconds, 240, 5

      # Test RFC 850 format
      rfc850_date = Calendar.strftime(future_time, "%A, %d-%b-%y %H:%M:%S GMT")

      assert {:ok, seconds} = Request.parse_retry_after(rfc850_date)
      assert_in_delta seconds, 240, 5
    end

    test "returns zero for past HTTP-date" do
      past_time = DateTime.add(DateTime.utc_now(), -240, :second)
      past_rfc1123 = Calendar.strftime(past_time, "%a, %d %b %Y %H:%M:%S GMT")

      assert Request.parse_retry_after(past_rfc1123) == {:ok, 0}
    end

    test "returns error for invalid datetime format" do
      assert Request.parse_retry_after("not-a-date") == :error
      assert Request.parse_retry_after("2025-13-01T12:00:00Z") == :error
      assert Request.parse_retry_after("Invalid, 99 Foo 9999 99:99:99 GMT") == :error
    end

    test "handles values with leading/trailing whitespace" do
      assert Request.parse_retry_after(" 120 ") == {:ok, 120}
      assert Request.parse_retry_after("\t60\n") == {:ok, 60}
      assert Request.parse_retry_after("  300  ") == {:ok, 300}

      # Test with datetime formats and whitespace
      future_time = DateTime.add(DateTime.utc_now(), 300, :second)
      iso8601_with_space = "  #{DateTime.to_iso8601(future_time)}  "

      assert {:ok, seconds} = Request.parse_retry_after(iso8601_with_space)
      assert_in_delta seconds, 300, 5

      # Test with HTTP-date format and whitespace
      rfc1123_date = Calendar.strftime(future_time, "%a, %d %b %Y %H:%M:%S GMT")
      rfc1123_with_space = "\t#{rfc1123_date}\n"

      assert {:ok, seconds} = Request.parse_retry_after(rfc1123_with_space)
      assert_in_delta seconds, 300, 5
    end
  end

  describe "link_urls/3" do
    @base_url "https://acme.example/acme/cert/abc"

    test "returns the targets of links with the given relation" do
      headers = %{
        "link" => [
          ~s(<https://acme.example/acme/cert/abc/1>;rel="alternate"),
          ~s(<https://acme.example/directory>;rel="index"),
          ~s(<https://acme.example/acme/cert/abc/2>; rel="alternate")
        ]
      }

      assert Request.link_urls(headers, @base_url, "alternate") == [
               "https://acme.example/acme/cert/abc/1",
               "https://acme.example/acme/cert/abc/2"
             ]
    end

    test "splits comma-separated links in a single header" do
      headers = %{
        "link" => [~s(<https://acme.example/directory>;rel="index", <https://acme.example/alt/1>;rel="alternate")]
      }

      assert Request.link_urls(headers, @base_url, "alternate") == ["https://acme.example/alt/1"]
    end

    test "matches unquoted, multi-valued and differently cased relations" do
      headers = %{
        "link" => [
          "<https://acme.example/alt/1>;rel=alternate",
          ~s(<https://acme.example/alt/2>;rel="up ALTERNATE"),
          ~s(<https://acme.example/alt/3>;title="x";REL="Alternate")
        ]
      }

      assert Request.link_urls(headers, @base_url, "alternate") == [
               "https://acme.example/alt/1",
               "https://acme.example/alt/2",
               "https://acme.example/alt/3"
             ]
    end

    test "resolves relative targets against the request URL" do
      headers = %{"link" => [~s(</acme/cert/abc/1>;rel="alternate")]}

      assert Request.link_urls(headers, @base_url, "alternate") == ["https://acme.example/acme/cert/abc/1"]
    end

    test "returns an empty list without matching links" do
      assert Request.link_urls(%{}, @base_url, "alternate") == []
      assert Request.link_urls(%{"link" => ["<https://acme.example/x>"]}, @base_url, "alternate") == []
      assert Request.link_urls(%{"link" => ["garbage"]}, @base_url, "alternate") == []
    end
  end
end
