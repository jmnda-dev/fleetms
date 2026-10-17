defmodule FleetmsWeb.NotificationsBellTest do
  @moduledoc """
  The navbar notifications bell: initial badge/list, real-time updates over
  PubSub, marking read, and click-through. Not async — like other LiveView tests
  it needs shared-mode sandbox and a logged-in owner (see IssueLiveTest).
  """
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Fleetms.Notifications
  alias Fleetms.Scope

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), owner: owner, org: org, scope: Scope.new(owner, org, true)}
  end

  test "renders the unread badge and recent notifications on mount", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    Notifications.notify!(
      %{recipient_id: scope.user.id, type: "issue_assigned", title: "You were assigned #7"},
      scope: scope
    )

    {:ok, _view, html} = live(conn, ~p"/o/#{org}")

    assert html =~ "You were assigned #7"
    # Badge shows the unread count.
    assert html =~ "Mark all read"
  end

  test "updates live when a notification is created", %{conn: conn, org: org, scope: scope} do
    {:ok, view, _html} = live(conn, ~p"/o/#{org}")

    refute render(view) =~ "Brand new alert"

    Notifications.notify!(
      %{recipient_id: scope.user.id, type: "issue_assigned", title: "Brand new alert"},
      scope: scope
    )

    assert render(view) =~ "Brand new alert"
  end

  test "the dropdown toggles open and closed", %{conn: conn, org: org} do
    {:ok, view, _html} = live(conn, ~p"/o/#{org}")

    panel = element(view, "#notificationDropdown")
    # The `hidden` boolean attribute renders right after the id when closed.
    closed = ~s|id="notificationDropdown" hidden|

    # Closed on mount.
    assert render(panel) =~ closed

    render_click(element(view, "#notifications-menu-button"))
    refute render(panel) =~ closed

    render_click(element(view, "#notifications-menu-button"))
    assert render(panel) =~ closed
  end

  test "mark all read clears the badge", %{conn: conn, org: org, scope: scope} do
    Notifications.notify!(
      %{recipient_id: scope.user.id, title: "Unread one"},
      scope: scope
    )

    {:ok, view, _html} = live(conn, ~p"/o/#{org}")
    assert render(view) =~ "Mark all read"

    view
    |> element("button", "Mark all read")
    |> render_click()

    # No unread left → the "Mark all read" affordance disappears.
    refute render(view) =~ "Mark all read"
    assert Notifications.unread_notification_count!(scope: scope) == 0
  end

  test "opening a notification marks it read and navigates to its path", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    notification =
      Notifications.notify!(
        %{recipient_id: scope.user.id, title: "Go to issue", path: "/issues/abc"},
        scope: scope
      )

    {:ok, view, _html} = live(conn, ~p"/o/#{org}")

    view
    |> element(~s|button[phx-value-id="#{notification.id}"]|)
    |> render_click()

    assert_redirect(view, "/o/#{org.public_id}/issues/abc")
    assert Notifications.unread_notification_count!(scope: scope) == 0
  end
end
