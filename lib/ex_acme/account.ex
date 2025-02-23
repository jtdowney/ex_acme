defmodule ExAcme.Account do
  @moduledoc """
  Represents an [ACME Account object](https://www.rfc-editor.org/rfc/rfc8555.html#section-7.1.2).

  Provides functionalities to fetch account details from the ACME server.

  ## Attributes

    - `url` - The URL of the account.
    - `status` - The current status of the account.
    - `contact_urls` - List of contact URLs.
    - `terms_of_service_agreed` - Boolean indicating agreement to terms of service.
    - `external_account_binding` - External account binding information.
    - `orders_url` - URL to fetch the list of orders.
  """

  defstruct [:url, :status, :contact_urls, :external_account_binding, :orders_url]

  @typedoc "ACME Account object"
  @type t :: %__MODULE__{
          url: String.t(),
          status: String.t(),
          contact_urls: [String.t()],
          external_account_binding: String.t() | nil,
          orders_url: String.t()
        }

  @doc """
  Fetches an account from the ACME server.

  ## Parameters

    - `url` - The account URL.
    - `account_key` - The account key for authentication.
    - `client` - The ExAcme client agent.

  ## Returns

    - `{:ok, account}` on success.
    - `{:error, reason}` on failure.
  """
  @spec fetch(String.t(), ExAcme.AccountKey.t(), ExAcme.client()) ::
          {:ok, ExAcme.Account.t()} | {:error, term()}
  def fetch(url, account_key, client) do
    request = %ExAcme.SimpleRequest{url: url}

    with {:ok, response} <- ExAcme.send_request(request, account_key, client) do
      {:ok, from_response(url, response.body)}
    end
  end

  @doc false
  @spec from_response(String.t(), map()) :: ExAcme.Account.t()
  def from_response(url, body) do
    %__MODULE__{
      url: url,
      status: body["status"],
      contact_urls: body["contact"],
      external_account_binding: body["externalAccountBinding"],
      orders_url: body["orders"]
    }
  end
end
