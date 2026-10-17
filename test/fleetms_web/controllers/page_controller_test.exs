defmodule FleetmsWeb.PageControllerTest do
  use FleetmsWeb.ConnCase

  test "GET / shows the landing page to anonymous visitors", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Keep your vehicles running"
  end

  test "GET / still shows the landing page to a signed-in user, with a link into the app",
       %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    assert response =~ "Keep your vehicles running"
    # Signed in: the "Sign in" call to action becomes a link into the app (onboarding
    # for a user without an organization yet).
    assert response =~ "Go to dashboard"
    assert response =~ ~p"/orgs/new"
  end
end
