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
end
