defmodule Fleetms.Inspections.InspectionTest do
  use Fleetms.DataCase

  import Fleetms.VehicleFixtures

  alias Fleetms.Inspections

  setup :shared_org

  # A published version with three graded item types.
  defp published_version(scope) do
    schema = %{
      "sections" => [
        %{
          "id" => "s1",
          "title" => "Checks",
          "items" => [
            %{"id" => "brakes", "label" => "Brakes", "config" => %{"type" => "pass_fail"}},
            %{
              "id" => "psi",
              "label" => "Tyre pressure",
              "config" => %{"type" => "number", "pass_min" => 30, "pass_max" => 35}
            },
            %{
              "id" => "odo",
              "label" => "Odometer",
              "config" => %{"type" => "meter", "must_increase" => true}
            }
          ]
        }
      ]
    }

    form =
      %{title: "DVIR #{System.unique_integer([:positive])}"}
      |> Inspections.create_inspection_form!(scope: scope)
      |> Inspections.update_inspection_form!(%{draft_schema: schema}, scope: scope)
      |> Inspections.publish_inspection_form!(scope: scope)

    [version] = Inspections.get_inspection_form!(form.id, scope: scope).versions
    {form, version}
  end

  test "submitting grades the answers, sets the result and materializes failures", %{
    scope: scope,
    owner: owner
  } do
    {form, version} = published_version(scope)
    vehicle = vehicle_fixture(scope, %{mileage: Decimal.new("5000")})

    answers = [
      %{"item_id" => "brakes", "value" => "fail"},
      %{"item_id" => "psi", "value" => "32"},
      %{"item_id" => "odo", "value" => "4000"}
    ]

    inspection =
      Inspections.submit_inspection!(
        %{
          vehicle_id: vehicle.id,
          inspection_form_version_id: version.id,
          answers: answers
        },
        scope: scope
      )

    assert inspection.status == :submitted
    assert inspection.result == :failed
    assert inspection.submitted_at
    assert inspection.submitted_by_id == owner.id
    assert inspection.inspection_form_version_id == version.id
    # denormalized from the version
    assert inspection.inspection_form_id == form.id

    # per-item statuses: brakes fails, psi passes, odo fails (4000 < 5000)
    by_item = Map.new(inspection.answers, &{&1.item_id, &1.status})
    assert by_item == %{"brakes" => :fail, "psi" => :pass, "odo" => :fail}

    # two failure rows, snapshotting the item labels
    loaded = Inspections.get_inspection!(inspection.id, scope: scope)
    assert loaded.failure_count == 2
    labels = Enum.map(loaded.failures, & &1.item_label) |> Enum.sort()
    assert labels == ["Brakes", "Odometer"]
  end

  test "photo evidence on an answer is stored with the inspection", %{scope: scope} do
    schema = %{
      "sections" => [
        %{
          "id" => "s1",
          "title" => "Evidence",
          "items" => [
            %{"id" => "damage", "label" => "Damage photos", "config" => %{"type" => "photo"}}
          ]
        }
      ]
    }

    version =
      %{title: "Photo DVIR #{System.unique_integer([:positive])}"}
      |> Inspections.create_inspection_form!(scope: scope)
      |> Inspections.update_inspection_form!(%{draft_schema: schema}, scope: scope)
      |> Inspections.publish_inspection_form!(scope: scope)
      |> then(&hd(Inspections.get_inspection_form!(&1.id, scope: scope).versions))

    vehicle = vehicle_fixture(scope)

    inspection =
      Inspections.submit_inspection!(
        %{
          vehicle_id: vehicle.id,
          inspection_form_version_id: version.id,
          answers: [
            %{
              "item_id" => "damage",
              "photos" => [
                %{
                  "image_key" => "inspections/answers/a.jpg",
                  "thumbnail_key" => "inspections/answers/a_thumb.jpg"
                }
              ]
            }
          ]
        },
        scope: scope
      )

    answer = Enum.find(inspection.answers, &(&1.item_id == "damage"))
    assert [photo] = answer.photos
    assert photo.image_key == "inspections/answers/a.jpg"
    assert photo.thumbnail_key == "inspections/answers/a_thumb.jpg"
  end

  test "a clean submission passes with no failures", %{scope: scope} do
    {_form, version} = published_version(scope)
    vehicle = vehicle_fixture(scope, %{mileage: Decimal.new("5000")})

    answers = [
      %{"item_id" => "brakes", "value" => "pass"},
      %{"item_id" => "psi", "value" => "33"},
      %{"item_id" => "odo", "value" => "5200"}
    ]

    inspection =
      Inspections.submit_inspection!(
        %{vehicle_id: vehicle.id, inspection_form_version_id: version.id, answers: answers},
        scope: scope
      )

    assert inspection.result == :passed
    assert Inspections.get_inspection!(inspection.id, scope: scope).failure_count == 0
  end

  test "inspections can be listed and filtered by vehicle", %{scope: scope} do
    {_form, version} = published_version(scope)
    v1 = vehicle_fixture(scope, %{name: "Rig One", mileage: Decimal.new("100")})
    v2 = vehicle_fixture(scope, %{name: "Rig Two", mileage: Decimal.new("100")})

    for v <- [v1, v2] do
      Inspections.submit_inspection!(
        %{
          vehicle_id: v.id,
          inspection_form_version_id: version.id,
          answers: [%{"item_id" => "brakes", "value" => "pass"}]
        },
        scope: scope
      )
    end

    all = Inspections.list_inspections!(%{}, scope: scope)
    assert length(all.results) == 2

    just_v1 = Inspections.list_inspections!(%{vehicle_id: v1.id}, scope: scope)
    assert [%{vehicle_id: id}] = just_v1.results
    assert id == v1.id
  end

  describe "soft delete (Option B)" do
    test "archiving an inspection hides it from the list but keeps it resolvable", %{scope: scope} do
      {_form, version} = published_version(scope)
      vehicle = vehicle_fixture(scope)

      inspection =
        Inspections.submit_inspection!(
          %{
            vehicle_id: vehicle.id,
            inspection_form_version_id: version.id,
            answers: [%{"item_id" => "brakes", "value" => "pass"}]
          },
          scope: scope
        )

      assert :ok = Inspections.delete_inspection(inspection, scope: scope)

      # hidden from the browse list
      refute Enum.any?(
               Inspections.list_inspections!(%{}, scope: scope).results,
               &(&1.id == inspection.id)
             )

      # still resolvable by id (an audit record reached from an issue it opened)
      assert {:ok, got} = Inspections.get_inspection(inspection.id, scope: scope)
      assert got.id == inspection.id

      # still resolvable via the primary :read that relationship loads use
      ids =
        Fleetms.Inspections.Inspection
        |> Ash.read!(tenant: scope.organization, authorize?: false)
        |> Enum.map(& &1.id)

      assert inspection.id in ids
    end

    test "an archived inspection shows in the archived list and can be restored", %{scope: scope} do
      {_form, version} = published_version(scope)
      vehicle = vehicle_fixture(scope)

      inspection =
        Inspections.submit_inspection!(
          %{
            vehicle_id: vehicle.id,
            inspection_form_version_id: version.id,
            answers: [%{"item_id" => "brakes", "value" => "pass"}]
          },
          scope: scope
        )

      assert :ok = Inspections.delete_inspection(inspection, scope: scope)

      archived_ids =
        Inspections.list_archived_inspections!(%{}, scope: scope).results |> Enum.map(& &1.id)

      assert inspection.id in archived_ids

      assert {:ok, restored} = Inspections.restore_inspection(inspection, %{}, scope: scope)
      assert is_nil(restored.archived_at)

      assert Enum.any?(
               Inspections.list_inspections!(%{}, scope: scope).results,
               &(&1.id == inspection.id)
             )
    end
  end
end
