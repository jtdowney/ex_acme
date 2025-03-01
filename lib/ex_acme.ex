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
  Generates a cryptographic key pair for use with ACME operations.

  This function creates a new key pair for signing ACME requests. The default
  algorithm is ES256 (ECDSA using P-256 and SHA-256), which is widely supported
  by ACME providers.

  ## Parameters

    - `algorithm` - The algorithm to use for key generation. Default is "ES256".

  ## Returns

    - `JOSE.JWK` struct representing the generated key pair.
  """
  def generate_key(algorithm \\ "ES256") do
    JOSE.JWS.generate_key(%{"alg" => algorithm})
  end

  @doc ~S"""
  Starts the ExAcme client agent with the given options.

  ## Options

    - `:directory_url` - The URL of the ACME directory. The value can be
      `:lets_encrypt` or `:lets_encrypt_staging` to use the Let's Encrypt
      production or staging directory URL or a custom directory URL.
    - `:finch` - The module name or pid of the Finch HTTP client to use.
    - Other options to pass to `Agent` like `:name`.
  """
  @spec start_link(Keyword.t()) :: client()
  def start_link(options) do
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
  Fetches account information from the specified URL.

  ## Parameters

    - `url` - The URL of the account to fetch.
    - `account_key` - The account key used for authentication.
    - `client` - The pid or name of the ExAcme client agent.

  ## Returns

    - `{:ok, account}` - If the account is successfully fetched.
    - `{:error, reason}` - If an error occurs during the fetch operation.
  """
  @spec fetch_account(String.t(), ExAcme.AccountKey.t(), Agent.agent()) :: {:ok, ExAcme.Account.t()} | {:error, any()}
  def fetch_account(url, account_key, client) do
    fetch_object(url, account_key, client, &ExAcme.Account.from_response/2)
  end

  @doc """
  Fetches order authorization information from the specified URL.

  ## Parameters

    - `url` - The URL of the authorization to fetch.
    - `account_key` - The account key used for authentication.
    - `client` - The pid or name of the ExAcme client agent.

  ## Returns

    - `{:ok, authorization}` - If the authorization is successfully fetched.
    - `{:error, reason}` - If an error occurs during the fetch operation.
  """
  @spec fetch_authorization(String.t(), ExAcme.AccountKey.t(), Agent.agent()) ::
          {:ok, ExAcme.Authorization.t()} | {:error, any()}
  def fetch_authorization(url, account_key, client) do
    fetch_object(url, account_key, client, &ExAcme.Authorization.from_response/2)
  end

  @doc """
  Fetches certificate chain from the specified URL.

  ## Parameters

    - `url` - The URL of the certificate to fetch.
    - `account_key` - The account key used for authentication.
    - `client` - The pid or name of the ExAcme client agent.

  ## Returns

    - `{:ok, certificate_chain}` - If the certificate chain is successfully fetched.
    - `{:error, reason}` - If an error occurs during the fetch operation.
  """
  @spec fetch_certificates(String.t(), ExAcme.AccountKey.t(), Agent.agent()) ::
          {:ok, [X509.Certificate.t()]} | {:error, any()}
  def fetch_certificates(url, account_key, client) do
    request = ExAcme.Request.build_fetch(url)

    with {:ok, response} <- send_request(request, account_key, client) do
      {:ok, X509.from_pem(response.body)}
    end
  end

  @doc """
  Fetches authorization challenge information from the specified URL.

  ## Parameters

    - `url` - The URL of the challenge to fetch.
    - `account_key` - The account key used for authentication.
    - `client` - The pid or name of the ExAcme client agent.

  ## Returns

    - `{:ok, challenge}` - If the challenge is successfully fetched.
    - `{:error, reason}` - If an error occurs during the fetch operation.
  """
  @spec fetch_challenge(String.t(), ExAcme.AccountKey.t(), Agent.agent()) ::
          {:ok, ExAcme.Challenge.t()} | {:error, any()}
  def fetch_challenge(url, account_key, client) do
    fetch_object(url, account_key, client, &ExAcme.Challenge.from_response/2)
  end

  @doc """
  Fetches order information from the specified URL.

  ## Parameters

    - `url` - The URL of the order to fetch.
    - `account_key` - The account key used for authentication.
    - `client` - The pid or name of the ExAcme client agent.

  ## Returns

    - `{:ok, order}` - If the order is successfully fetched.
    - `{:error, reason}` - If an error occurs during the fetch operation.
  """
  @spec fetch_order(String.t(), ExAcme.AccountKey.t(), Agent.agent()) ::
          {:ok, ExAcme.Order.t()} | {:error, any()}
  def fetch_order(url, account_key, client) do
    fetch_object(url, account_key, client, &ExAcme.Order.from_response/2)
  end

  @doc """
  Finalizes an order by sending a Certificate Signing Request (CSR) to the specified URL.

  ## Parameters

    - `finalize_url` - The URL to finalize the order.
    - `csr` - The Certificate Signing Request (CSR) to send for finalization. You can generate a
       CSR using the `ExAcme.Order.to_csr/2` function.
    - `account_key` - The account key used for authentication.
    - `client` - The pid or name of the ExAcme client agent.

  ## Returns

    - `{:ok, order}` - If the order is successfully finalized.
    - `{:error, reason}` - If an error occurs during the finalization process.
  """
  @spec finalize_order(String.t(), X509.CSR.t(), ExAcme.AccountKey.t(), Agent.agent()) ::
          {:ok, ExAcme.Order.t()} | {:error, any()}
  def finalize_order(finalize_url, csr, account_key, client) do
    csr = csr |> X509.CSR.to_der() |> Base.url_encode64(padding: false)
    request = ExAcme.Request.build_update(finalize_url, %{csr: csr})

    with {:ok, response} <- send_request(request, account_key, client) do
      {:ok, ExAcme.Order.from_response(finalize_url, response.body)}
    end
  end

  @doc """
  Registers a new account with the ACME server.

  This function creates a new account on the ACME server using the provided registration information
  and JSON Web Key (JWK).

  ## Parameters

    - `registration_builder` - A `ExAcme.RegistrationBuilder` struct containing registration information
      or a map with details from section 7.3 of RFC 8555.
    - `key` - The JSON Web Key (JWK) to use for the account.
    - `client` - The pid or name of the ExAcme client agent.

  ## Returns

    - `{:ok, account, account_key}` - If the registration is successful, returns the account
      information and the corresponding account key. An account key is the provided JSON Web Key
      (JWK) and the Key Identifier (kid) returned by the server.
    - `{:error, reason}` - If an error occurs during registration.
  """
  @spec register_account(ExAcme.RegistrationBuilder.t() | map(), JOSE.JWK.t(), Agent.agent(), keyword()) ::
          {:ok, ExAcme.Account.t(), ExAcme.AccountKey.t()} | {:error, any()}
  def register_account(registration_builder, key, client, opts \\ [])

  def register_account(%ExAcme.RegistrationBuilder{} = registration_builder, key, client, opts) do
    registration_builder
    |> ExAcme.RegistrationBuilder.to_map()
    |> register_account(key, client, opts)
  end

  def register_account(registration, key, client, opts) do
    body =
      registration
      |> ExAcme.Utils.to_camel_case()
      |> Map.put("onlyReturnExisting", Keyword.get(opts, :only_return_existing, false))

    request = ExAcme.Request.build_named("newAccount", body, client)

    with {:ok, %{body: body, headers: headers}} <-
           send_request(request, key, client) do
      location = Map.get(headers, "location")
      %{url: kid} = account = ExAcme.Account.from_response(location, body)
      account_key = ExAcme.AccountKey.new(key, kid)
      {:ok, account, account_key}
    end
  end

  @doc """
  Rotates the account key for an ACME account.

  This function replaces the current account key with a new one. The server will authorize the key
  change based on a request signed by both the old and new keys.

  ## Parameters

    - `old_account_key` - The current account key to be replaced.
    - `new_key` - The new JSON Web Key (JWK) to use for the account.
    - `client` - The pid or name of the ExAcme client agent.

  ## Returns

    - `{:ok, account_key}` - If the key rotation is successful, returns the new account key, which
       is the provided JSON Web Key (JWK) and the Key ID (kid).
    - `{:error, reason}` - If an error occurs during key rotation.
  """
  @spec rotate_account_key(ExAcme.AccountKey.t(), JOSE.JWK.t(), client()) ::
          {:ok, ExAcme.AccountKey.t()} | {:error, any()}
  def rotate_account_key(%ExAcme.AccountKey{kid: kid} = old_account_key, new_key, client) do
    url = ExAcme.Request.lookup_named_url("keyChange", client)
    algorithm = new_key |> JOSE.JWK.to_map() |> elem(1) |> Map.fetch!("alg")
    inner_payload = %{account: kid, oldKey: ExAcme.AccountKey.to_public(old_account_key)}
    inner_headers_jwk = new_key |> JOSE.JWK.to_public_map() |> elem(1)
    inner_headers = %{"url" => url, "alg" => algorithm, "jwk" => inner_headers_jwk}

    with {:ok, inner_payload} <- Jason.encode(inner_payload),
         outer_payload = inner_payload |> JOSE.JWK.sign(inner_headers, new_key) |> elem(1),
         request = ExAcme.Request.build_update(url, outer_payload),
         {:ok, _response} <- send_request(request, old_account_key, client) do
      new_account_key = ExAcme.AccountKey.new(new_key, kid)
      {:ok, new_account_key}
    end
  end

  @doc """
  Starts the validation process for a challenge by sending a request to the specified challenge URL.

  This function notifies the ACME server that the client is ready for the server to attempt validation
  of the challenge. The server will then verify that the requirements of the challenge have been
  fulfilled.

  ## Parameters

    - `url` - The URL of the challenge to validate.
    - `account_key` - The account key used for authentication.
    - `client` - The pid or name of the ExAcme client agent.

  ## Returns

    - `{:ok, challenge}` - If the challenge validation request is successfully sent, returns the
      updated challenge information.
    - `{:error, reason}` - If an error occurs during the validation request.
  """
  @spec start_challenge_validation(String.t(), ExAcme.AccountKey.t(), client()) ::
          {:ok, ExAcme.Challenge.t()} | {:error, any()}
  def start_challenge_validation(url, account_key, client) do
    request = ExAcme.Request.build_update(url, %{})

    with {:ok, %{body: body}} <- send_request(request, account_key, client) do
      {:ok, ExAcme.Challenge.from_response(url, body)}
    end
  end

  @doc """
  Submits a new order to the ACME server.

  This function creates a new certificate order using the provided order information.
  It can accept either an `ExAcme.OrderBuilder` struct or a map with order details from section 7.4
  of RFC 8555.

  ## Parameters

    - `order_builder` - An `ExAcme.OrderBuilder` struct or a map containing order details such as
      identifiers, not_before, and not_after.
    - `account_key` - The account key used for authentication.
    - `client` - The pid or name of the ExAcme client agent.

  ## Returns

    - `{:ok, order}` - If the order submission is successful, returns the order information.
    - `{:error, reason}` - If an error occurs during order submission.
  """
  @spec submit_order(ExAcme.OrderBuilder.t() | map(), ExAcme.AccountKey.t(), client()) ::
          {:ok, ExAcme.Order.t()} | {:error, any()}
  def submit_order(%ExAcme.OrderBuilder{} = order_builder, account_key, client) do
    order_builder
    |> ExAcme.OrderBuilder.to_map()
    |> submit_order(account_key, client)
  end

  def submit_order(order, account_key, client) do
    body = ExAcme.Utils.to_camel_case(order)
    request = ExAcme.Request.build_named("newOrder", body, client)

    with {:ok, %{body: body, headers: headers}} <-
           send_request(request, account_key, client) do
      location = Map.get(headers, "location")
      order = ExAcme.Order.from_response(location, body)
      {:ok, order}
    end
  end

  defp decode_body(body, headers) do
    content_type =
      headers
      |> List.keyfind("content-type", 0, {"content-type", "text/plain"})
      |> elem(1)
      |> String.split("; ")
      |> List.first()

    case content_type do
      "application/json" -> Jason.decode!(body)
      "application/problem+json" -> Jason.decode!(body)
      _ -> body
    end
  end

  defp fetch_object(url, account_key, client, object_builder) do
    request = ExAcme.Request.build_fetch(url)

    with {:ok, response} <- send_request(request, account_key, client) do
      {:ok, object_builder.(url, response.body)}
    end
  end

  defp send_request(request, key, client) do
    %{finch: finch} = Agent.get(client, & &1)
    body = sign_request(request.url, request.body, key, client)
    user_agent = "ExAcme/#{Application.spec(:ex_acme, :vsn)}"
    headers = [{"Content-Type", @content_type}, {"User-Agent", user_agent}]

    with {:ok, body} <- Jason.encode(body),
         finch_request = Finch.build(:post, request.url, headers, body),
         {:ok, %Finch.Response{status: status, body: body, headers: headers}} <-
           Finch.request(finch_request, finch) do
      refresh_nonce(client, headers)
      body = decode_body(body, headers)

      case {status, body} do
        {400, %{"type" => "urn:ietf:params:acme:error:badNonce"}} ->
          send_request(request, key, client)

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

  defp sign_request(url, body, key, client) do
    %{nonce: nonce} = Agent.get(client, & &1)
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
    algorithm = jwk |> JOSE.JWK.to_map() |> elem(1) |> Map.fetch!("alg")
    header = Map.merge(header, %{"alg" => algorithm, "jwk" => jwk})
    body |> JOSE.JWK.sign(header, key) |> elem(1)
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

  defp expand_directory(:lets_encrypt), do: "https://acme-v02.api.letsencrypt.org/directory"
  defp expand_directory(:lets_encrypt_staging), do: "https://acme-staging-v02.api.letsencrypt.org/directory"
  defp expand_directory(directory_url), do: directory_url
end
