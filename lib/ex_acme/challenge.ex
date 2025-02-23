defmodule ExAcme.Challenge do
  @moduledoc """
  Represents an [ACME Challenge object](https://datatracker.ietf.org/doc/html/rfc8555#section-7.1.5).

  Provides functionalities to handle challenges required for validation.

  ## Attributes

    - `url` - The URL of the challenge.
    - `status` - The current status of the challenge.
    - `type` - The type of challenge (e.g., "dns-01").
    - `token` - The challenge token.
    - `validated` - Datetime when the challenge was validated.
    - `error` - Any error associated with the challenge.
  """

  defstruct [:url, :status, :type, :token, :validated, :error]

  @typedoc "ACME Challenge Object"
  @type t :: %__MODULE__{
          url: String.t(),
          status: String.t(),
          type: String.t(),
          token: String.t() | nil,
          validated: DateTime.t() | nil,
          error: map() | nil
        }

  @doc """
  Finds a challenge of a specific type within an authorization.

  ## Parameters

    - `authorization` - The authorization map.
    - `type` - The type of challenge to find (e.g., "dns-01").

  ## Returns

    - The challenge object if found, else `nil`.
  """
  @spec find_by_type(map(), String.t()) :: t() | nil
  def find_by_type(authorization, type) do
    case Enum.find(authorization.challenges, &(Map.get(&1, "type") == type)) do
      nil ->
        nil

      challenge ->
        {url, challenge} = Map.pop(challenge, "url")
        from_response(url, challenge)
    end
  end

  @doc """
  Fetches a challenge from the ACME server.

  ## Parameters

    - `url` - The challenge URL.
    - `account_key` - The account key for authentication.
    - `client` - The ExAcme client agent.

  ## Returns

    - `{:ok, challenge}` on success.
    - `{:error, reason}` on failure.
  """
  @spec fetch(String.t(), ExAcme.AccountKey.t(), ExAcme.client()) :: {:ok, t()} | {:error, term()}
  def fetch(url, account_key, client) do
    request = %ExAcme.SimpleRequest{url: url}

    with {:ok, response} <- ExAcme.send_request(request, account_key, client) do
      {:ok, from_response(url, response.body)}
    end
  end

  @doc false
  @spec from_response(String.t(), map()) :: t()
  def from_response(url, challenge) do
    %__MODULE__{
      url: url,
      status: challenge["status"],
      type: challenge["type"],
      token: challenge["token"],
      validated: ExAcme.Utils.datetime_from_rfc3339(challenge["validated"]),
      error: challenge["error"]
    }
  end

  @doc """
  Triggers the validation of a challenge.

  ## Parameters

    - `url` - The challenge URL.
    - `account_key` - The account key for authentication.
    - `client` - The ExAcme client agent.

  ## Returns

    - `{:ok, challenge}` on success.
    - `{:error, reason}` on failure.
  """
  @spec trigger_validation(String.t(), ExAcme.AccountKey.t(), ExAcme.client()) :: {:ok, t()} | {:error, term()}
  def trigger_validation(url, account_key, client) do
    request = %ExAcme.SimpleRequest{url: url, body: %{}}

    with {:ok, %{body: body}} <- ExAcme.send_request(request, account_key, client) do
      {:ok, from_response(url, body)}
    end
  end

  @doc """
  Generates the key authorization string for a challenge.

  ## Parameters

    - `token` - The challenge token.
    - `account_key` - The account key.

  ## Returns

    - The key authorization string.
  """
  @spec key_authorization(String.t(), ExAcme.AccountKey.t()) :: String.t()
  def key_authorization(token, account_key) do
    thumbprint = ExAcme.AccountKey.thumbprint(account_key)
    "#{token}.#{thumbprint}"
  end
end
