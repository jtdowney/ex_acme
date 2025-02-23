defmodule ExAcme.AccountKeyTest do
  use ExUnit.Case, async: true

  test "generating a default key" do
    account_key = ExAcme.AccountKey.generate()

    assert account_key.type == :ec256
  end

  test "generating an ECDSA P-256 key" do
    account_key = ExAcme.AccountKey.generate(:ec256)

    assert account_key.type == :ec256
    assert {%{kty: :jose_jwk_kty_ec}, %{"crv" => "P-256", "kty" => "EC"}} = JOSE.JWK.to_map(account_key.key)
  end

  test "generating an Ed25519 key" do
    account_key = ExAcme.AccountKey.generate(:ed25519)

    assert account_key.type == :ed25519
    assert {%{kty: :jose_jwk_kty_okp_ed25519}, %{"crv" => "Ed25519", "kty" => "OKP"}} = JOSE.JWK.to_map(account_key.key)
  end

  test "signing a message with an Ed25519 key" do
    account_key = ExAcme.AccountKey.generate(:ed25519)
    message = ExAcme.AccountKey.sign(account_key, "test", %{})

    assert JOSE.JWS.peek_payload(message) == "test"

    assert %{"alg" => "EdDSA", "jwk" => %{"crv" => "Ed25519", "kty" => "OKP"}} =
             message |> JOSE.JWS.peek_protected() |> Jason.decode!()
  end

  test "signing a message with no KID" do
    account_key = ExAcme.AccountKey.generate()
    message = ExAcme.AccountKey.sign(account_key, "test", %{})

    assert JOSE.JWS.peek_payload(message) == "test"

    assert %{"alg" => "ES256", "jwk" => %{"crv" => "P-256", "kty" => "EC"}} =
             message |> JOSE.JWS.peek_protected() |> Jason.decode!()
  end

  test "signing a message with KID" do
    account_key = ExAcme.AccountKey.update_kid(ExAcme.AccountKey.generate(), "test-kid")
    message = ExAcme.AccountKey.sign(account_key, "test", %{})

    assert JOSE.JWS.peek_payload(message) == "test"

    assert %{"alg" => "ES256", "kid" => "test-kid"} =
             message |> JOSE.JWS.peek_protected() |> Jason.decode!()
  end

  test "to_json encode without KID" do
    account_key = ExAcme.AccountKey.generate()
    json = ExAcme.AccountKey.to_json(account_key)

    assert %{"kid" => nil, "type" => "ec256", "key" => %{"crv" => "P-256", "kty" => "EC"}} = Jason.decode!(json)
  end

  test "to_json encode with KID" do
    account_key = ExAcme.AccountKey.update_kid(ExAcme.AccountKey.generate(), "test-kid")
    json = ExAcme.AccountKey.to_json(account_key)

    assert %{"kid" => "test-kid", "type" => "ec256", "key" => %{"crv" => "P-256", "kty" => "EC"}} = Jason.decode!(json)
  end

  test "to and from JSON" do
    account_key = ExAcme.AccountKey.update_kid(ExAcme.AccountKey.generate(), "test-kid")
    json = ExAcme.AccountKey.to_json(account_key)
    {:ok, decoded_account_key} = ExAcme.AccountKey.from_json(json)

    assert decoded_account_key == account_key
  end
end
