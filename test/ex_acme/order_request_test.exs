defmodule ExAcme.OrderRequestTest do
  use ExAcme.TestCase, async: true

  setup %{client: client} do
    account_key = ExAcme.AccountKey.generate()
    {account_key, _} = ExAcme.TestHelpers.create_account(account_key, client)

    %{client: client, key: account_key}
  end

  test "creating an order request", %{client: client, key: account_key} do
    {:ok, order} =
      ExAcme.OrderRequest.new()
      |> ExAcme.OrderRequest.add_dns_identifier("example.com")
      |> ExAcme.OrderRequest.submit(account_key, client)

    assert order.status == "pending"
    assert order.identifiers == [%{"type" => "dns", "value" => "example.com"}]
  end

  test "creating an order with multiple domains", %{client: client, key: account_key} do
    {:ok, order} =
      ExAcme.OrderRequest.new()
      |> ExAcme.OrderRequest.add_dns_identifier("example.com")
      |> ExAcme.OrderRequest.add_dns_identifier("example.org")
      |> ExAcme.OrderRequest.submit(account_key, client)

    assert order.status == "pending"

    assert Enum.sort_by(order.identifiers, & &1["value"]) == [
             %{"type" => "dns", "value" => "example.com"},
             %{"type" => "dns", "value" => "example.org"}
           ]
  end

  test "creating an order with a profile", %{client: client, key: account_key} do
    {:ok, order} =
      ExAcme.OrderRequest.new()
      |> ExAcme.OrderRequest.add_dns_identifier("example.com")
      |> ExAcme.OrderRequest.profile("shortlived")
      |> ExAcme.OrderRequest.submit(account_key, client)

    assert order.profile == "shortlived"
  end

  test "creating an order with a not before", %{client: client, key: account_key} do
    not_before = DateTime.add(DateTime.utc_now(), 1, :day)

    {:ok, order} =
      ExAcme.OrderRequest.new()
      |> ExAcme.OrderRequest.add_dns_identifier("example.com")
      |> ExAcme.OrderRequest.not_before(not_before)
      |> ExAcme.OrderRequest.submit(account_key, client)

    assert order.not_before == not_before
  end

  test "creating an order with a not after", %{client: client, key: account_key} do
    not_after = DateTime.add(DateTime.utc_now(), 90, :day)

    {:ok, order} =
      ExAcme.OrderRequest.new()
      |> ExAcme.OrderRequest.add_dns_identifier("example.com")
      |> ExAcme.OrderRequest.not_after(not_after)
      |> ExAcme.OrderRequest.submit(account_key, client)

    assert order.not_after == not_after
  end
end
