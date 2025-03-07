defmodule ExAcme.Authorization do
  @moduledoc """
  Represents an [ACME Authorization object](https://datatracker.ietf.org/doc/html/rfc8555#section-7.1.4).

  Provides functionalities to fetch and process authorization details from the ACME server.

  ### Attributes

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
