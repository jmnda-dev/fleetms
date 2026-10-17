defmodule Fleetms.Inventory.LowStockDigestTest do
  @moduledoc "The daily low-stock digest emails owners about low / out-of-stock parts."
  use Fleetms.DataCase, async: false

  import Swoosh.TestAssertions
  import Fleetms.InventoryFixtures

  alias Fleetms.Inventory.LowStockDigest

  setup :shared_org

  test "emails the owner when a tracked part is at or below its threshold", %{
    scope: scope,
    org: org
  } do
    location = inventory_location_fixture(scope)

    low =
      part_fixture(scope, %{
        name: "Brake Pads",
        track_inventory: true,
        quantity_threshold: Decimal.new(10)
      })

    part_stock_fixture(scope, low, location, Decimal.new(3))

    healthy =
      part_fixture(scope, %{
        name: "Air Filter",
        track_inventory: true,
        quantity_threshold: Decimal.new(2)
      })

    part_stock_fixture(scope, healthy, location, Decimal.new(50))

    assert {:ok, count} = LowStockDigest.deliver_for_tenant("org_#{org.id}")
    assert count >= 1

    assert_email_sent(fn email ->
      email.html_body =~ "Brake Pads" and not (email.html_body =~ "Air Filter")
    end)
  end

  test "sends nothing when all stock is healthy", %{scope: scope, org: org} do
    location = inventory_location_fixture(scope)

    part =
      part_fixture(scope, %{track_inventory: true, quantity_threshold: Decimal.new(1)})

    part_stock_fixture(scope, part, location, Decimal.new(100))

    assert {:ok, 0} = LowStockDigest.deliver_for_tenant("org_#{org.id}")
  end
end
