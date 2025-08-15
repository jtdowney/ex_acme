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
    {:ok, pid} = ExAcme.start_link(directory_url: :lets_encrypt)
    %{directory_url: directory_url} = Agent.get(pid, & &1)
    assert directory_url == "https://acme-v02.api.letsencrypt.org/directory"
  end

  test "current_nonce basic functionality", %{client: client} do
    {:ok, nonce1} = ExAcme.current_nonce(client)
    assert is_binary(nonce1)
    assert String.length(nonce1) > 0

    {:ok, nonce2} = ExAcme.current_nonce(client)
    assert is_binary(nonce2)
    assert String.length(nonce2) > 0

    assert nonce1 != nonce2
  end

  test "nonce storage and retrieval", %{client: client} do
    Agent.update(client, &Map.put(&1, :nonce, "test-nonce-from-server"))

    {:ok, nonce} = ExAcme.current_nonce(client)
    assert nonce == "test-nonce-from-server"

    {:ok, new_nonce} = ExAcme.current_nonce(client)
    assert is_binary(new_nonce)
    assert new_nonce != "test-nonce-from-server"
  end

  test "multiple concurrent nonce requests", %{client: client} do
    tasks = for _i <- 1..5 do
      Task.async(fn ->
        case ExAcme.current_nonce(client) do
          {:ok, nonce} when is_binary(nonce) -> :ok
          error -> error
        end
      end)
    end

    results = Task.await_many(tasks, 5000)

    assert Enum.all?(results, &(&1 == :ok))
  end
end
