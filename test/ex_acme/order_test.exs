defmodule ExAcme.OrderTest do
  @moduledoc false
  use ExAcme.TestCase, async: true
  use AssertEventually

  @private_key X509.PrivateKey.from_pem!(File.read!("test/fixtures/private_rsa_key"))

  setup %{client: client} do
    key = ExAcme.generate_key()
    {account_key, _} = ExAcme.TestHelpers.create_account(key, client)

    %{client: client, account_key: account_key}
  end

  test "fetch an existing order", %{client: client, account_key: account_key} do
    {:ok, %{url: url} = order} = ExAcme.TestHelpers.create_order(account_key, client)

    {:ok, found_order} = ExAcme.fetch_order(url, account_key, client)

    assert order == found_order
  end

  test "fetch a non-existing order", %{client: client, account_key: account_key} do
    url =
      client
      |> ExAcme.directory()
      |> Map.fetch!("newOrder")
      |> URI.new!()
      |> URI.merge("/my-order/missing")
      |> URI.to_string()

    assert {:error, {:http_error, 404}} = ExAcme.fetch_order(url, account_key, client)
  end

  test "finalize an order", %{client: client, account_key: account_key} do
    {:ok, order} = ExAcme.TestHelpers.create_order(account_key, client)
    ExAcme.TestHelpers.validate_order(order, account_key, client)
    {:ok, csr} = ExAcme.Order.to_csr(order, @private_key)

    {:ok, finalized_order} = ExAcme.finalize_order(order.finalize_url, csr, account_key, client)

    assert finalized_order.url == order.url

    assert_eventually {:ok, %{status: "valid"}} =
                        ExAcme.fetch_order(order.url, account_key, client)
  end

  test "creating an order request", %{client: client, account_key: account_key} do
    {:ok, order} =
      ExAcme.OrderBuilder.new_order()
      |> ExAcme.OrderBuilder.add_dns_identifier("example.com")
      |> ExAcme.submit_order(account_key, client)

    assert order.status == "pending"
    assert order.identifiers == [%{"type" => "dns", "value" => "example.com"}]
  end

  test "creating an order request without the builder", %{client: client, account_key: account_key} do
    {:ok, order} =
      ExAcme.submit_order(
        %{
          identifiers: [%{"type" => "dns", "value" => "example.com"}]
        },
        account_key,
        client
      )

    assert order.status == "pending"
    assert order.identifiers == [%{"type" => "dns", "value" => "example.com"}]
  end

  test "creating an order with multiple domains", %{client: client, account_key: account_key} do
    {:ok, order} =
      ExAcme.OrderBuilder.new_order()
      |> ExAcme.OrderBuilder.add_dns_identifier(["example.com", "example.org"])
      |> ExAcme.submit_order(account_key, client)

    assert order.status == "pending"

    assert Enum.sort_by(order.identifiers, & &1["value"]) == [
             %{"type" => "dns", "value" => "example.com"},
             %{"type" => "dns", "value" => "example.org"}
           ]
  end

  test "creating an order with a profile", %{client: client, account_key: account_key} do
    {:ok, order} =
      ExAcme.OrderBuilder.new_order()
      |> ExAcme.OrderBuilder.add_dns_identifier("example.com")
      |> ExAcme.OrderBuilder.profile("shortlived")
      |> ExAcme.submit_order(account_key, client)

    assert order.profile == "shortlived"
  end

  test "creating an order with a not before", %{client: client, account_key: account_key} do
    not_before = DateTime.add(DateTime.utc_now(), 1, :day)

    {:ok, order} =
      ExAcme.OrderBuilder.new_order()
      |> ExAcme.OrderBuilder.add_dns_identifier("example.com")
      |> ExAcme.OrderBuilder.not_before(not_before)
      |> ExAcme.submit_order(account_key, client)

    assert order.not_before == not_before
  end

  test "creating an order with a not after", %{client: client, account_key: account_key} do
    not_after = DateTime.add(DateTime.utc_now(), 90, :day)

    {:ok, order} =
      ExAcme.OrderBuilder.new_order()
      |> ExAcme.OrderBuilder.add_dns_identifier("example.com")
      |> ExAcme.OrderBuilder.not_after(not_after)
      |> ExAcme.submit_order(account_key, client)

    assert order.not_after == not_after
  end

  test "creating an order for a wildcard", %{client: client, account_key: account_key} do
    {:ok, order} =
      ExAcme.OrderBuilder.new_order()
      |> ExAcme.OrderBuilder.add_dns_identifier("*.example.com")
      |> ExAcme.submit_order(account_key, client)

    assert order.status == "pending"
    assert order.identifiers == [%{"type" => "dns", "value" => "*.example.com"}]

    auth_url = List.first(order.authorizations)
    {:ok, auth} = ExAcme.fetch_authorization(auth_url, account_key, client)

    assert auth.wildcard == true
  end

  test "to_csr with empty identifiers returns error" do
    order = %ExAcme.Order{identifiers: []}
    private_key = X509.PrivateKey.new_ec(:secp256r1)

    assert {:error, :empty_identifiers} = ExAcme.Order.to_csr(order, private_key)
  end
end
