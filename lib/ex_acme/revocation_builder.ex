defmodule ExAcme.RevocationBuilder do
  @moduledoc """
  Provides functionality to build ACME certificate revocation requests.

  Use this module to construct a revocation request by supplying the certificate in one of several formats
  (`X509.Certificate` struct, DER binary, or PEM string) and an optional revocation reason.
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
  Sets the certificate for revocation using an X509 certificate struct.

  ## Parameters

    - `revocation`: The current revocation builder.
    - `certificate`: An `X509.Certificate` struct representing the certificate to revoke.

  ## Returns

    - An updated `ExAcme.RevocationBuilder` struct with the certificate set.
  """
  @spec certificate(t(), X509.Certificate.t()) :: t()
  def certificate(revocation, certificate) do
    der = X509.Certificate.to_der(certificate)
    certificate_der(revocation, der)
  end

  @doc """
  Sets the certificate for revocation using a DER-encoded binary.

  ## Parameters

    - `revocation`: The current revocation builder.
    - `der`: A binary containing the DER-encoded certificate.

  ## Returns

    - An updated `ExAcme.RevocationBuilder` struct with the certificate set.
  """
  @spec certificate_der(t(), binary()) :: t()
  def certificate_der(revocation, der) do
    %{revocation | certificate: der}
  end

  @doc """
  Sets the certificate for revocation using a PEM-encoded string.

  ## Parameters

    - `revocation`: The current revocation builder.
    - `pem`: A string containing the PEM-encoded certificate.

  ## Returns

    - `{:ok, revocation}` if successful and the PEM certificate is valid.
    - `{:error, reason}` if the PEM certificate is invalid.
  """
  @spec certificate_pem(t(), String.t()) :: t()
  def certificate_pem(revocation, pem) do
    with {:ok, cert} <- X509.Certificate.from_pem(pem) do
      certificate(revocation, cert)
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
    |> ExAcme.Utils.to_camel_case()
  end
end
