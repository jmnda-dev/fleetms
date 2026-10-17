defmodule FleetmsWeb.JsonApiNotificationsTest do
  @moduledoc "JSON:API for notifications (own list + mark read) and inspection reads."
  use FleetmsWeb.ConnCase

  import Fleetms.NotificationFixtures

  alias Fleetms.Notifications
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

  test "lists and marks a notification read", %{conn: conn, scope: scope} do
    n = notification_fixture(scope, %{title: "API notice"})

    assert %{"data" => data} = json_response(get(conn, "/api/v1/notifications"), 200)
    assert Enum.any?(data, &(&1["id"] == n.id))

    body = %{data: %{type: "notification", id: n.id, attributes: %{}}}

    assert json_response(
             patch(conn, "/api/v1/notifications/#{n.id}/read", Jason.encode!(body)),
             200
           )

    assert Notifications.unread_notification_count!(scope: scope) == 0
  end

  test "inspection read routes respond", %{conn: conn} do
    for path <- ~w(/api/v1/inspections /api/v1/inspection-forms
                   /api/v1/inspection-schedules /api/v1/inspection-assignments) do
      assert %{"data" => _} = json_response(get(conn, path), 200)
    end
  end
end
