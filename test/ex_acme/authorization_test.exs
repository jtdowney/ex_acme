defmodule ExAcme.AuthorizationTest do
  use ExAcme.TestCase, async: true

  setup %{client: client} do
    account_key = ExAcme.AccountKey.generate()

    {account_key, _} = ExAcme.TestHelpers.create_account(account_key, client)
    {:ok, order} = ExAcme.TestHelpers.create_order(account_key, client)

    %{key: account_key, client: client, order: order}
  end

  test "fetching authorization", %{key: account_key, client: client, order: order} do
    authorization_url = List.first(order.authorizations)
    identifier = List.first(order.identifiers)

    {:ok, authorization} = ExAcme.Authorization.fetch(authorization_url, account_key, client)

    assert authorization.url == authorization_url
    assert authorization.status == "pending"
    assert authorization.identifier == identifier
    assert authorization.challenges != []
  end
end
