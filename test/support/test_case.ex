defmodule ExAcme.TestCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      defp directory_url, do: System.get_env("ACME_DIRECTORY_URL") || raise("ACME_DIRECTORY_URL not set")

      setup_all do
        client =
          start_supervised!({
            ExAcme,
            directory_url: directory_url()
          })

        %{client: client}
      end
    end
  end
end
