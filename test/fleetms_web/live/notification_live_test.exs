defmodule FleetmsWeb.NotificationLiveTest do
  @moduledoc "The full notifications page: listing, mark-all-read and clearing."
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fleetms.NotificationFixtures

  alias Fleetms.Notifications
  alias Fleetms.Scope

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), org: org, scope: Scope.new(owner, org, true)}
  end

  test "lists the recipient's notifications", %{conn: conn, org: org, scope: scope} do
    notification_fixture(scope, %{title: "Renewal due soon"})

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/notifications")

    assert html =~ "Notifications"
    assert html =~ "Renewal due soon"
  end

  test "empty state when there's nothing", %{conn: conn, org: org} do
    {:ok, _view, html} = live(conn, ~p"/o/#{org}/notifications")
    assert html =~ "No notifications"
  end

  test "mark all read marks everything read", %{conn: conn, org: org, scope: scope} do
    notification_fixture(scope, %{title: "Unread one"})

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/notifications")

    view |> element("button[phx-click='mark_all']") |> render_click()

    assert Notifications.unread_notification_count!(scope: scope) == 0
  end

  test "clearing a notification removes it from the list", %{conn: conn, org: org, scope: scope} do
    notification_fixture(scope, %{title: "Delete me"})

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/notifications")
    assert has_element?(view, "li", "Delete me")

    view |> element("button[phx-click='delete']") |> render_click()

    refute has_element?(view, "li", "Delete me")
    assert Notifications.list_notifications!(scope: scope) == []
  end
end
