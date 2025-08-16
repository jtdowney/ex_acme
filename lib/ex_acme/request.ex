defmodule ExAcme.Request do
  @moduledoc """
  Provides functions to build and manage HTTP requests for the ACME API.

  ### Attributes

    - `url` - The target URL for the request
    - `body` - The request body content (string or map)
  """

  defstruct [:url, :body]

  @content_type "application/jose+json"

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
    client
    |> ExAcme.directory()
    |> Map.fetch!(name)
  end

  @doc """
  Sends an HTTP request to the ACME API.

  This function handles the actual HTTP communication with the ACME server,
  including signing the request with the provided key, handling nonce refreshes,
  and processing the response.

  ## Parameters

    - `request`: The request struct containing URL and body.
    - `key` - The key used for authentication, it can either be an
      `ExAcme.AccountKey` or a `JOSE.JWK` depending on if the account is
      registered or not.
    - `client` - The pid or name of the ExAcme client agent.

  ## Returns

    - `{:ok, %{body: body(), headers: map()}}` - On successful request.
    - `{:error, {:retry_after, seconds}}` - When the server returns a Retry-After header,
      indicating the client should wait the specified number of seconds before retrying.
    - `{:error, reason}` - On other failures, with details about the error.
  """
  @spec send_request(t(), ExAcme.AccountKey.t() | JOSE.JWK.t(), ExAcme.client()) ::
          {:ok, %{body: body(), headers: map()}} | {:error, any()}
  def send_request(request, key, client) do
    user_agent = "ExAcme/#{Application.spec(:ex_acme, :vsn)}"
    headers = [content_type: @content_type, user_agent: user_agent]

    with {:ok, nonce} <- ExAcme.current_nonce(client),
         body = sign_request(request.url, request.body, key, nonce),
         {:ok, %{status: status, body: body, headers: headers}} <-
           Req.post(request.url, json: body, headers: headers) do
      maybe_refresh_nonce(client, headers)

      case {status, body} do
        {400, %{"type" => "urn:ietf:params:acme:error:badNonce"}} ->
          send_request(request, key, client)

        {status, body} when status >= 400 ->
          handle_error_response(headers, status, body)

        {_, body} ->
          {:ok, %{body: body, headers: Map.new(headers)}}
      end
    end
  end

  defp maybe_refresh_nonce(client, headers) do
    case Map.fetch(headers, "replay-nonce") do
      {:ok, [nonce]} -> Agent.update(client, &Map.put(&1, :nonce, nonce))
      _ -> nil
    end
  end

  defp handle_error_response(headers, status, body) do
    case extract_retry_after(headers) do
      {:ok, retry_after_seconds} ->
        {:error, {:retry_after, retry_after_seconds}}

      :error ->
        error_body = if body == "", do: {:http_error, status}, else: body
        {:error, error_body}
    end
  end

  defp extract_retry_after(headers) do
    case Map.get(headers, "retry-after") do
      [value | _] when is_binary(value) ->
        parse_retry_after(value)

      _ ->
        :error
    end
  end

  @doc false
  def parse_retry_after(value) do
    value = String.trim(value)

    parse_integer_seconds(value) ||
      parse_iso8601_datetime(value) ||
      parse_http_date(value) ||
      :error
  end

  defp parse_integer_seconds(value) do
    case Integer.parse(value) do
      {seconds, ""} when seconds >= 0 -> {:ok, seconds}
      _ -> nil
    end
  end

  defp parse_iso8601_datetime(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> calculate_seconds_from_now(datetime)
      _ -> nil
    end
  end

  defp parse_http_date(value) do
    case :httpd_util.convert_request_date(String.to_charlist(value)) do
      {{year, month, day}, {hour, minute, second}} ->
        with {:ok, date} <- Date.new(year, month, day),
             {:ok, time} <- Time.new(hour, minute, second),
             {:ok, datetime} <- DateTime.new(date, time, "Etc/UTC") do
          calculate_seconds_from_now(datetime)
        else
          _ -> nil
        end

      _ ->
        nil
    end
  rescue
    FunctionClauseError -> nil
  end

  defp calculate_seconds_from_now(datetime) do
    seconds = max(DateTime.diff(datetime, DateTime.utc_now()), 0)
    {:ok, seconds}
  end

  defp sign_request(url, body, key, nonce) do
    headers = %{"nonce" => nonce, "url" => url}
    sign(key, body, headers)
  end

  defp sign(key, body, header) when is_map(body) do
    sign(key, Jason.encode!(body), header)
  end

  defp sign(%ExAcme.AccountKey{} = key, body, header) do
    ExAcme.AccountKey.sign(key, body, header)
  end

  defp sign(%JOSE.JWK{} = key, body, header) do
    jwk = key |> JOSE.JWK.to_public_map() |> elem(1)
    algorithm = Map.fetch!(jwk, "alg")
    header = Map.merge(header, %{"alg" => algorithm, "jwk" => jwk})
    body |> JOSE.JWK.sign(header, key) |> elem(1)
  end
end
