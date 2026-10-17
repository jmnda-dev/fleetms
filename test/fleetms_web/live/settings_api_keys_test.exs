defmodule FleetmsWeb.SettingsApiKeysTest do
  @moduledoc "Managing API keys from Account Settings."
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Fleetms.Accounts
  alias Fleetms.Scope

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), owner: owner, org: org, scope: Scope.new(owner, org, true)}
  end

  test "generates a key and shows it once, then lists and revokes it", %{
    conn: conn,
    org: org,
    owner: owner
  } do
    {:ok, view, html} = live(conn, ~p"/o/#{org}/settings")
    assert html =~ "API keys"
    assert html =~ "No API keys yet."

    html = render_click(view, "generate-api-key", %{})
    # The plaintext key is shown once and starts with the configured prefix.
    assert html =~ "be shown again"
    assert html =~ "fleetms_"

    assert [key] = Accounts.list_user_api_keys!(owner.id, actor: owner)

    render_click(view, "revoke-api-key", %{"id" => key.id})
    assert Accounts.list_user_api_keys!(owner.id, actor: owner) == []
  end
end
