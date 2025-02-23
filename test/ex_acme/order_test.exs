defmodule ExAcme.OrderTest do
  @moduledoc false
  use ExAcme.TestCase, async: true
  use AssertEventually

  @private_key X509.PrivateKey.from_pem!(File.read!("test/fixtures/private_rsa_key"))

  setup %{client: client} do
    account_key = ExAcme.AccountKey.generate()

    {account_key, _} = ExAcme.TestHelpers.create_account(account_key, client)

    %{client: client, key: account_key}
  end

  test "fetch an existing order", %{client: client, key: account_key} do
    {:ok, %{url: url} = order} =
      ExAcme.OrderRequest.new()
      |> ExAcme.OrderRequest.add_dns_identifier("example.com")
      |> ExAcme.OrderRequest.submit(account_key, client)

    {:ok, found_order} = ExAcme.Order.fetch(url, account_key, client)

    assert order == found_order
  end

  test "fetch a non-existing order", %{client: client, key: account_key} do
    directory = ExAcme.directory(client)

    url =
      directory["newOrder"]
      |> URI.new!()
      |> URI.merge("/my-order/missing")
      |> URI.to_string()

    assert {:error, {:http_error, 404}} = ExAcme.Order.fetch(url, account_key, client)
  end

  test "finalize an order", %{client: client, key: account_key} do
    {:ok, order} =
      ExAcme.OrderRequest.new()
      |> ExAcme.OrderRequest.add_dns_identifier(Faker.Internet.domain_name())
      |> ExAcme.OrderRequest.submit(account_key, client)

    ExAcme.TestHelpers.validate_order(order, account_key, client)
    csr = ExAcme.Certificate.csr_from_order(order, @private_key)

    {:ok, _} = ExAcme.Order.finalize(order.finalize_url, csr, account_key, client)

    assert_eventually {:ok, %{status: "valid"}} =
                        ExAcme.Order.fetch(order.url, account_key, client)
  end
end
