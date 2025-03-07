defmodule ExAcme.Account do
  @moduledoc """
  Represents an [ACME Account object](https://datatracker.ietf.org/doc/html/rfc8555#section-7.1.2).

  Provides functionalities to fetch account details from the ACME server.

  ### Attributes

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
