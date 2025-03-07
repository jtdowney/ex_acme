defmodule ExAcme.RevocationBuilder do
  @moduledoc """
  Provides functionality to build ACME certificate revocation requests.

  Use this module to construct a revocation request by supplying the certificate in one of several formats
  (`X509.Certificate` struct, DER binary, or PEM string) and an optional revocation reason.

  ### Attributes

    - `certificate` - The DER-encoded certificate to revoke
    - `reason` - The revocation reason
  """
  defstruct [:certificate, :reason]

  @reason_codes %{
    unspecified: 0,
    key_compromise: 1,
    affiliation_changed: 3,
    superseded: 4,
    cessation_of_operation: 5
  }

  @typedoc "A certificate revocation builder"
  @type t :: %__MODULE__{
          certificate: binary() | nil,
          reason: integer() | nil
        }

  @doc """
  Creates a new revocation builder.

  ## Returns

    - A new `ExAcme.RevocationBuilder` struct with no certificate or reason set.
  """
  @spec new_revocation() :: t()
  def new_revocation do
    %__MODULE__{
      certificate: nil,
      reason: nil
    }
  end

  @doc """
  Sets the certificate for revocation using an X509 certificate struct, DER binary, or PEM string.

  ## Parameters

    - `revocation`: The current revocation builder.
    - `certificate`: Keyword with one of the following options:
      - `certificate`: An `X509.Certificate` struct representing the certificate to revoke.
      - `der`: A DER-encoded binary of the certificate to revoke.
      - `pem`: A PEM-encoded string of the certificate to revoke.

  ## Returns

    - An updated `ExAcme.RevocationBuilder` struct with the certificate set.

  ## Examples

      # Using a certificate struct
      iex> cert = X509.Certificate.self_signed(X509.PrivateKey.new_ec(:secp256r1), "/CN=example.com")
      iex> revocation = ExAcme.RevocationBuilder.new_revocation()
      iex> |> ExAcme.RevocationBuilder.certificate(certificate: cert)

      # Using a PEM string
      iex> pem = File.read!("path/to/certificate.pem")
      iex> revocation = ExAcme.RevocationBuilder.new_revocation()
      iex> |> ExAcme.RevocationBuilder.certificate(pem: pem)

      # Using a DER binary
      iex> der = File.read!("path/to/certificate.der")
      iex> revocation = ExAcme.RevocationBuilder.new_revocation()
      iex> |> ExAcme.RevocationBuilder.certificate(der: der)
  """
  @spec certificate(t(), certificate: X509.Certificate.t(), der: binary(), pem: binary()) :: t()
  def certificate(revocation, certificate: certificate) do
    der = X509.Certificate.to_der(certificate)
    %{revocation | certificate: der}
  end

  def certificate(revocation, der: der) do
    %{revocation | certificate: der}
  end

  def certificate(revocation, pem: pem) do
    with {:ok, cert} <- X509.Certificate.from_pem(pem) do
      certificate(revocation, certificate: cert)
    end
  end

  @doc """
  Sets the revocation reason.

  Accepts either a named reason or a numeric reason code as defined in
  [RFC 5280](https://datatracker.ietf.org/doc/html/rfc5280#section-5.3.1).

  ## Parameters

    - `revocation`: The current revocation builder.
    - `reason`: An atom representing the reason (`:unspecified`, `:key_compromise`,
      `:affiliation_changed`, `:superseded`, or `:cessation_of_operation`) or an integer code.

  ## Returns

    - An updated `ExAcme.RevocationBuilder` struct with the reason set.

  ## Examples

      # Using a named reason
      iex> revocation = ExAcme.RevocationBuilder.new_revocation()
      iex> revocation = ExAcme.RevocationBuilder.reason(revocation, :key_compromise)
      iex> revocation.reason
      1

      # Using a numeric reason code
      iex> revocation = ExAcme.RevocationBuilder.new_revocation()
      iex> revocation = ExAcme.RevocationBuilder.reason(revocation, 4)
      iex> revocation.reason
      4
  """
  @spec reason(t(), atom() | integer()) :: t()
  def reason(revocation, reason) when is_atom(reason) do
    code = Map.fetch!(@reason_codes, reason)
    reason(revocation, code)
  end

  def reason(revocation, reason) do
    %{revocation | reason: reason}
  end

  @doc """
  Converts the revocation builder to a map.

  Removes any keys with nil values and converts all keys to camelCase for API compatibility.

  ## Parameters

    - `revocation`: The revocation builder struct.

  ## Returns

    - A map representing the revocation request.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = revocation) do
    revocation
    |> Map.from_struct()
    |> Map.reject(fn {_, value} -> value == nil end)
  end
end
