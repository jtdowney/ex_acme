defmodule ExAcme.TestHelpers do
  @moduledoc false
  use AssertEventually

  def create_account(key, client) do
    {:ok, account, account_key} =
      ExAcme.register_account(
        %{
          contacts: ["mailto:#{Faker.Internet.email()}"],
          terms_of_service_agreed: true
        },
        key,
        client
      )

    {account_key, account}
  end

  def create_order(account_key, client) do
    ExAcme.OrderBuilder.new_order()
    |> ExAcme.OrderBuilder.add_dns_identifier(Faker.Internet.domain_name())
    |> ExAcme.submit_order(account_key, client)
  end

  def validate_order(order, account_key, client) do
    for url <- order.authorizations do
      {:ok, authorization} = ExAcme.fetch_authorization(url, account_key, client)
      validate_authorization(authorization, account_key, client)
    end

    eventually {:ok, %{status: "ready"}} =
                 ExAcme.fetch_order(order.url, account_key, client)
  end

  def validate_authorization(authorization, account_key, client) do
    challenge = ExAcme.Challenge.find_by_type(authorization, "dns-01")
    %{"type" => "dns", "value" => domain_name} = authorization.identifier
    ExAcme.TestHelpers.set_dns_challenge(domain_name, challenge.token, account_key, client)
    ExAcme.start_challenge_validation(challenge.url, account_key, client)

    eventually {:ok, %{status: "valid"}} =
                 ExAcme.fetch_challenge(challenge.url, account_key, client)

    ExAcme.TestHelpers.clear_dns_challenge(domain_name, client)
  end

  def set_dns_challenge(domain, token, account_key, client) do
    %{finch: finch} = Agent.get(client, & &1)

    url =
      challenge_test_server_url()
      |> URI.parse()
      |> URI.append_path("/set-txt")

    value =
      :sha256 |> :crypto.hash(ExAcme.Challenge.key_authorization(token, account_key)) |> Base.url_encode64(padding: false)

    body = Jason.encode!(%{host: "_acme-challenge.#{domain}.", value: value})
    headers = [{"Content-Type", "application/json"}]

    :post
    |> Finch.build(url, headers, body)
    |> Finch.request(finch)
  end

  def clear_dns_challenge(domain, client) do
    %{finch: finch} = Agent.get(client, & &1)

    url =
      challenge_test_server_url()
      |> URI.parse()
      |> URI.append_path("/clear-txt")

    body = Jason.encode!(%{host: "_acme-challenge.#{domain}."})
    headers = [{"Content-Type", "application/json"}]

    :post
    |> Finch.build(url, headers, body)
    |> Finch.request(finch)
  end

  defp challenge_test_server_url, do: System.get_env("CHALLTESTSRV_URL") || raise("CHALLTESTSRV_URL not set")
end
