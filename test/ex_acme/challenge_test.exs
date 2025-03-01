defmodule ExAcme.ChallengeTest do
  use ExAcme.TestCase, async: true
  use AssertEventually, timeout: :timer.seconds(10), interval: :timer.seconds(1)

  setup %{client: client} do
    key = ExAcme.generate_key()
    {account_key, _} = ExAcme.TestHelpers.create_account(key, client)
    {:ok, order} = ExAcme.TestHelpers.create_order(account_key, client)

    {:ok, authorization} =
      order.authorizations
      |> List.first()
      |> ExAcme.fetch_authorization(account_key, client)

    %{client: client, account_key: account_key, order: order, authorization: authorization}
  end

  test "find_by_type", %{authorization: authorization} do
    challenge = ExAcme.Challenge.find_by_type(authorization, "dns-01")
    assert challenge.type == "dns-01"
    assert challenge.status == "pending"
  end

  test "find_by_type with bad type", %{authorization: authorization} do
    challenge = ExAcme.Challenge.find_by_type(authorization, "missing-01")
    assert challenge == nil
  end

  test "validate DNS challenge", %{client: client, account_key: account_key, order: order, authorization: authorization} do
    challenge = ExAcme.Challenge.find_by_type(authorization, "dns-01")
    ExAcme.TestHelpers.validate_order(order, account_key, client)

    assert_eventually {:ok, %{status: "valid"}} =
                        ExAcme.fetch_challenge(challenge.url, account_key, client)
  end
end
