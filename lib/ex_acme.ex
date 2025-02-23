defmodule ExAcme do
  @moduledoc """
  ExAcme is an ACME protocol client for managing SSL certificates.

  It provides functionalities to interact with the ACME server, including
  generating keys, sending ACME requests, and handling directory and nonce
  information.

  ## Features

    - Start and manage the ExAcme client agent.
    - Fetch directory information and terms of service.
    - Send signed ACME requests.
    - Handle nonce refreshing automatically.

  Use the client to interact with ACME endpoints.
  """

  use Agent

  @content_type "application/jose+json"

  @typedoc "Client process holding directory cache and state"
  @type client() :: Agent.agent()

  @doc ~S"""
  Starts the ExAcme client agent with the given options.

  ## Options

    - `:directory_url` - The URL of the ACME directory.
    - `:finch` - The module name or pid of the Finch HTTP client to use.
  """
  @spec start_link(Keyword.t()) :: client()
  def start_link(options) do
    options = Keyword.validate!(options, [:directory_url, :finch])
    directory_url = expand_directory(Keyword.fetch!(options, :directory_url))
    finch = Keyword.fetch!(options, :finch)

    with {:ok, directory} <- fetch_directory(directory_url, finch),
         {:ok, nonce} <- fetch_nonce(directory, finch) do
      Agent.start_link(
        fn -> Enum.into(options, %{directory: directory, nonce: nonce}) end,
        options
      )
    end
  end

  @doc ~S"""
  Retrieves the directory information from the client.

  ## Parameters

    - `client` - The pid or name of the ExAcme client agent.
  """
  @spec directory(Agent.agent()) :: map()
  def directory(client) do
    client
    |> Agent.get(& &1)
    |> Map.get(:directory)
  end

  @doc ~S"""
  Retrieves the terms of service URL from the ACME directory information.

  ## Parameters

    - `client` - The pid or name of the ExAcme client agent.
  """
  @spec terms_of_service(Agent.agent()) :: String.t()
  def terms_of_service(client) do
    client
    |> directory()
    |> get_in(["meta", "termsOfService"])
  end

  @doc """
  Retrieves the profiles from the ACME directory.

  ## Parameters

    - `client` - The pid or name of the ExAcme client agent.
  """
  @spec profiles(Agent.agent()) :: [map()]
  def profiles(client) do
    client
    |> directory()
    |> get_in(["meta", "profiles"])
  end

  @doc """
  Checks if an external account is required.

  ## Parameters

    - `client` - The pid or name of the ExAcme client agent.
  """
  @spec external_account_required?(Agent.agent()) :: boolean()
  def external_account_required?(client) do
    client
    |> directory()
    |> get_in(["meta", "externalAccountRequired"])
  end

  @doc """
  Sends an ACME request.

  ## Parameters

    - `acme_request` - The ACME request to send.
    - `account_key` - The account key for signing.
    - `client` - The ExAcme client agent.
  """
  @spec send_request(ExAcme.Request.t(), ExAcme.AccountKey.t(), Agent.agent()) :: {:ok, map()} | {:error, any()}
  def send_request(acme_request, account_key, client) do
    state = Agent.get(client, & &1)
    request = ExAcme.Request.to_request(acme_request, state)
    nonce = state.nonce
    message_headers = %{"nonce" => nonce, "url" => request.url}
    body = sign_body(account_key, request.body, message_headers)
    user_agent = "ExAcme/#{Application.spec(:ex_acme, :vsn)}"
    request_headers = [{"Content-Type", @content_type}, {"User-Agent", user_agent}]

    with {:ok, body} <- Jason.encode(body),
         request = Finch.build(:post, request.url, request_headers, body),
         {:ok, %Finch.Response{status: status, body: body, headers: headers}} <-
           Finch.request(request, state.finch) do
      refresh_nonce(client, headers)

      content_type =
        headers
        |> List.keyfind("content-type", 0, {"content-type", "text/plain"})
        |> elem(1)
        |> String.split("; ")
        |> List.first()

      body =
        case content_type do
          "application/json" -> Jason.decode!(body)
          "application/problem+json" -> Jason.decode!(body)
          _ -> body
        end

      case {status, body} do
        {400, %{"type" => "urn:ietf:params:acme:error:badNonce"}} ->
          ExAcme.send_request(acme_request, account_key, client)

        {status, body} when status >= 400 ->
          body =
            if body == "" do
              {:http_error, status}
            else
              body
            end

          {:error, body}

        {_, body} ->
          {:ok, %{body: body, headers: Map.new(headers)}}
      end
    end
  end

  defp fetch_directory(directory_url, finch) do
    with {:ok, %Finch.Response{body: body}} <-
           :get |> Finch.build(directory_url) |> Finch.request(finch) do
      Jason.decode(body)
    end
  end

  defp fetch_nonce(%{"newNonce" => nonce_url}, finch) do
    with {:ok, %Finch.Response{headers: headers}} <-
           :head |> Finch.build(nonce_url) |> Finch.request(finch) do
      nonce = headers |> List.keyfind("replay-nonce", 0) |> elem(1)
      {:ok, nonce}
    end
  end

  defp update_nonce(client, nonce) do
    Agent.update(client, fn state -> Map.put(state, :nonce, nonce) end)
  end

  defp refresh_nonce(client, headers) do
    state = Agent.get(client, & &1)

    new_nonce =
      case List.keyfind(headers, "replay-nonce", 0) do
        {_, nonce} ->
          nonce

        nil ->
          {:ok, nonce} = fetch_nonce(state.directory, state.finch)
          nonce
      end

    update_nonce(client, new_nonce)
  end

  defp sign_body(account_key, body, header) when is_nil(body) do
    sign_body(account_key, "", header)
  end

  defp sign_body(account_key, body, header) when is_map(body) do
    sign_body(account_key, Jason.encode!(body), header)
  end

  defp sign_body(account_key, body, header) do
    ExAcme.AccountKey.sign(account_key, body, header)
  end

  defp expand_directory(:lets_encrypt), do: "https://acme-v02.api.letsencrypt.org/directory"
  defp expand_directory(:lets_encrypt_staging), do: "https://acme-staging-v02.api.letsencrypt.org/directory"
  defp expand_directory(directory_url), do: directory_url
end
