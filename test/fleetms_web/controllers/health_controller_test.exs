defmodule FleetmsWeb.HealthControllerTest do
  use FleetmsWeb.ConnCase, async: true

  test "GET /health returns 200 without touching the database", %{conn: conn} do
    conn = get(conn, ~p"/health")
    assert text_response(conn, 200) == "ok"
  end
end
