defmodule ExAcme.CertificateTest do
  use ExAcme.TestCase, async: true
  use AssertEventually, timeout: :timer.seconds(10), interval: :timer.seconds(1)

  @private_key X509.PrivateKey.from_pem!(File.read!("test/fixtures/private_rsa_key"))

  setup %{client: client} do
    account_key = ExAcme.AccountKey.generate()
    {account_key, _} = ExAcme.TestHelpers.create_account(account_key, client)
    {:ok, order} = ExAcme.TestHelpers.create_order(account_key, client)

    %{key: account_key, client: client, order: order}
  end

  test "creating a CSR from an order", %{order: order} do
    %{"type" => "dns", "value" => domain_name} = List.first(order.identifiers)
    csr = ExAcme.Certificate.csr_from_order(order, @private_key)
    {:Extension, _, _, [dNSName: name]} = csr |> X509.CSR.extension_request() |> List.first()

    assert name == String.to_charlist(domain_name)
  end

  test "fetching a certificate", %{order: order, client: client, key: account_key} do
    ExAcme.TestHelpers.validate_order(order, account_key, client)
    csr = ExAcme.Certificate.csr_from_order(order, @private_key)

    ExAcme.Order.finalize(order.finalize_url, csr, account_key, client)

    assert_eventually {:ok, %{status: "valid", certificate_url: certificate_url}} =
                        ExAcme.Order.fetch(order.url, account_key, client)

    assert {:ok, certificates} = ExAcme.Certificate.fetch(certificate_url, account_key, client)
    assert certificates != []
  end
end
