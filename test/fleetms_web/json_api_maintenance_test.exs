defmodule FleetmsWeb.JsonApiMaintenanceTest do
  @moduledoc "JSON:API for the maintenance domain (vendors, reminders + snooze, etc.)."
  use FleetmsWeb.ConnCase

  import Fleetms.VehicleFixtures
  import Fleetms.MaintenanceFixtures

  alias Fleetms.Maintenance
  alias Fleetms.Scope

  @ct "application/vnd.api+json"

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    {:ok, token, _} = AshAuthentication.Jwt.token_for_user(owner)

    conn =
      conn
      |> put_req_header("accept", @ct)
      |> put_req_header("content-type", @ct)
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("x-organization", org.public_id)

    %{conn: conn, org: org, scope: Scope.new(owner, org, true)}
  end

  test "index routes respond", %{conn: conn} do
    for path <- ~w(/api/v1/work-orders /api/v1/service-reminders /api/v1/vendors
                   /api/v1/service-tasks /api/v1/service-groups) do
      assert %{"data" => _} = json_response(get(conn, path), 200)
    end
  end

  test "creates a vendor via POST", %{conn: conn, scope: scope} do
    body = %{data: %{type: "vendor", attributes: %{name: "API Parts Co"}}}
    conn = post(conn, "/api/v1/vendors", Jason.encode!(body))

    assert %{"data" => %{"id" => id}} = json_response(conn, 201)
    assert {:ok, _} = Maintenance.get_vendor(id, scope: scope)
  end

  test "snoozes a reminder via the custom action route", %{conn: conn, scope: scope} do
    vehicle = vehicle_fixture(scope)
    task = service_task_fixture(scope)

    reminder =
      service_reminder_fixture(scope, vehicle, task, %{
        time_interval: 1,
        time_interval_unit: :month
      })

    original = reminder.next_due_date
    body = %{data: %{type: "service-reminder", id: reminder.id, attributes: %{days: 7}}}

    conn = patch(conn, "/api/v1/service-reminders/#{reminder.id}/snooze", Jason.encode!(body))

    assert json_response(conn, 200)
    updated = Maintenance.get_service_reminder!(reminder.id, scope: scope)
    assert Date.diff(updated.next_due_date, original) == 7
  end
end
