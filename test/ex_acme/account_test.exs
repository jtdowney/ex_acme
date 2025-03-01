defmodule ExAcme.AccountTest do
  use ExAcme.TestCase, async: true

  test "fetch existing account", %{client: client} do
    account_key = ExAcme.generate_key()

    {account_key, account} = ExAcme.TestHelpers.create_account(account_key, client)
    {:ok, fetched_account} = ExAcme.fetch_account(account.url, account_key, client)

    assert fetched_account == account
  end

  test "deactivate account", %{client: client} do
    account_key = ExAcme.generate_key()

    {account_key, _} = ExAcme.TestHelpers.create_account(account_key, client)
    {:ok, account} = ExAcme.deactivate_account(account_key, client)

    assert account.status == "deactivated"
  end

  test "fetch non-existing account", %{client: client} do
    url =
      client
      |> ExAcme.directory()
      |> Map.fetch!("newAccount")
      |> URI.new!()
      |> URI.merge("/my-account/missing")
      |> URI.to_string()

    key = ExAcme.generate_key()
    account_key = ExAcme.AccountKey.new(key, url)
    {:error, body} = ExAcme.fetch_account(url, account_key, client)

    assert body["status"] == 400
    assert body["type"] == "urn:ietf:params:acme:error:accountDoesNotExist"
  end

  test "rotating account key", %{client: client} do
    old_key = ExAcme.generate_key()
    new_key = ExAcme.generate_key()

    {old_account_key, account} = ExAcme.TestHelpers.create_account(old_key, client)
    {:ok, old_fetched_account} = ExAcme.fetch_account(account.url, old_account_key, client)
    {:ok, new_account_key} = ExAcme.rotate_account_key(old_account_key, new_key, client)
    {:ok, new_fetched_account} = ExAcme.fetch_account(account.url, new_account_key, client)

    assert old_fetched_account == account
    assert new_fetched_account == account
  end

  test "rotating account key with an invalid old key", %{client: client} do
    old_key = ExAcme.generate_key()
    new_key = ExAcme.generate_key()

    {_, account} = ExAcme.TestHelpers.create_account(old_key, client)
    old_account_key = ExAcme.AccountKey.new(ExAcme.generate_key(), account.url)

    assert {:error, %{"type" => "urn:ietf:params:acme:error:malformed"}} =
             ExAcme.rotate_account_key(old_account_key, new_key, client)
  end
end
