defmodule ExAcme.RegistrationTest do
  use ExAcme.TestCase, async: true

  test "successful registration", %{client: client} do
    key = ExAcme.generate_key()

    {:ok, account, account_key} =
      ExAcme.RegistrationBuilder.new_registration()
      |> ExAcme.RegistrationBuilder.contacts("mailto:admin@example.com")
      |> ExAcme.RegistrationBuilder.agree_to_terms()
      |> ExAcme.register_account(key, client)

    assert account.status == "valid"
    assert account.contact_urls == ["mailto:admin@example.com"]
    assert String.starts_with?(account.orders_url, "https://pebble:14000/list-orderz/")
    assert String.starts_with?(account.url, "https://pebble:14000/my-account/")
    assert account_key.key == key
    assert account_key.kid == account.url
  end

  test "successful registration without builder", %{client: client} do
    key = ExAcme.generate_key()

    {:ok, account, account_key} =
      ExAcme.register_account(%{contact: ["mailto:admin@example.com"], terms_of_service_agreed: true}, key, client)

    assert account.status == "valid"
    assert account.contact_urls == ["mailto:admin@example.com"]
    assert String.starts_with?(account.orders_url, "https://pebble:14000/list-orderz/")
    assert String.starts_with?(account.url, "https://pebble:14000/my-account/")
    assert account_key.key == key
    assert account_key.kid == account.url
  end

  test "registration missing terms agreement", %{client: client} do
    key = ExAcme.generate_key()

    {:error, body} =
      ExAcme.register_account(
        %{contact: ["mailto:admin@example.com", "mailto:dev@example.com"]},
        key,
        client
      )

    assert body["status"] == 403
    assert body["type"] == "urn:ietf:params:acme:error:agreementRequired"
  end

  test "only_return_existing with no existing account", %{client: client} do
    key = ExAcme.generate_key()

    {:error, body} =
      ExAcme.register_account(
        %{contact: ["mailto:admin@example.com", "mailto:dev@example.com"], terms_of_service_agreed: true},
        key,
        client,
        only_return_existing: true
      )

    assert body["status"] == 400
    assert body["type"] == "urn:ietf:params:acme:error:accountDoesNotExist"
  end

  test "only_return_existing with existing account", %{client: client} do
    key = ExAcme.generate_key()

    {:ok, account1, account_key1} =
      ExAcme.register_account(%{contact: ["mailto:admin@example.com"], terms_of_service_agreed: true}, key, client)

    {:ok, account2, account_key2} =
      ExAcme.register_account(%{contact: ["mailto:admin@example.com"], terms_of_service_agreed: true}, key, client,
        only_return_existing: true
      )

    assert account1 == account2
    assert account_key1 == account_key2
  end
end
