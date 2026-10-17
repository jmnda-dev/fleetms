defmodule Fleetms.Inspections.DueDigestTest do
  use Fleetms.DataCase, async: true

  import Fleetms.VehicleFixtures
  import Swoosh.TestAssertions

  alias Fleetms.Inspections
  alias Fleetms.Inspections.{DueDigest, InspectionAssignment}

  setup :shared_org

  defp tenant(org), do: Ash.ToTenant.to_tenant(org, InspectionAssignment)

  defp published_form(scope) do
    schema = %{
      "sections" => [
        %{
          "id" => "s1",
          "items" => [
            %{"id" => "brakes", "label" => "Brakes", "config" => %{"type" => "pass_fail"}}
          ]
        }
      ]
    }

    %{title: "DVIR #{System.unique_integer([:positive])}"}
    |> Inspections.create_inspection_form!(scope: scope)
    |> Inspections.update_inspection_form!(%{draft_schema: schema}, scope: scope)
    |> Inspections.publish_inspection_form!(scope: scope)
  end

  defp schedule(scope, form, vehicle) do
    Inspections.create_inspection_schedule!(
      %{inspection_form_id: form.id, vehicle_id: vehicle.id, interval_days: 1},
      scope: scope
    )
  end

  defp assignment(scope, sched, form, vehicle, due_on) do
    Inspections.generate_inspection_assignment!(
      %{
        due_on: due_on,
        schedule_id: sched.id,
        vehicle_id: vehicle.id,
        inspection_form_id: form.id
      },
      scope: scope,
      authorize?: false
    )
  end

  test "emails the owner a digest of overdue / due-soon inspections", %{
    scope: scope,
    org: org,
    owner: owner
  } do
    form = published_form(scope)
    vehicle = vehicle_fixture(scope, %{name: "Digest-#{System.unique_integer([:positive])}"})
    sched = schedule(scope, form, vehicle)
    assignment(scope, sched, form, vehicle, Date.add(Date.utc_today(), -2))

    assert {:ok, 1} = DueDigest.deliver_for_tenant(tenant(org))

    assert_email_sent(fn email ->
      assert {_, to} = hd(email.to)
      assert to == to_string(owner.email)
      assert email.subject =~ "inspection"
      assert email.html_body =~ vehicle.name
      assert email.html_body =~ "Overdue"
    end)
  end

  test "sends nothing when the only assignment is beyond the horizon", %{scope: scope, org: org} do
    form = published_form(scope)
    vehicle = vehicle_fixture(scope, %{name: "Far-#{System.unique_integer([:positive])}"})
    sched = schedule(scope, form, vehicle)
    assignment(scope, sched, form, vehicle, Date.add(Date.utc_today(), 30))

    assert {:ok, 0} = DueDigest.deliver_for_tenant(tenant(org))
    assert_no_email_sent()
  end
end
