defmodule ExAcme.Request do
  @moduledoc """
  Provides functions to build and manage HTTP requests for the ACME API.
  """

  defstruct [:url, :body]

  @typedoc "The type of the request body."
  @type body :: String.t() | map()

  @typedoc "Request object"
  @type t :: %__MODULE__{
          url: String.t(),
          body: body()
        }

  @doc """
  Builds a fetch request with the given URL.

  ## Parameters

    - `url`: The URL to fetch.

  ## Returns

    - A request struct with the specified URL and an empty body.
  """
  @spec build_fetch(String.t()) :: t()
  def build_fetch(url) do
    %__MODULE__{
      url: url,
      body: ""
    }
  end

  @doc """
  Builds an update request with the given URL and body.

  ## Parameters

    - `url`: The URL to send the update to.
    - `body`: The content of the request body.

  ## Returns

    - A request struct with the specified URL and body.
  """
  @spec build_update(String.t(), body()) :: t()
  def build_update(url, body) do
    %__MODULE__{
      url: url,
      body: body
    }
  end

  @doc """
  Builds a named request by looking up the URL based on the given name and client.

  ## Parameters

    - `name`: The name identifier for the request URL.
    - `body`: The content of the request body.
    - `client`: The client used to fetch the directory information.

  ## Returns

    - A request struct with the looked-up URL and specified body.
  """
  @spec build_named(String.t(), body(), ExAcme.client()) :: t()
  def build_named(name, body, client) do
    %__MODULE__{
      url: lookup_named_url(name, client),
      body: body
    }
  end

  @doc """
  Looks up the URL associated with a given name from the client's directory.

  ## Parameters

    - `name`: The name identifier for the request URL.
    - `client`: The client used to fetch the directory information.

  ## Returns

    - The URL associated with the given name in the directory.
  """
  @spec lookup_named_url(String.t(), ExAcme.client()) :: String.t()
  def lookup_named_url(name, client) do
    %{directory: directory} = Agent.get(client, & &1)
    Map.fetch!(directory, name)
  end
end
