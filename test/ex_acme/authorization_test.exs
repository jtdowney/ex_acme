defmodule ExAcme.AuthorizationTest do
  use ExAcme.TestCase, async: true

  setup %{client: client} do
    key = ExAcme.generate_key()

    {account_key, _} = ExAcme.TestHelpers.create_account(key, client)
    {:ok, order} = ExAcme.TestHelpers.create_order(account_key, client)

    %{account_key: account_key, client: client, order: order}
  end

  test "fetching authorization", %{account_key: account_key, client: client, order: order} do
    authorization_url = List.first(order.authorizations)
    identifier = List.first(order.identifiers)

    {:ok, authorization} = ExAcme.fetch_authorization(authorization_url, account_key, client)

    assert authorization.url == authorization_url
    assert authorization.status == "pending"
    assert authorization.identifier == identifier
    assert authorization.challenges != []
  end
end
