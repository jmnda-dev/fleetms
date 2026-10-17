defmodule Fleetms.FuelManagement.FuelReceiptTest do
  @moduledoc "Fuel entries persist their receipt image keys."
  use Fleetms.DataCase, async: true

  import Fleetms.FuelFixtures

  alias Fleetms.FuelManagement

  setup :shared_org

  test "receipt keys are stored on create and can be cleared/updated", %{scope: scope} do
    entry =
      fuel_entry_fixture(scope, %{
        receipt_image_key: "fuel/receipts/abc.jpg",
        receipt_thumbnail_key: "fuel/receipts/abc_thumb.jpg"
      })

    assert entry.receipt_image_key == "fuel/receipts/abc.jpg"
    assert entry.receipt_thumbnail_key == "fuel/receipts/abc_thumb.jpg"

    {:ok, updated} =
      FuelManagement.update_fuel_entry(
        entry,
        %{
          receipt_image_key: "fuel/receipts/new.jpg",
          receipt_thumbnail_key: "fuel/receipts/new_thumb.jpg"
        },
        scope: scope
      )

    assert updated.receipt_image_key == "fuel/receipts/new.jpg"
  end
end
