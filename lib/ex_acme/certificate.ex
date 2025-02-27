defmodule ExAcme.Certificate do
  @moduledoc """
  Handles ACME certificate operations.

  Provides functionalities to fetch certificates and generate Certificate Signing Requests (CSRs).
  """

  @doc """
  Fetches a certificate chain from the ACME server.

  ## Parameters

    - `url` - The certificate URL.
    - `account_key` - The account key for authentication.
    - `client` - The ExAcme client agent.

  ## Returns

    - `{:ok, certificates}` on success.
    - `{:error, reason}` on failure.
  """
  @spec fetch(String.t(), ExAcme.AccountKey.t(), ExAcme.client()) :: {:ok, [X509.Certificate.t()]} | {:error, term()}
  def fetch(url, account_key, client) do
    request = ExAcme.Request.build_fetch(url)

    with {:ok, response} <- ExAcme.send_request(request, account_key, client) do
      {:ok, X509.from_pem(response.body)}
    end
  end

  @doc """
  Generates a Certificate Signing Request (CSR) from an order and a private key.

  ## Parameters

    - `order` - The ACME order.
    - `private_key` - The private key to sign the CSR and associate with the certificate.

  ## Returns

    - `%X509.CSR{}` struct.
  """
  @spec csr_from_order(ExAcme.Order.t(), X509.PrivateKey.t()) :: X509.CSR.t()
  def csr_from_order(order, private_key) do
    cn = order.identifiers |> List.first() |> Map.get("value")
    subject_alt_names = Enum.map(order.identifiers, &Map.get(&1, "value"))

    X509.CSR.new(private_key, "CN=#{cn}",
      extension_request: [
        X509.Certificate.Extension.subject_alt_name(subject_alt_names)
      ]
    )
  end
end
