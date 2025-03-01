defmodule ExAcme.AccountKeyTest do
  use ExUnit.Case, async: true

  test "signing a message with KID" do
    key = ExAcme.generate_key()
    account_key = ExAcme.AccountKey.new(key, "test-kid")
    message = ExAcme.AccountKey.sign(account_key, "test", %{})

    assert JOSE.JWS.peek_payload(message) == "test"

    assert %{"alg" => "ES256", "kid" => "test-kid"} =
             message |> JOSE.JWS.peek_protected() |> Jason.decode!()
  end
end
