defmodule FleetmsWeb.PwaTest do
  @moduledoc "The PWA shell files are served (manifest, service worker, offline page)."
  use FleetmsWeb.ConnCase, async: true

  test "serves the web manifest", %{conn: conn} do
    conn = get(conn, "/manifest.json")
    assert conn.status == 200
    assert conn.resp_body =~ "FleetMS"
    assert conn.resp_body =~ "standalone"
  end

  test "serves the service worker at the origin root", %{conn: conn} do
    conn = get(conn, "/service-worker.js")
    assert conn.status == 200
    assert conn.resp_body =~ "addEventListener"
  end

  test "serves the offline fallback page", %{conn: conn} do
    conn = get(conn, "/offline.html")
    assert conn.status == 200
    assert conn.resp_body =~ "offline"
  end

  test "serves the PWA icons", %{conn: conn} do
    for path <- ["/images/icon-192.png", "/images/icon-512.png", "/images/icon-maskable-512.png"] do
      assert get(conn, path).status == 200
    end
  end
end
