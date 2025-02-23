defmodule ExAcme.Utils do
  @moduledoc false
  @spec to_camel_case(map() | atom() | String.t()) :: map() | atom() | String.t()
  def to_camel_case(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      {
        to_camel_case(key),
        value
      }
    end)
  end

  def to_camel_case(key) when is_atom(key) do
    key
    |> Atom.to_string()
    |> to_camel_case()
    |> String.to_atom()
  end

  def to_camel_case(key) when is_binary(key) do
    key
    |> String.split("_")
    |> Enum.with_index()
    |> Enum.map_join(fn
      {word, 0} -> String.downcase(word)
      {word, _} -> String.capitalize(word)
    end)
  end

  @spec datetime_from_rfc3339(String.t() | nil) :: DateTime.t() | nil
  def datetime_from_rfc3339(nil), do: nil

  def datetime_from_rfc3339(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} ->
        datetime

      {:error, reason} ->
        raise ArgumentError, "Invalid RFC3339 string: #{reason}"
    end
  end
end
