defmodule ExAcme.OrderBuilderTest do
  @moduledoc false
  use ExUnit.Case

  describe "to_map/1" do
    test "returns error for empty identifiers" do
      order = ExAcme.OrderBuilder.new_order()

      assert {:error, :no_identifiers} = ExAcme.OrderBuilder.to_map(order)
    end

    test "returns ok with map for valid order with identifiers" do
      order = ExAcme.OrderBuilder.add_dns_identifier(ExAcme.OrderBuilder.new_order(), "example.com")

      assert {:ok, map} = ExAcme.OrderBuilder.to_map(order)
      assert map.identifiers == [%{type: "dns", value: "example.com"}]
    end

    test "removes nil values from the map" do
      order =
        ExAcme.OrderBuilder.new_order()
        |> ExAcme.OrderBuilder.add_dns_identifier("example.com")
        |> ExAcme.OrderBuilder.profile("default")

      assert {:ok, map} = ExAcme.OrderBuilder.to_map(order)
      assert Map.has_key?(map, :identifiers)
      assert Map.has_key?(map, :profile)
      refute Map.has_key?(map, :not_before)
      refute Map.has_key?(map, :not_after)
    end

    test "includes all non-nil values" do
      now = DateTime.utc_now()
      later = DateTime.add(now, 3600, :second)

      order =
        ExAcme.OrderBuilder.new_order()
        |> ExAcme.OrderBuilder.add_dns_identifier("example.com")
        |> ExAcme.OrderBuilder.profile("default")
        |> ExAcme.OrderBuilder.not_before(now)
        |> ExAcme.OrderBuilder.not_after(later)

      assert {:ok, map} = ExAcme.OrderBuilder.to_map(order)
      assert map.identifiers == [%{type: "dns", value: "example.com"}]
      assert map.profile == "default"
      assert map.not_before == now
      assert map.not_after == later
    end
  end
end
