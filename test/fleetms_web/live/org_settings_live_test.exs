defmodule FleetmsWeb.OrgSettingsLiveTest do
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Fleetms.Accounts

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), owner: owner, org: org}
  end

  test "the owner sees the settings (ZMW default) and can change them", %{
    conn: conn,
    org: org,
    owner: owner
  } do
    {:ok, view, html} = live(conn, ~p"/o/#{org}/organization-settings")

    assert html =~ "Organization Settings"
    assert html =~ "ZMW"

    view
    |> form("#org-settings-form", %{
      settings: %{
        unit_system: "imperial",
        currency: "USD",
        timezone: "Africa/Lusaka",
        date_format: "eu"
      }
    })
    |> render_submit()

    updated = Accounts.get_organization!(org.id, actor: owner)
    assert updated.unit_system == :imperial
    assert updated.currency == "USD"
    assert updated.timezone == "Africa/Lusaka"
    assert updated.date_format == :eu
  end
end
