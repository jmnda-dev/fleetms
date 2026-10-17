defmodule Fleetms.Inspections.ScheduleTest do
  use Fleetms.DataCase

  import Fleetms.VehicleFixtures

  alias Fleetms.Inspections
  alias Fleetms.Inspections.{InspectionSchedule, ScheduleRunner}

  setup :shared_org

  defp tenant(org), do: Ash.ToTenant.to_tenant(org, InspectionSchedule)

  defp published_form(scope) do
    schema = %{
      "sections" => [
        %{
          "id" => "s1",
          "title" => "Checks",
          "items" => [
            %{"id" => "brakes", "label" => "Brakes", "config" => %{"type" => "pass_fail"}}
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

  defp schedule(scope, form, vehicle, extra) do
    %{inspection_form_id: form.id, vehicle_id: vehicle.id}
    |> Map.merge(extra)
    |> Inspections.create_inspection_schedule!(scope: scope)
  end

  defp submit(scope, vehicle, version, brakes \\ "pass") do
    Inspections.submit_inspection!(
      %{
        vehicle_id: vehicle.id,
        inspection_form_version_id: version.id,
        answers: [%{"item_id" => "brakes", "value" => brakes}]
      },
      scope: scope
    )
  end

  test "generates one pending assignment per active schedule, idempotently", %{
    scope: scope,
    org: org
  } do
    {form, _version} = published_form(scope)
    vehicle = vehicle_fixture(scope, %{mileage: Decimal.new("100")})
    schedule(scope, form, vehicle, %{interval_days: 1})

    assert ScheduleRunner.generate_for_tenant(tenant(org)) == 1
    # An open assignment already exists — the next run creates nothing.
    assert ScheduleRunner.generate_for_tenant(tenant(org)) == 0

    assert [assignment] = Inspections.list_inspection_assignments!(%{}, scope: scope).results
    assert assignment.due_on == Date.utc_today()
    assert assignment.status == :pending
    assert is_nil(assignment.completed_at)
  end

  test "a schedule anchored in the past yields an overdue assignment", %{scope: scope, org: org} do
    {form, _version} = published_form(scope)
    vehicle = vehicle_fixture(scope, %{mileage: Decimal.new("100")})

    schedule(scope, form, vehicle, %{
      interval_days: 7,
      start_date: Date.add(Date.utc_today(), -10)
    })

    ScheduleRunner.generate_for_tenant(tenant(org))

    assert [assignment] = Inspections.list_inspection_assignments!(%{}, scope: scope).results
    assert assignment.status == :overdue
  end

  test "an inactive schedule generates nothing", %{scope: scope, org: org} do
    {form, _version} = published_form(scope)
    vehicle = vehicle_fixture(scope, %{mileage: Decimal.new("100")})
    schedule(scope, form, vehicle, %{active: false})

    assert ScheduleRunner.generate_for_tenant(tenant(org)) == 0
    assert Inspections.list_inspection_assignments!(%{}, scope: scope).results == []
  end

  test "submitting a matching inspection closes the assignment; the next is then generated", %{
    scope: scope,
    org: org
  } do
    {form, version} = published_form(scope)
    vehicle = vehicle_fixture(scope, %{mileage: Decimal.new("100")})
    schedule(scope, form, vehicle, %{interval_days: 7, start_date: Date.utc_today()})
    ScheduleRunner.generate_for_tenant(tenant(org))

    assert [assignment] = Inspections.list_inspection_assignments!(%{}, scope: scope).results
    refute assignment.completed_at

    inspection = submit(scope, vehicle, version)

    completed = Inspections.get_inspection_assignment!(assignment.id, scope: scope)
    assert completed.status == :done
    assert completed.inspection_id == inspection.id
    assert completed.completed_at

    # With the previous one closed, the next run generates the following period.
    assert ScheduleRunner.generate_for_tenant(tenant(org)) == 1

    assert [next] =
             Inspections.list_inspection_assignments!(%{only_open: true}, scope: scope).results

    assert next.due_on == Date.add(Date.utc_today(), 7)
  end

  test "submitting without a matching schedule completes nothing", %{scope: scope} do
    {_form, version} = published_form(scope)
    vehicle = vehicle_fixture(scope, %{mileage: Decimal.new("100")})

    submit(scope, vehicle, version)

    assert Inspections.list_inspection_assignments!(%{}, scope: scope).results == []
  end
end
