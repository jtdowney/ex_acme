defmodule ExAcme.AccountKey do
  @moduledoc """
  Handles the ACME account key operations.

  Provides functionalities to generate keys, sign requests, and manage key identifiers.

  ### Attributes

    - `key` - The JOSE JSON Web Key (JWK).
    - `algorithm` - The algorithm of the key (e.g., ES256).
    - `kid` - The Key ID assigned by the server.
  """

  defstruct [:key, :algorithm, :kid]

  @typedoc "Account key for authenticating requests"
  @type t :: %__MODULE__{key: JOSE.JWK.t(), algorithm: String.t(), kid: String.t()}

  @doc """
  Creates a new account key from a JOSE JSON Web Key (JWK) and the Key ID assigned by the server.

  ## Parameters

    - `key` - The JOSE JSON Web Key (JWK).
    - `kid` - The Key ID assigned by the server.

  ## Returns

    - A new `ExAcme.AccountKey` struct.
  """
  @spec new(JOSE.JWK.t(), String.t() | nil) :: t()
  def new(key, kid) do
    algorithm = key |> JOSE.JWK.to_map() |> elem(1) |> Map.fetch!("alg")
    %__MODULE__{key: key, algorithm: algorithm, kid: kid}
  end

  @doc """
  Signs a request body with the account key.

  ## Parameters

    - `account_key` - The account key.
    - `body` - The request body to sign.
    - `header` - Additional headers.

  ## Returns

    - The signed JSON Web Signature (JWS).
  """
  @spec sign(t(), binary(), map()) :: map()
  def sign(%__MODULE__{key: key, algorithm: algorithm, kid: kid}, body, header) do
    header = Map.merge(header, %{"alg" => algorithm, "kid" => kid})
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

    - A map representing the public JSON Web Key (JWK).
  """
  @spec to_public(t()) :: map()
  def to_public(%__MODULE__{key: key}) do
    key |> JOSE.JWK.to_public_map() |> elem(1)
  end
end
