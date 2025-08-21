defmodule ExAcmeTest do
  @moduledoc false
  use ExAcme.TestCase, async: true

  test "directory", %{client: client} do
    directory = ExAcme.directory(client)

    assert directory["newNonce"] == "https://pebble:14000/nonce-plz"
  end

  test "terms_of_service", %{client: client} do
    terms_of_service = ExAcme.terms_of_service(client)

    assert terms_of_service == "data:text/plain,Do%20what%20thou%20wilt"
  end

  test "profiles", %{client: client} do
    profiles = ExAcme.profiles(client)

    assert profiles == %{
             "default" => "The profile you know and love",
             "shortlived" => "A short-lived cert profile, without actual enforcement"
           }
  end

  test "external_account_required?", %{client: client} do
    external_account_required = ExAcme.external_account_required?(client)

    assert external_account_required == false
  end

  test "named directory lets_encrypt" do
    {:ok, pid} = ExAcme.start_link(directory_url: :lets_encrypt)
    %{directory_url: directory_url} = Agent.get(pid, & &1)
    assert directory_url == "https://acme-v02.api.letsencrypt.org/directory"
  end

  test "current_nonce basic functionality", %{client: client} do
    {:ok, nonce1} = ExAcme.current_nonce(client)
    assert is_binary(nonce1)
    assert String.length(nonce1) > 0

    {:ok, nonce2} = ExAcme.current_nonce(client)
    assert is_binary(nonce2)
    assert String.length(nonce2) > 0

    assert nonce1 != nonce2
  end

  test "nonce storage and retrieval", %{client: client} do
    Agent.update(client, &Map.put(&1, :nonce, "test-nonce-from-server"))

    {:ok, nonce} = ExAcme.current_nonce(client)
    assert nonce == "test-nonce-from-server"

    {:ok, new_nonce} = ExAcme.current_nonce(client)
    assert is_binary(new_nonce)
    assert new_nonce != "test-nonce-from-server"
  end

  test "multiple concurrent nonce requests", %{client: client} do
    tasks =
      for _i <- 1..5 do
        Task.async(fn ->
          case ExAcme.current_nonce(client) do
            {:ok, nonce} when is_binary(nonce) -> :ok
            error -> error
          end
        end)
      end

    results = Task.await_many(tasks, 5000)

    assert Enum.all?(results, &(&1 == :ok))
  end

  describe "generate_key/1" do
    test "generates ES256 key by default" do
      key = ExAcme.generate_key()

      assert %JOSE.JWK{} = key

      # Check that the key has the correct algorithm
      {_jwk, public_map} = JOSE.JWK.to_public_map(key)
      assert public_map["alg"] == "ES256"
      assert public_map["kty"] == "EC"
      assert public_map["crv"] == "P-256"

      # Check that x and y coordinates are present and properly formatted
      assert is_binary(public_map["x"])
      assert is_binary(public_map["y"])
      assert String.length(public_map["x"]) > 0
      assert String.length(public_map["y"]) > 0
    end

    test "generates ES256 key when explicitly requested" do
      key = ExAcme.generate_key("ES256")

      assert %JOSE.JWK{} = key

      {_jwk, public_map} = JOSE.JWK.to_public_map(key)
      assert public_map["alg"] == "ES256"
      assert public_map["kty"] == "EC"
      assert public_map["crv"] == "P-256"
    end

    test "generates different keys on each call" do
      key1 = ExAcme.generate_key()
      key2 = ExAcme.generate_key()

      {_jwk1, public_map1} = JOSE.JWK.to_public_map(key1)
      {_jwk2, public_map2} = JOSE.JWK.to_public_map(key2)

      # Keys should be different
      assert public_map1["x"] != public_map2["x"]
      assert public_map1["y"] != public_map2["y"]
    end

    test "generated key can be used for signing" do
      key = ExAcme.generate_key()
      payload = "test payload"
      header = %{"alg" => "ES256", "typ" => "JWT"}

      # Should be able to sign without error
      {_jws, signed_payload} = JOSE.JWK.sign(payload, header, key)
      assert is_map(signed_payload)

      # Should be able to peek at the payload
      assert JOSE.JWS.peek_payload(signed_payload) == payload
    end

    test "generated key can produce thumbprint" do
      key = ExAcme.generate_key()

      thumbprint = JOSE.JWK.thumbprint(key)
      assert is_binary(thumbprint)
      assert String.length(thumbprint) > 0

      # Thumbprint should be consistent for the same key
      assert JOSE.JWK.thumbprint(key) == thumbprint
    end

    test "fallback to JOSE for non-ES256 algorithms" do
      # This should still work for other algorithms
      key = ExAcme.generate_key("RS256")

      assert %JOSE.JWK{} = key

      {_jwk, public_map} = JOSE.JWK.to_public_map(key)
      assert public_map["alg"] == "RS256"
      assert public_map["kty"] == "RSA"
    end

    test "generated key works with AccountKey.new/2" do
      key = ExAcme.generate_key()
      account_key = ExAcme.AccountKey.new(key, "test-kid")

      assert %ExAcme.AccountKey{} = account_key
      assert account_key.algorithm == "ES256"
      assert account_key.kid == "test-kid"
      assert account_key.key == key
    end
  end
end
