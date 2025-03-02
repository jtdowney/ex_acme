defmodule ExAcmeTest do
  @moduledoc false
  use ExAcme.TestCase, async: true

  test "directory", %{client: client} do
    directory = ExAcme.directory(client)

    assert directory["newNonce"] == "https://pebble:14000/nonce-plz"
  end

  test "terms_of_service", %{client: client} do
    terms_of_service = ExAcme.terms_of_service(client)

    assert terms_of_service == "data:text/plain,Do%20what%20thou%20wilt"
  end

  test "profiles", %{client: client} do
    profiles = ExAcme.profiles(client)

    assert profiles == %{
             "default" => "The profile you know and love",
             "shortlived" => "A short-lived cert profile, without actual enforcement"
           }
  end

  test "external_account_required?", %{client: client} do
    external_account_required = ExAcme.external_account_required?(client)

    assert external_account_required == false
  end

  test "named directory lets_encrypt" do
    {:ok, pid} = ExAcme.start_link(finch: MyFinch, directory_url: :lets_encrypt)
    %{directory_url: directory_url} = Agent.get(pid, & &1)
    assert directory_url == "https://acme-v02.api.letsencrypt.org/directory"
  end

  test "named directory lets_encrypt_staging" do
    {:ok, pid} = ExAcme.start_link(finch: MyFinch, directory_url: :lets_encrypt_staging)
    %{directory_url: directory_url} = Agent.get(pid, & &1)
    assert directory_url == "https://acme-staging-v02.api.letsencrypt.org/directory"
  end

  test "named directory zerossl" do
    {:ok, pid} = ExAcme.start_link(finch: MyFinch, directory_url: :zerossl)
    %{directory_url: directory_url} = Agent.get(pid, & &1)
    assert directory_url == "https://acme.zerossl.com/v2/DV90"
  end
end
