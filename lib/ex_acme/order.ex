defmodule ExAcme.Order do
  @moduledoc """
  Represents an [ACME Order object](https://datatracker.ietf.org/doc/html/rfc8555#section-7.1.3).

  Provides functionalities to fetch, finalize, and parse order details from the ACME server.

  ### Attributes

    - `url` - The URL of the order.
    - `status` - The current status of the order.
    - `expires` - Expiration datetime of the order.
    - `identifiers` - List of domain identifiers associated with the order.
    - `profile` - The profile associated with the order.
    - `not_before` - Start datetime of the order's validity.
    - `not_after` - End datetime of the order's validity.
    - `error` - Any error associated with the order.
    - `authorizations` - List of authorization URLs.
    - `finalize_url` - URL to finalize the order.
    - `certificate_url` - URL to retrieve the issued certificate.
  """

  alias X509.Certificate.Extension

  defstruct [
    :url,
    :status,
    :expires,
    :identifiers,
    :profile,
    :not_before,
    :not_after,
    :error,
    :authorizations,
    :finalize_url,
    :certificate_url
  ]

  @typedoc "ACME Order object"
  @type t :: %__MODULE__{
          url: String.t(),
          status: String.t(),
          expires: DateTime.t() | nil,
          identifiers: [map()],
          profile: String.t(),
          not_before: DateTime.t() | nil,
          not_after: DateTime.t() | nil,
          error: map() | nil,
          authorizations: [String.t()],
          finalize_url: String.t(),
          certificate_url: String.t() | nil
        }

  @doc false
  @spec from_response(String.t(), map()) :: t()
  def from_response(location, body) do
    %__MODULE__{
      url: location,
      status: body["status"],
      expires: ExAcme.Utils.datetime_from_rfc3339(body["expires"]),
      identifiers: body["identifiers"],
      profile: body["profile"],
      not_before: ExAcme.Utils.datetime_from_rfc3339(body["notBefore"]),
      not_after: ExAcme.Utils.datetime_from_rfc3339(body["notAfter"]),
      error: body["error"],
      authorizations: body["authorizations"],
      finalize_url: body["finalize"],
      certificate_url: body["certificate"]
    }
  end

  @doc """
  Generates a Certificate Signing Request (CSR) from an order and a private key.

  ## Parameters

    - `order` - The ACME order.
    - `private_key` - The private key to sign the CSR and associate with the certificate.

  ## Returns

    - `{:ok, X509.CSR.t()}` - The generated CSR.
    - `{:error, :empty_identifiers}` - If the order has no identifiers.
  """
  @spec to_csr(ExAcme.Order.t(), X509.PrivateKey.t()) :: {:ok, X509.CSR.t()} | {:error, :empty_identifiers}
  def to_csr(order, private_key) do
    case order.identifiers do
      [] ->
        {:error, :empty_identifiers}

      identifiers ->
        cn = identifiers |> List.first() |> Map.get("value")
        subject_alt_names = Enum.map(identifiers, &Map.get(&1, "value"))

        csr =
          X509.CSR.new(private_key, "CN=#{cn}",
            extension_request: [
              Extension.subject_alt_name(subject_alt_names)
            ]
          )

        {:ok, csr}
    end
  end
end
