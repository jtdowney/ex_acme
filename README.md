# ExAcme

ExAcme is a lightweight, developer-friendly Elixir library for interacting with [RFC 8555-compliant](https://tools.ietf.org/html/rfc8555) ACME servers like [Let’s Encrypt](https://letsencrypt.org). It simplifies the process of managing X.509 (TLS/SSL) certificates by providing a straightforward API for registering accounts, handling domain challenges, and issuing certificates.

## Features

- Designed with developer productivity and Elixir idioms in mind.
- Easy integration into your projects with minimal configuration.

## Missing

- Handling external account binding

## Installation

The package can be installed by adding `ex_acme` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_acme, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc) and published on [HexDocs](https://hexdocs.pm). The docs can be found at <https://hexdocs.pm/ex_acme>.

## Examples

### Starting the client

ExAcme needs a running Finch process to interact with the ACME server. You can add ExAcme and Finch to your supervision tree.

```elixir
children = [
  {Finch, name: MyFinch},
  {ExAcme, name: MyAcme, directory_url: :lets_encrypt_staging, finch: MyFinch}
]
```

### Registering an account

To register a new account with the ACME server, you need to generate an account key, create a registration, and agree to the terms of service.

```elixir
alias ExAcme.{AccountKey, Registration}

# Generate a new account key
account_key = AccountKey.generate()

# Create and configure the registration
registration =
  Registration.new()
  |> Registration.contacts(["mailto:admin@example.com"])
  |> Registration.agree_to_terms()

# Register the account
case Registration.register(registration, account_key, MyAcme) do
  {:ok, account} ->
    IO.puts("Account registered successfully!")
    IO.inspect(account)

  {:error, reason} ->
    IO.puts("Failed to register account:")
    IO.inspect(reason)
end
```

### Creating an order request

Once you have registered an account, you can create an order for a certificate by specifying the domain(s) you wish to obtain certificates for.

```elixir
alias ExAcme.OrderRequest

# Create a new order request
order_request =
  OrderRequest.new()
  |> OrderRequest.add_dns_identifier("example.com")
  |> OrderRequest.add_dns_identifier("www.example.com")

# Submit the order
case OrderRequest.submit(order_request, account_key, MyAcme) do
  {:ok, order} ->
    IO.puts("Order created successfully!")
    IO.inspect(order)

  {:error, reason} ->
    IO.puts("Failed to create order:")
    IO.inspect(reason)
end
```

### Fetching the challenges for the order

After creating an order, you need to complete the necessary challenges to prove ownership of the domain.

```elixir
alias ExAcme.{Authorization, Challenge}

for auth_url <- order.authorizations do
  {:ok, authorization} = Authorization.fetch(auth_url, account_key, MyAcme)
  challenge = Challenge.find_by_type(authorization, "dns-01")

  if challenge do
    value = Challenge.key_authorization(challenge.token, account_key)
    # Set up challenge (implementation depends on your setup)
    setup_challenge(authorization.identifier["value"], value)

    # Trigger validation
    {:ok, _validated_challenge} = Challenge.trigger_validation(challenge.url, account_key, MyAcme)

    # Optionally, wait and verify the challenge status
    :timer.sleep(5000)
    {:ok, validated_challenge} = Challenge.fetch(challenge.url, account_key, MyAcme)

    if validated_challenge.status == "valid" do
      IO.puts("Challenge for #{authorization.identifier["value"]} validated successfully.")
    else
      IO.puts("Challenge for #{authorization.identifier["value"]} failed.")
    end
  else
    IO.puts("No challenge found for #{authorization.identifier["value"]}.")
  end
end
```

### Finalizing the order with a Certificate Signing Request (CSR)

After all challenges are validated, you can finalize the order by submitting a CSR.

```elixir
alias ExAcme.{Order, Certificate}

# Create a private key for the certificate
private_key = X509.PrivateKey.new_ec(:secp256r1)

# Generate CSR from the order and private key
csr = Certificate.csr_from_order(order, private_key)

# Finalize the order by submitting the CSR
case Order.finalize(order.finalize_url, csr, account_key, MyAcme) do
  {:ok, finalized_order} ->
    IO.puts("Order finalized successfully!")
    IO.inspect(finalized_order)

  {:error, reason} ->
    IO.puts("Failed to finalize order:")
    IO.inspect(reason)
end
```

### Fetching the certificate

Once the order is finalized and the certificate is issued, you can fetch the certificate from the ACME server.

```elixir
alias ExAcme.Certificate

case Certificate.fetch(finalized_order.certificate_url, account_key, MyAcme) do
  {:ok, certificates} ->
    Enum.each(certificates, fn cert ->
      IO.puts("Fetched Certificate:")
      IO.puts(X509.Certificate.to_pem(cert))
    end)

  {:error, reason} ->
    IO.puts("Failed to fetch certificate:")
    IO.inspect(reason)
end
```

## License

This library is licensed under the [MIT License](https://opensource.org/licenses/MIT).
