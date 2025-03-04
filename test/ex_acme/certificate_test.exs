defmodule ExAcme.CertificateTest do
  use ExAcme.TestCase, async: true
  use AssertEventually, timeout: to_timeout(second: 10), interval: to_timeout(second: 1)

  @private_key X509.PrivateKey.from_pem!(File.read!("test/fixtures/private_rsa_key"))

  setup %{client: client} do
    key = ExAcme.generate_key()
    {account_key, _} = ExAcme.TestHelpers.create_account(key, client)
    {:ok, order} = ExAcme.TestHelpers.create_order(account_key, client)

    %{account_key: account_key, client: client, order: order}
  end

  test "creating a CSR from an order", %{order: order} do
    %{"type" => "dns", "value" => domain_name} = List.first(order.identifiers)
    csr = ExAcme.Order.to_csr(order, @private_key)
    {:Extension, _, _, [dNSName: name]} = csr |> X509.CSR.extension_request() |> List.first()

    assert name == String.to_charlist(domain_name)
  end

  test "fetching a certificate", %{order: order, client: client, account_key: account_key} do
    ExAcme.TestHelpers.validate_order(order, account_key, client)
    csr = ExAcme.Order.to_csr(order, @private_key)

    ExAcme.finalize_order(order.finalize_url, csr, account_key, client)

    assert_eventually {:ok, %{status: "valid", certificate_url: certificate_url}} =
                        ExAcme.fetch_order(order.url, account_key, client)

    assert {:ok, certificates} = ExAcme.fetch_certificates(certificate_url, account_key, client)
    assert certificates != []
  end
end
