defmodule ExAcme.AccountTest do
  use ExAcme.TestCase, async: true

  test "fetch existing account", %{client: client} do
    account_key = ExAcme.AccountKey.generate()

    {account_key, account} = ExAcme.TestHelpers.create_account(account_key, client)
    {:ok, fetched_account} = ExAcme.Account.fetch(account.url, account_key, client)

    assert fetched_account == account
  end

  test "fetch non-existing account", %{client: client} do
    directory = ExAcme.directory(client)

    url =
      directory["newAccount"]
      |> URI.new!()
      |> URI.merge("/my-account/missing")
      |> URI.to_string()

    account_key = ExAcme.AccountKey.update_kid(ExAcme.AccountKey.generate(), url)

    {:error, body} = ExAcme.Account.fetch(url, account_key, client)

    assert body["status"] == 400
    assert body["type"] == "urn:ietf:params:acme:error:accountDoesNotExist"
  end

  test "rotating account key", %{client: client} do
    old_account_key = ExAcme.AccountKey.generate()
    new_account_key = ExAcme.AccountKey.generate()

    {old_account_key, account} = ExAcme.TestHelpers.create_account(old_account_key, client)
    {:ok, old_fetched_account} = ExAcme.Account.fetch(account.url, old_account_key, client)
    {:ok, new_account_key} = ExAcme.Account.rotate_key(old_account_key, new_account_key, client)
    {:ok, new_fetched_account} = ExAcme.Account.fetch(account.url, new_account_key, client)

    assert old_fetched_account == account
    assert new_fetched_account == account
  end

  test "rotating account key with an invalid old key", %{client: client} do
    old_account_key = ExAcme.AccountKey.generate()
    new_account_key = ExAcme.AccountKey.generate()

    {_, account} = ExAcme.TestHelpers.create_account(old_account_key, client)
    old_account_key = ExAcme.AccountKey.update_kid(ExAcme.AccountKey.generate(), account.url)

    assert {:error, %{"type" => "urn:ietf:params:acme:error:malformed"}} =
             ExAcme.Account.rotate_key(old_account_key, new_account_key, client)
  end

  # This test is a bit brittle because it relies on pebble not supporting the ed25519 key type
  test "rotating account key with an invalid new key", %{client: client} do
    old_account_key = ExAcme.AccountKey.generate()
    new_account_key = ExAcme.AccountKey.generate(:ed25519)

    {_, account} = ExAcme.TestHelpers.create_account(old_account_key, client)
    old_account_key = ExAcme.AccountKey.update_kid(ExAcme.AccountKey.generate(), account.url)

    assert {:error, %{"type" => "urn:ietf:params:acme:error:malformed"}} =
             ExAcme.Account.rotate_key(old_account_key, new_account_key, client)
  end
end
