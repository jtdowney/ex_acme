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

    - `authorization` - The authorization object.
    - `type` - The type of challenge to find (e.g., "dns-01").

  ## Returns

    - The challenge object if found, else `nil`.
  """
  @spec find_by_type(ExAcme.Authorization.t(), String.t()) :: t() | nil
  def find_by_type(authorization, type) do
    case Enum.find(authorization.challenges, &(Map.get(&1, "type") == type)) do
      nil ->
        nil

      challenge ->
        {url, challenge} = Map.pop(challenge, "url")
        from_response(url, challenge)
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
