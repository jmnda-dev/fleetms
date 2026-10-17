defmodule FleetmsWeb.WorkOrderShowLiveTest do
  # Not async (ConnCase default): LiveView tests need shared-mode sandbox and a
  # logged-in owner with a real auth token, so they create their own org.
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fleetms.MaintenanceFixtures
  import Fleetms.InventoryFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.Maintenance
  alias Fleetms.Scope

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), owner: owner, org: org, scope: Scope.new(owner, org, true)}
  end

  defp work_order_with_lines(scope, owner) do
    vehicle = vehicle_fixture(scope, %{name: "Zephyr Hauler"})
    task = service_task_fixture(scope, %{name: "Oil change"})
    part = part_fixture(scope, %{name: "Oil filter"})

    Maintenance.create_work_order!(
      %{
        vehicle_id: vehicle.id,
        work_order_service_tasks: [
          %{
            service_task_id: task.id,
            work_order_service_task_parts: [
              %{part_id: part.id, quantity: Decimal.new("2"), unit_cost: Money.new(:USD, "10.00")}
            ],
            labor_items: [
              %{
                labor_type: :technician,
                technician_id: owner.id,
                hours: Decimal.new("1"),
                hourly_rate: Money.new(:USD, "40.00")
              }
            ]
          }
        ]
      },
      scope: scope
    )
  end

  test "shows the work order overview with costs and line items", %{
    conn: conn,
    owner: owner,
    org: org,
    scope: scope
  } do
    wo = work_order_with_lines(scope, owner)

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/work-orders/#{wo.id}")

    assert html =~ "##{wo.work_order_number}"
    assert html =~ "Zephyr Hauler"
    assert html =~ "Open"
    assert html =~ "Oil change"
    assert html =~ "Oil filter"
    # parts $20.00 + labour $40.00 = $60.00 total
    assert html =~ "$60.00"
  end

  test "renders the printable document tab", %{conn: conn, owner: owner, org: org, scope: scope} do
    wo = work_order_with_lines(scope, owner)

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/work-orders/#{wo.id}")

    html = render_click(element(view, ~s|[phx-click][phx-value-tab="document"]|))

    assert html =~ "Work Order"
    assert html =~ "print-work-order"
    assert html =~ "Technician signature"
  end

  test "renders the photos and documents tabs with upload panels", %{
    conn: conn,
    owner: owner,
    org: org,
    scope: scope
  } do
    wo = work_order_with_lines(scope, owner)

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/work-orders/#{wo.id}")

    photos = render_click(element(view, ~s|[phx-click][phx-value-tab="photos"]|))
    assert photos =~ "No photos yet."
    assert photos =~ "PNG, JPG or WEBP up to 10MB"

    docs = render_click(element(view, ~s|[phx-click][phx-value-tab="documents"]|))
    assert docs =~ "No documents yet."
    assert docs =~ "PDF, Office, images or text up to 20MB"
  end

  test "start → complete → reopen through the header buttons", %{
    conn: conn,
    owner: owner,
    org: org,
    scope: scope
  } do
    wo = work_order_with_lines(scope, owner)

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/work-orders/#{wo.id}")

    render_click(element(view, ~s|button[phx-click="start"]|))
    assert Maintenance.get_work_order!(wo.id, scope: scope).status == :in_progress

    render_click(element(view, ~s|button[phx-click="complete"]|))
    assert Maintenance.get_work_order!(wo.id, scope: scope).status == :completed

    render_click(element(view, ~s|button[phx-click="reopen"]|))
    assert Maintenance.get_work_order!(wo.id, scope: scope).status == :in_progress
  end

  test "the History tab shows a readable audit timeline", %{conn: conn, org: org, scope: scope} do
    wo = work_order_fixture(scope)
    Maintenance.start_work_order!(wo, scope: scope)

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/work-orders/#{wo.id}")
    html = render_click(view, "select-tab", %{"tab" => "history"})

    assert html =~ "created this work order"
    assert html =~ "started work"
  end

  test "posts a comment from the Comments tab", %{conn: conn, org: org, scope: scope} do
    wo = work_order_fixture(scope)

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/work-orders/#{wo.id}")
    render_click(view, "select-tab", %{"tab" => "comments"})

    view
    |> form("#comments-#{wo.id}-compose", %{body: "Parts on order"})
    |> render_submit()

    assert render(view) =~ "Parts on order"

    assert [%{body: "Parts on order"}] =
             Fleetms.Comments.list_comments!(%{work_order_id: wo.id}, scope: scope)
  end
end
