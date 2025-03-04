defmodule ExAcme.RegistrationBuilder do
  @moduledoc """
  Represents an [ACME Account registration](https://datatracker.ietf.org/doc/html/rfc8555#section-7.3).

  Provides functionalities to create and manage account registrations with the ACME server.

  ## Attributes

    - `contact` - List of contact URIs.
    - `terms_of_service_agreed` - Boolean indicating agreement to terms.
    - `only_return_existing` - Boolean to indicate if only existing accounts should be returned.
    - `external_account_binding` - External account binding information.
  """

  defstruct [:contact, :terms_of_service_agreed, :only_return_existing, :external_account_binding]

  @typedoc "ACME Account registration object"
  @type t() :: %__MODULE__{
          contact: [String.t()],
          terms_of_service_agreed: boolean(),
          only_return_existing: boolean(),
          external_account_binding: map() | nil
        }

  @doc """
  Creates a new account registration struct with default values.

  ## Returns

    - `ExAcme.RegistrationBuilder` struct.
  """
  @spec new_registration() :: t()
  def new_registration do
    %__MODULE__{contact: [], terms_of_service_agreed: false, only_return_existing: false, external_account_binding: nil}
  end

  @doc """
  Adds contact URIs to the registration.

  ## Parameters

    - `registration` - The current registration struct.
    - `contacts` - A list or single contact URI.

  ## Returns

    - Updated `ExAcme.RegistrationBuilder` struct.
  """
  @spec contacts(t(), [String.t()] | String.t()) :: t()
  def contacts(registration, contacts) do
    %__MODULE__{registration | contact: List.wrap(contacts)}
  end

  @doc """
  Agrees to the terms of service for the registration.

  ## Parameters

    - `registration` - The current registration struct.

  ## Returns

    - Updated `ExAcme.RegistrationBuilder` struct.
  """
  @spec agree_to_terms(t()) :: t()
  def agree_to_terms(registration) do
    %__MODULE__{registration | terms_of_service_agreed: true}
  end

  @doc """
  Configures the external account binding for the registration.

  This function sets up an external account binding using the provided key, client,
  external account binding key ID, and MAC key.

  ## Parameters

    - `registration` - The current registration struct.
    - `key` - The `JOSE.JWK` key being registered.
    - `client` - The ExAcme client name or pid.
    - `eab_kid` - The external account binding key ID.
    - `eab_mac_key` - The external account binding MAC key. This must be a valid base64url-encoded
       string.

  ## Returns

    - Updated `ExAcme.RegistrationBuilder` struct with external account binding.
  """
  @spec external_account_binding(t(), JOSE.JWK.t(), ExAcme.client(), String.t(), String.t()) :: t()
  def external_account_binding(registration, key, client, eab_kid, eab_mac_key) do
    url = ExAcme.Request.lookup_named_url("newAccount", client)

    header = %{
      "alg" => "HS256",
      "kid" => eab_kid,
      "url" => url
    }

    payload = key |> JOSE.JWK.to_public_map() |> elem(1) |> Jason.encode!()
    mac_key = eab_mac_key |> Base.url_decode64!(padding: false) |> JOSE.JWK.from_oct()
    signature = mac_key |> JOSE.JWS.sign(payload, header) |> elem(1)
    %__MODULE__{registration | external_account_binding: signature}
  end

  @doc """
  Converts the registration struct to a map.

  This function transforms the RegistrationBuilder struct into a map format,
  removes nil values, and converts keys to camelCase for API compatibility.

  ## Parameters

    - `registration` - The current registration struct.

  ## Returns

    - A map representation of the registration.
  """
  @spec to_map(t()) :: map()
  def to_map(registration) do
    registration
    |> Map.from_struct()
    |> Map.reject(fn {_, value} -> value == nil end)
  end
end
