defmodule ExAcme.UtilsTest do
  use ExUnit.Case, async: true

  test "datetime_from_rfc3339/1" do
    {:ok, date, _} = DateTime.from_iso8601("2025-01-01T00:00:00Z")
    assert ExAcme.Utils.datetime_from_rfc3339("2025-01-01T00:00:00Z") == date
  end

  test "datetime_from_rfc3339/1 with invalid input" do
    assert_raise(ArgumentError, "Invalid RFC3339 string: invalid_format", fn ->
      ExAcme.Utils.datetime_from_rfc3339("invalid")
    end)
  end
end
