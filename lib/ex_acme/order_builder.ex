defmodule ExAcme.OrderBuilder do
  @moduledoc """
  Represents an [ACME Order request](https://datatracker.ietf.org/doc/html/rfc8555#section-7.4).

  Provides functionalities to build and submit order requests to the ACME server.

  ## Attributes

    - `identifiers` - List of identifiers for the order.
    - `profile` - The profile to apply to the order.
    - `not_before` - Request start time for the certificate.
    - `not_after` - Request end time for the certificate.
  """

  defstruct [:identifiers, :profile, :not_before, :not_after]

  @typedoc "ACME Order request object"
  @type t() :: %__MODULE__{
          identifiers: [%{type: String.t(), value: String.t()}],
          profile: String.t() | nil,
          not_before: DateTime.t() | nil,
          not_after: DateTime.t() | nil
        }

  @doc """
  Creates a new order request with default values.

  ## Returns

    - `ExAcme.OrderBuilder` struct.
  """
  @spec new_order() :: t()
  def new_order do
    %__MODULE__{
      identifiers: [],
      profile: nil,
      not_before: nil,
      not_after: nil
    }
  end

  @doc """
  Adds an identifier to the order request.

  ## Parameters

    - `order` - The current order request.
    - `type` - The type of identifier (e.g., "dns").
    - `value` - The value of the identifier (e.g., domain name).

  ## Returns

    - Updated `ExAcme.OrderBuilder` struct.
  """
  def add_identifier(%__MODULE__{identifiers: identifiers} = order, type, value) do
    %{order | identifiers: [%{type: type, value: value} | identifiers]}
  end

  @doc """
  Adds a DNS identifier to the order request.

  ## Parameters

    - `order` - The current order request.
    - `domain` - The domain name to add.

  ## Returns

    - Updated `ExAcme.OrderBuilder` struct.
  """
  @spec add_dns_identifier(t(), String.t()) :: t()
  def add_dns_identifier(order, domain) do
    add_identifier(order, "dns", domain)
  end

  @doc """
  Sets the profile for the order request.

  ## Parameters

    - `order` - The current order request.
    - `profile` - The profile name.

  ## Returns

    - Updated `ExAcme.OrderBuilder` struct.
  """
  @spec profile(t(), String.t()) :: t()
  def profile(order, profile) do
    %{order | profile: profile}
  end

  @doc """
  Sets the requested end time for the certificate.

  ## Parameters

    - `order` - The current order request.
    - `date` - The end datetime.

  ## Returns

    - Updated `ExAcme.OrderBuilder` struct.
  """
  @spec not_after(t(), DateTime.t()) :: t()
  def not_after(order, date) do
    %{order | not_after: date}
  end

  @doc """
  Sets the requested start time for the certificate.

  ## Parameters

    - `order` - The current order request.
    - `date` - The start datetime.

  ## Returns

    - Updated `ExAcme.OrderBuilder` struct.
  """
  @spec not_before(t(), DateTime.t()) :: t()
  def not_before(order, date) do
    %{order | not_before: date}
  end

  @doc """
  Converts an order request to a map.

  This function transforms the OrderBuilder struct into a map format,
  removes nil values, and converts keys to camelCase for API compatibility.

  ## Parameters

    - `order` - The order request to convert.

  ## Returns

    - A map representation of the order.
  """
  @spec to_map(t()) :: map()
  def to_map(order) do
    order
    |> Map.from_struct()
    |> Map.reject(fn {_, value} -> value == nil end)
  end
end
