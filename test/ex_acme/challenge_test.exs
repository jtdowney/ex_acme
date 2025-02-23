defmodule ExAcme.ChallengeTest do
  use ExAcme.TestCase, async: true
  use AssertEventually, timeout: :timer.seconds(10), interval: :timer.seconds(1)

  setup %{client: client} do
    account_key = ExAcme.AccountKey.generate()
    {account_key, _} = ExAcme.TestHelpers.create_account(account_key, client)
    {:ok, order} = ExAcme.TestHelpers.create_order(account_key, client)

    {:ok, authorization} =
      order.authorizations
      |> List.first()
      |> ExAcme.Authorization.fetch(account_key, client)

    %{client: client, key: account_key, order: order, authorization: authorization}
  end

  test "validate DNS challenge", %{client: client, key: account_key, order: order, authorization: authorization} do
    challenge = ExAcme.Challenge.find_by_type(authorization, "dns-01")
    ExAcme.TestHelpers.validate_order(order, account_key, client)

    assert_eventually {:ok, %{status: "valid"}} =
                        ExAcme.Challenge.fetch(challenge.url, account_key, client)
  end
end
