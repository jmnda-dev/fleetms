defmodule FleetmsWeb.UploadsServingTest do
  @moduledoc """
  Guards that locally-stored user uploads are served at `/uploads`.

  Regression test: uploads must live in `priv/uploads` (outside `priv/static`) so
  the main asset `Plug.Static` doesn't intercept them. If they slip back under
  `priv/static`, this request would 404 (and, in dev, the static allowlist would
  raise instead of serving).
  """
  use FleetmsWeb.ConnCase, async: true

  test "serves a stored upload from /uploads", %{conn: conn} do
    dir = Application.app_dir(:fleetms, "priv/uploads/__serving_test__")
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "probe.txt"), "served")
    on_exit(fn -> File.rm_rf!(dir) end)

    conn = get(conn, "/uploads/__serving_test__/probe.txt")
    assert response(conn, 200) == "served"
  end
end
