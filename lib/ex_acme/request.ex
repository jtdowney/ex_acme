defprotocol ExAcme.Request do
  @doc false
  def to_request(object, directory)
end

defmodule ExAcme.SimpleRequest do
  @moduledoc false
  defstruct [:url, :body]
end

defimpl ExAcme.Request, for: ExAcme.SimpleRequest do
  @doc false
  def to_request(request, _directory), do: request
end
