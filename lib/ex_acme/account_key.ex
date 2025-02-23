defmodule ExAcme.AccountKey do
  @moduledoc """
  Handles the ACME account key operations.

  Provides functionalities to generate keys, sign requests, and manage key identifiers.

  ## Attributes

    - `key` - The JOSE JSON Web Key (JWK).
    - `type` - The type of the key (e.g., :ec256, :ed25519).
    - `kid` - The Key ID assigned by the server.
  """

  defstruct [:key, :type, :kid]

  @typedoc "Account key for authenticating requests"
  @type t :: %__MODULE__{key: JOSE.JWK.t(), type: atom(), kid: String.t() | nil}

  @doc """
  Generates a new account key.

  ## Parameters

    - `type` - The type of key to generate (:ec256 or :ed25519). Defaults to :ec256.

  ## Returns

    - `%ExAcme.AccountKey{}` struct.
  """
  @spec generate(atom()) :: t()
  def generate(type \\ :ec256) do
    key = JOSE.JWK.generate_key(generate_algorithm(type))
    %__MODULE__{key: key, type: type, kid: nil}
  end

  @doc """
  Signs a request body with the account key.

  ## Parameters

    - `account_key` - The account key.
    - `body` - The request body to sign.
    - `header` - Additional headers.

  ## Returns

    - The signed JWS.
  """
  @spec sign(t(), binary(), map()) :: map()
  def sign(%__MODULE__{key: key, type: type, kid: kid} = account_key, body, header) do
    header = Map.put(header, "alg", header_algorithm(type))

    header =
      if kid do
        Map.put(header, "kid", kid)
      else
        Map.put(header, "jwk", to_public(account_key))
      end

    key |> JOSE.JWS.sign(body, header) |> elem(1)
  end

  @doc """
  Generates the thumbprint of the account key.

  ## Parameters

    - `account_key` - The account key.

  ## Returns

    - The thumbprint as a string.
  """
  @spec thumbprint(t()) :: String.t()
  def thumbprint(%__MODULE__{key: key}) do
    JOSE.JWK.thumbprint(key)
  end

  @doc """
  Converts the account key to its public representation.

  ## Parameters

    - `account_key` - The account key.

  ## Returns

    - A map representing the public JWK.
  """
  @spec to_public(t()) :: map()
  def to_public(%__MODULE__{key: key}) do
    key |> JOSE.JWK.to_public_map() |> elem(1)
  end

  @doc """
  Updates the Key ID (KID) of the account key.

  ## Parameters

    - `key` - The account key.
    - `kid` - The new Key ID.

  ## Returns

    - Updated `%ExAcme.AccountKey{}` struct.
  """
  @spec update_kid(t(), String.t()) :: t()
  def update_kid(account_key, kid) do
    %{account_key | kid: kid}
  end

  @doc """
  Serializes the account key to JSON.

  ## Parameters

    - `account_key` - The account key.

  ## Returns

    - JSON string representation of the account key.
  """
  @spec to_json(t()) :: String.t()
  def to_json(%__MODULE__{key: key, kid: kid, type: type}) do
    key = key |> JOSE.JWK.to_map() |> elem(1)
    Jason.encode!(%{key: key, kid: kid, type: type})
  end

  @doc """
  Deserializes the account key from JSON.

  ## Parameters

    - `json` - The JSON string representing the account key.

  ## Returns

    - `{:ok, %ExAcme.AccountKey{}}` on success.
    - `{:error, reason}` on failure.
  """
  @spec from_json(String.t()) :: {:ok, t()} | {:error, term()}
  def from_json(json) do
    with {:ok, data} <- Jason.decode(json) do
      key = JOSE.JWK.from_map(data["key"])
      {:ok, %__MODULE__{key: key, type: String.to_existing_atom(data["type"]), kid: data["kid"]}}
    end
  end

  defp generate_algorithm(:ec256), do: {:ec, "P-256"}
  defp generate_algorithm(:ed25519), do: {:okp, :Ed25519}

  defp header_algorithm(:ec256), do: "ES256"
  defp header_algorithm(:ed25519), do: "EdDSA"
end
