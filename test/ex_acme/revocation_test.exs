defmodule ExAcme.RevocationTest do
  use ExAcme.TestCase, async: true

  setup %{client: client} do
    key = ExAcme.generate_key()
    {account_key, _} = ExAcme.TestHelpers.create_account(key, client)
    {:ok, order} = ExAcme.TestHelpers.create_order(account_key, client)

    %{account_key: account_key, client: client, order: order}
  end

  test "revoking a DER encoded certificate", %{order: order, client: client, account_key: account_key} do
    {certificates, _} = ExAcme.TestHelpers.issue_certificate(order, account_key, client)

    der =
      certificates
      |> List.first()
      |> X509.Certificate.to_der()

    assert :ok = ExAcme.revoke_certificate(%{certificate: der}, account_key, client)
  end

  test "revoking a DER encoded certificate with builder", %{order: order, client: client, account_key: account_key} do
    {certificates, _} = ExAcme.TestHelpers.issue_certificate(order, account_key, client)

    der =
      certificates
      |> List.first()
      |> X509.Certificate.to_der()

    assert :ok =
             ExAcme.RevocationBuilder.new_revocation()
             |> ExAcme.RevocationBuilder.certificate(der: der)
             |> ExAcme.revoke_certificate(account_key, client)
  end

  test "revoking a PEM encoded certificate", %{order: order, client: client, account_key: account_key} do
    {certificates, _} = ExAcme.TestHelpers.issue_certificate(order, account_key, client)

    pem =
      certificates
      |> List.first()
      |> X509.Certificate.to_pem()

    assert :ok =
             ExAcme.RevocationBuilder.new_revocation()
             |> ExAcme.RevocationBuilder.certificate(pem: pem)
             |> ExAcme.revoke_certificate(account_key, client)
  end

  test "revoking a certificate object", %{order: order, client: client, account_key: account_key} do
    {certificates, _} = ExAcme.TestHelpers.issue_certificate(order, account_key, client)
    certificate = List.first(certificates)

    assert :ok =
             ExAcme.RevocationBuilder.new_revocation()
             |> ExAcme.RevocationBuilder.certificate(certificate: certificate)
             |> ExAcme.revoke_certificate(account_key, client)
  end

  test "revoking a certificate with reason", %{order: order, client: client, account_key: account_key} do
    {certificates, _} = ExAcme.TestHelpers.issue_certificate(order, account_key, client)
    certificate = List.first(certificates)

    assert :ok =
             ExAcme.RevocationBuilder.new_revocation()
             |> ExAcme.RevocationBuilder.certificate(certificate: certificate)
             |> ExAcme.RevocationBuilder.reason(4)
             |> ExAcme.revoke_certificate(account_key, client)
  end

  test "revoking a certificate with named reason", %{order: order, client: client, account_key: account_key} do
    {certificates, _} = ExAcme.TestHelpers.issue_certificate(order, account_key, client)
    certificate = List.first(certificates)

    assert :ok =
             ExAcme.RevocationBuilder.new_revocation()
             |> ExAcme.RevocationBuilder.certificate(certificate: certificate)
             |> ExAcme.RevocationBuilder.reason(:key_compromise)
             |> ExAcme.revoke_certificate(account_key, client)
  end
end
