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

  test "only return existing with no existing account", %{client: client} do
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

  test "only return existing with existing account", %{client: client} do
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

  test "external account binding", %{client: client} do
    key = %{
      "alg" => "ES256",
      "crv" => "P-256",
      "d" => "hoRe_jV87Vqd5O0yqr6xFaERBIACzFXCJxXc8PzwKn4",
      "kty" => "EC",
      "use" => "sig",
      "x" => "AMv5Ucpq9LN9ItxECdNWhF5_PAYFc4rzfldX2GFMfmY",
      "y" => "dyArqcwTzAzmcffGotj-gfL6YmLvhOHPhOMbfxMi_0k"
    }

    eab_kid = "https://example.com/eab"
    eab_key = "lz7ytuIS2Il_GRFGC2bMEM32qI5ejhke9eQCBlbJE7c"

    %ExAcme.RegistrationBuilder{external_account_binding: eab} =
      ExAcme.RegistrationBuilder.new_registration()
      |> ExAcme.RegistrationBuilder.contacts("mailto:admin@example.com")
      |> ExAcme.RegistrationBuilder.agree_to_terms()
      |> ExAcme.RegistrationBuilder.external_account_binding(key, client, eab_kid, eab_key)

    assert eab == %{
             "payload" =>
               "eyJhbGciOiJFUzI1NiIsImNydiI6IlAtMjU2Iiwia3R5IjoiRUMiLCJ1c2UiOiJzaWciLCJ4IjoiQU12NVVjcHE5TE45SXR4RUNkTldoRjVfUEFZRmM0cnpmbGRYMkdGTWZtWSIsInkiOiJkeUFycWN3VHpBem1jZmZHb3RqLWdmTDZZbUx2aE9IUGhPTWJmeE1pXzBrIn0",
             "protected" =>
               "eyJhbGciOiJIUzI1NiIsImtpZCI6Imh0dHBzOi8vZXhhbXBsZS5jb20vZWFiIiwidXJsIjoiaHR0cHM6Ly9wZWJibGU6MTQwMDAvc2lnbi1tZS11cCJ9",
             "signature" => "roQDAoexWcvEh6DwOFCV12yUnaA31FcTZmSNaJAWYtI"
           }
  end

  test "builder with single URI contact" do
    %ExAcme.RegistrationBuilder{contact: contact} =
      ExAcme.RegistrationBuilder.contacts(ExAcme.RegistrationBuilder.new_registration(), "https://example.com")

    assert contact == ["https://example.com"]
  end

  test "builder with multiple URI contacts" do
    %ExAcme.RegistrationBuilder{contact: contact} =
      ExAcme.RegistrationBuilder.contacts(
        ExAcme.RegistrationBuilder.new_registration(),
        ["https://example.com", "https://example.org"]
      )

    assert contact == ["https://example.com", "https://example.org"]
  end

  test "builder with single email contact" do
    %ExAcme.RegistrationBuilder{contact: contact} =
      ExAcme.RegistrationBuilder.contacts(ExAcme.RegistrationBuilder.new_registration(), email: "admin@example.com")

    assert contact == ["mailto:admin@example.com"]
  end

  test "builder with multiple email contacts" do
    %ExAcme.RegistrationBuilder{contact: contact} =
      ExAcme.RegistrationBuilder.contacts(ExAcme.RegistrationBuilder.new_registration(),
        email: ["admin@example.com", "user@example.com"]
      )

    assert contact == ["mailto:admin@example.com", "mailto:user@example.com"]
  end
end
