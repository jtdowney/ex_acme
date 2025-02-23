defmodule ExAcme.Order do
  @moduledoc """
  Represents an [ACME Order object](https://tools.ietf.org/html/rfc8555#section-7.1.3).

  Provides functionalities to fetch, finalize, and parse order details from the ACME server.

  ## Attributes

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

  @doc """
  Fetches an order from the ACME server.

  ## Parameters

    - `url` - The order URL.
    - `account_key` - The account key for authentication.
    - `client` - The ExAcme client agent.

  ## Returns

    - `{:ok, order}` on success.
    - `{:error, reason}` on failure.
  """
  @spec fetch(String.t(), ExAcme.AccountKey.t(), ExAcme.client()) :: {:ok, t()} | {:error, term()}
  def fetch(url, account_key, client) do
    request = %ExAcme.SimpleRequest{url: url}

    with {:ok, response} <- ExAcme.send_request(request, account_key, client) do
      {:ok, from_response(url, response.body)}
    end
  end

  @doc """
  Finalizes an order by submitting a Certificate Signing Request (CSR).

  ## Parameters

    - `finalize_url` - The finalize URL from the order.
    - `csr` - The Certificate Signing Request.
    - `account_key` - The account key for authentication.
    - `client` - The ExAcme client agent.

  ## Returns

    - `{:ok, order}` on success.
    - `{:error, reason}` on failure.
  """
  @spec finalize(String.t(), X509.CSR.t(), ExAcme.AccountKey.t(), ExAcme.client()) :: {:ok, t()} | {:error, term()}
  def finalize(finalize_url, csr, account_key, client) do
    csr = csr |> X509.CSR.to_der() |> Base.url_encode64(padding: false)
    request = %ExAcme.SimpleRequest{url: finalize_url, body: %{csr: csr}}

    with {:ok, response} <- ExAcme.send_request(request, account_key, client) do
      {:ok, from_response(finalize_url, response.body)}
    end
  end

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
end
