defmodule ExAcme.Authorization do
  @moduledoc """
  Represents an [ACME Authorization object](https://datatracker.ietf.org/doc/html/rfc8555#section-7.1.4).

  Provides functionalities to fetch and process authorization details from the ACME server.

  ## Attributes

    - `url` - The URL of the authorization.
    - `status` - The current status of the authorization.
    - `expires` - Expiration datetime of the authorization.
    - `identifier` - The identifier (e.g., domain) associated with the authorization.
    - `challenges` - List of challenges available for the authorization.
    - `wildcard` - Boolean indicating if the authorization is for a wildcard domain.
  """

  defstruct [:url, :status, :expires, :identifier, :challenges, :wildcard]

  @typedoc "ACME Authorization object"
  @type t :: %__MODULE__{
          url: String.t(),
          status: String.t(),
          expires: DateTime.t() | nil,
          identifier: map(),
          challenges: [map()],
          wildcard: boolean()
        }

  @doc """
  Fetches an authorization from the ACME server.

  ## Parameters

    - `url` - The authorization URL.
    - `account_key` - The account key for authentication.
    - `client` - The ExAcme client agent.

  ## Returns

    - `{:ok, authorization}` on success.
    - `{:error, reason}` on failure.
  """
  @spec fetch(String.t(), ExAcme.AccountKey.t(), ExAcme.client()) :: {:ok, t()} | {:error, term()}
  def fetch(url, account_key, client) do
    request = %ExAcme.SimpleRequest{url: url}

    with {:ok, %{body: body}} <- ExAcme.send_request(request, account_key, client) do
      {:ok, from_response(url, body)}
    end
  end

  @doc false
  @spec from_response(String.t(), map()) :: t()
  def from_response(url, body) do
    %__MODULE__{
      url: url,
      status: body["status"],
      expires: ExAcme.Utils.datetime_from_rfc3339(body["expires"]),
      identifier: body["identifier"],
      challenges: body["challenges"],
      wildcard: body["wildcard"]
    }
  end
end
