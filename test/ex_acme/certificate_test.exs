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
    {:ok, csr} = ExAcme.Order.to_csr(order, @private_key)
    {:Extension, _, _, [dNSName: name]} = csr |> X509.CSR.extension_request() |> List.first()

    assert name == String.to_charlist(domain_name)
  end

  test "fetching a certificate", %{order: order, client: client, account_key: account_key} do
    ExAcme.TestHelpers.validate_order(order, account_key, client)
    {:ok, csr} = ExAcme.Order.to_csr(order, @private_key)

    ExAcme.finalize_order(order, csr, account_key, client)

    assert_eventually {:ok, %{status: "valid", certificate_url: certificate_url}} =
                        ExAcme.fetch_order(order.url, account_key, client)

    assert {:ok, certificates} = ExAcme.fetch_certificates(certificate_url, account_key, client)
    assert certificates != []
  end

  test "fetching a wildcard certificate", %{client: client, account_key: account_key} do
    {:ok, order} = ExAcme.TestHelpers.create_order("*.example.com", account_key, client)
    ExAcme.TestHelpers.validate_order(order, account_key, client)
    {:ok, csr} = ExAcme.Order.to_csr(order, @private_key)

    ExAcme.finalize_order(order, csr, account_key, client)

    assert_eventually {:ok, %{status: "valid", certificate_url: certificate_url}} =
                        ExAcme.fetch_order(order.url, account_key, client)

    assert {:ok, certificates} = ExAcme.fetch_certificates(certificate_url, account_key, client)
    assert certificates != []
  end

  describe "alternate chains" do
    setup %{order: order, client: client, account_key: account_key} do
      ExAcme.TestHelpers.validate_order(order, account_key, client)
      {:ok, csr} = ExAcme.Order.to_csr(order, @private_key)
      ExAcme.finalize_order(order, csr, account_key, client)

      assert_eventually {:ok, %{status: "valid", certificate_url: certificate_url}} =
                          ExAcme.fetch_order(order.url, account_key, client)

      %{certificate_url: certificate_url}
    end

    test "fetches the default chain and every alternate", context do
      %{certificate_url: url, account_key: account_key, client: client} = context

      assert {:ok, [default_chain | alternates] = chains} =
               ExAcme.fetch_certificate_chains(url, account_key, client)

      assert {:ok, default_chain} == ExAcme.fetch_certificates(url, account_key, client)
      # pebble is started with PEBBLE_ALTERNATE_ROOTS
      assert alternates != []

      # every chain carries the same end-entity certificate, towards a different root
      assert chains |> Enum.map(&hd/1) |> Enum.uniq() |> length() == 1
      assert chains |> Enum.map(&top_issuer/1) |> Enum.uniq() |> length() == length(chains)
    end

    test "returns the chain leading to the preferred root", context do
      %{certificate_url: url, account_key: account_key, client: client} = context
      {:ok, [_default_chain, alternate | _]} = ExAcme.fetch_certificate_chains(url, account_key, client)

      assert {:ok, alternate} ==
               ExAcme.fetch_certificates(url, account_key, client, preferred_chain: top_issuer(alternate))
    end

    test "falls back to the default chain when no chain leads to the preferred root", context do
      %{certificate_url: url, account_key: account_key, client: client} = context
      {:ok, [default_chain | _]} = ExAcme.fetch_certificate_chains(url, account_key, client)

      assert {:ok, default_chain} ==
               ExAcme.fetch_certificates(url, account_key, client, preferred_chain: "No Such Root")
    end
  end

  defp top_issuer(chain) do
    [name] = chain |> List.last() |> X509.Certificate.issuer("CN")
    name
  end
end
