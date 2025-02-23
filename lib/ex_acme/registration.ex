defmodule ExAcme.Registration do
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
          external_account_binding: String.t() | nil
        }

  @doc """
  Creates a new account registration struct with default values.

  ## Returns

    - `%ExAcme.Registration{}` struct.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{contact: [], terms_of_service_agreed: false, only_return_existing: false, external_account_binding: nil}
  end

  @doc """
  Adds contact URIs to the registration.

  ## Parameters

    - `registration` - The current registration struct.
    - `contacts` - A list or single contact URI.

  ## Returns

    - Updated `%ExAcme.Registration{}` struct.
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

    - Updated `%ExAcme.Registration{}` struct.
  """
  @spec agree_to_terms(t()) :: t()
  def agree_to_terms(registration) do
    %__MODULE__{registration | terms_of_service_agreed: true}
  end

  @doc """
  Registers the account with the ACME server.

  ## Parameters

    - `registration` - The registration struct.
    - `account_key` - The account key for authentication.
    - `client` - The ExAcme client agent.
    - `opts` - Optional parameters.

  ## Options

    - `:only_return_existing` - If true, only existing accounts will be returned.

  ## Returns

    - `{:ok, account}` on success.
    - `{:error, reason}` on failure.
  """
  def register(registration, account_key, client, opts \\ []) do
    only_return_existing = Keyword.get(opts, :only_return_existing, false)
    registration = %{registration | only_return_existing: only_return_existing}

    with {:ok, %{body: body, headers: headers}} <-
           ExAcme.send_request(registration, account_key, client) do
      location = Map.get(headers, "location")
      account = ExAcme.Account.from_response(location, body)
      {:ok, account}
    end
  end
end

defimpl ExAcme.Request, for: ExAcme.Registration do
  @doc false
  def to_request(registration, %{directory: %{"newAccount" => url}}) do
    body =
      registration
      |> Map.from_struct()
      |> Map.reject(fn {_, value} -> value == nil end)
      |> ExAcme.Utils.to_camel_case()

    %{
      url: url,
      body: body
    }
  end
end
