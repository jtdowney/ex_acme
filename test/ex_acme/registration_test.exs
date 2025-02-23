defmodule ExAcme.RegistrationTest do
  use ExAcme.TestCase, async: true

  test "successful registration", %{client: client} do
    account_key = ExAcme.AccountKey.generate()

    {:ok, account} =
      ExAcme.Registration.new()
      |> ExAcme.Registration.contacts(["mailto:admin@example.com", "mailto:dev@example.com"])
      |> ExAcme.Registration.agree_to_terms()
      |> ExAcme.Registration.register(account_key, client)

    assert account.status == "valid"
    assert account.contact_urls == ["mailto:admin@example.com", "mailto:dev@example.com"]
    assert String.starts_with?(account.orders_url, "https://pebble:14000/list-orderz/")
    assert String.starts_with?(account.url, "https://pebble:14000/my-account/")
  end

  test "registration missing terms agreement", %{client: client} do
    account_key = ExAcme.AccountKey.generate()

    {:error, body} =
      ExAcme.Registration.new()
      |> ExAcme.Registration.contacts(["mailto:admin@example.com", "mailto:dev@example.com"])
      |> ExAcme.Registration.register(account_key, client)

    assert body["status"] == 403
    assert body["type"] == "urn:ietf:params:acme:error:agreementRequired"
  end

  test "only_return_existing with no existing account", %{client: client} do
    account_key = ExAcme.AccountKey.generate()

    {:error, body} =
      ExAcme.Registration.new()
      |> ExAcme.Registration.contacts(["mailto:admin@example.com", "mailto:dev@example.com"])
      |> ExAcme.Registration.agree_to_terms()
      |> ExAcme.Registration.register(account_key, client, only_return_existing: true)

    assert body["status"] == 400
    assert body["type"] == "urn:ietf:params:acme:error:accountDoesNotExist"
  end

  test "only_return_existing with existing account", %{client: client} do
    account_key = ExAcme.AccountKey.generate()

    {:ok, account1} =
      ExAcme.Registration.new()
      |> ExAcme.Registration.contacts(["mailto:admin@example.com", "mailto:dev@example.com"])
      |> ExAcme.Registration.agree_to_terms()
      |> ExAcme.Registration.register(account_key, client)

    {:ok, account2} =
      ExAcme.Registration.new()
      |> ExAcme.Registration.contacts(["mailto:admin@example.com", "mailto:dev@example.com"])
      |> ExAcme.Registration.register(account_key, client, only_return_existing: true)

    assert account1 == account2
  end
end
