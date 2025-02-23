defmodule ExAcme.KeyTest do
  use ExUnit.Case, async: true

  test "generating an ed25519 key" do
    account_key = ExAcme.AccountKey.generate(:ed25519)
    assert account_key.type == :ed25519
  end
end
