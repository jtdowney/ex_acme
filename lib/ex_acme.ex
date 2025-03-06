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

  @named_directory_urls %{
    lets_encrypt: "https://acme-v02.api.letsencrypt.org/directory",
    lets_encrypt_staging: "https://acme-staging-v02.api.letsencrypt.org/directory",
    zerossl: "https://acme.zerossl.com/v2/DV90"
  }

  @typedoc "Client process holding directory cache and state"

  @type client() :: client()

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
      production or staging directory URL, `:zerossl` to use ZeroSSL
      directory URL, or a custom directory URL.
    - Other options to pass to `Agent` like `:name`.
  """
  @spec start_link(Keyword.t()) :: client()
  def start_link(options) do
    options = Keyword.update!(options, :directory_url, &expand_directory/1)
    directory_url = Keyword.fetch!(options, :directory_url)

    with {:ok, %{body: directory}} <- Req.get(directory_url) do
      Agent.start_link(
        fn -> Enum.into(options, %{directory: directory}) end,
        options
      )
    end
  end

  @doc ~S"""
  Refreshes and returns the current ACME nonce.

  This function retrieves the current nonce from the client's state. If no nonce
  is available, it automatically fetches a new one from the ACME server.

  The nonce is a unique value provided by the ACME server that must be included
  in each request to prevent replay attacks.

  ## Parameters

    - `client` - The pid or name of the ExAcme client agent.

  ## Returns

    - `{:ok, nonce}` - The current nonce value.
    - `{:error, reason}` - If an error occurs during nonce retrieval.
  """
  @spec current_nonce(client()) :: {:ok, String.t()} | {:error, term()}
  def current_nonce(client) do
    Agent.get_and_update(client, fn state ->
      case Map.pop(state, :nonce) do
        {nil, state} ->
          result = fetch_nonce(state)
          {result, state}

        {nonce, state} ->
          {{:ok, nonce}, state}
      end
    end)
  end

  @doc ~S"""
  Retrieves the directory information from the client.

  ## Parameters

    - `client` - The pid or name of the ExAcme client agent.
  """
  @spec directory(client()) :: map()
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
  @spec terms_of_service(client()) :: String.t()
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
  @spec profiles(client()) :: [map()]
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
  @spec external_account_required?(client()) :: boolean()
  def external_account_required?(client) do
    client
    |> directory()
    |> get_in(["meta", "externalAccountRequired"])
  end

  @doc """
  Deactivates an existing ACME account.

  This function sends a request to the ACME server to change the status of an account to 'deactivated'.
  Once an account is deactivated, it cannot be used for any further operations and the change is irreversible.

  ## Parameters

    - `account_key` - The account key used for authentication, containing the Key ID (kid).
    - `client` - The pid or name of the ExAcme client agent.

  ## Returns

    - `{:ok, account}` - If the account is successfully deactivated, returns the updated account information.
    - `{:error, reason}` - If an error occurs during the deactivation process.
  """
  @spec deactivate_account(ExAcme.AccountKey.t(), client()) :: {:ok, ExAcme.Account.t()} | {:error, any()}
  def deactivate_account(%ExAcme.AccountKey{kid: kid} = account_key, client) do
    request = ExAcme.Request.build_update(kid, %{status: "deactivated"})

    with {:ok, response} <- ExAcme.Request.send_request(request, account_key, client) do
      {:ok, ExAcme.Account.from_response(kid, response.body)}
    end
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
  @spec fetch_account(String.t(), ExAcme.AccountKey.t(), client()) :: {:ok, ExAcme.Account.t()} | {:error, any()}
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
  @spec fetch_authorization(String.t(), ExAcme.AccountKey.t(), client()) ::
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
  @spec fetch_certificates(String.t(), ExAcme.AccountKey.t(), client()) ::
          {:ok, [X509.Certificate.t()]} | {:error, any()}
  def fetch_certificates(url, account_key, client) do
    request = ExAcme.Request.build_fetch(url)

    with {:ok, %{body: body}} <- ExAcme.Request.send_request(request, account_key, client) do
      {:ok, X509.from_pem(body)}
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
  @spec fetch_challenge(String.t(), ExAcme.AccountKey.t(), client()) ::
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
  @spec fetch_order(String.t(), ExAcme.AccountKey.t(), client()) ::
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
  @spec finalize_order(String.t(), X509.CSR.t(), ExAcme.AccountKey.t(), client()) ::
          {:ok, ExAcme.Order.t()} | {:error, any()}
  def finalize_order(finalize_url, csr, account_key, client) do
    csr = csr |> X509.CSR.to_der() |> Base.url_encode64(padding: false)
    request = ExAcme.Request.build_update(finalize_url, %{csr: csr})

    with {:ok, %{body: body, headers: headers}} <- ExAcme.Request.send_request(request, account_key, client) do
      location = headers |> Map.get("location") |> List.first()
      {:ok, ExAcme.Order.from_response(location, body)}
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
  @spec register_account(ExAcme.RegistrationBuilder.t() | map(), JOSE.JWK.t(), client(), keyword()) ::
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
           ExAcme.Request.send_request(request, key, client) do
      location = headers |> Map.get("location") |> List.first()
      %{url: kid} = account = ExAcme.Account.from_response(location, body)
      account_key = ExAcme.AccountKey.new(key, kid)
      {:ok, account, account_key}
    end
  end

  @doc """
  Revokes a previously issued certificate.

  This function sends a request to the ACME server to revoke the specified certificate.
  Once a certificate is revoked, it is no longer valid and cannot be reinstated.

  ## Parameters

    - `revocation_builder` - An `ExAcme.RevocationBuilder` struct or a map containing revocation details
      such as the certificate data and optional reason code.
    - `account_key` - The account key used for authentication.
    - `client` - The pid or name of the ExAcme client agent.

  ## Returns

    - `:ok` - If the certificate is successfully revoked.
    - `{:error, reason}` - If an error occurs during the revocation process.
  """
  @spec revoke_certificate(ExAcme.RevocationBuilder.t() | map(), ExAcme.AccountKey.t(), ExAcme.client()) ::
          :ok | {:error, any()}
  def revoke_certificate(%ExAcme.RevocationBuilder{} = revocation_builder, account_key, client) do
    revocation_builder
    |> ExAcme.RevocationBuilder.to_map()
    |> revoke_certificate(account_key, client)
  end

  def revoke_certificate(%{certificate: cert_data} = body, account_key, client) do
    certificate = Base.url_encode64(cert_data, padding: false)

    body =
      body
      |> ExAcme.Utils.to_camel_case()
      |> Map.put(:certificate, certificate)

    request = ExAcme.Request.build_named("revokeCert", body, client)

    with {:ok, _} <- ExAcme.Request.send_request(request, account_key, client) do
      :ok
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
         {:ok, _response} <- ExAcme.Request.send_request(request, old_account_key, client) do
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

    with {:ok, %{body: body}} <- ExAcme.Request.send_request(request, account_key, client) do
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
           ExAcme.Request.send_request(request, account_key, client) do
      location = headers |> Map.get("location") |> List.first()
      order = ExAcme.Order.from_response(location, body)
      {:ok, order}
    end
  end

  defp fetch_object(url, account_key, client, object_builder) do
    request = ExAcme.Request.build_fetch(url)

    with {:ok, response} <- ExAcme.Request.send_request(request, account_key, client) do
      {:ok, object_builder.(url, response.body)}
    end
  end

  defp fetch_nonce(%{directory: %{"newNonce" => url}}) do
    with {:ok, %{headers: headers}} <- Req.head(url) do
      case Map.get(headers, "replay-nonce") do
        [nonce] -> {:ok, nonce}
        _ -> {:error, :unable_to_fetch_nonce}
      end
    end
  end

  defp expand_directory(directory_url) when is_atom(directory_url) do
    Map.fetch!(@named_directory_urls, directory_url)
  end

  defp expand_directory(directory_url), do: directory_url
end
