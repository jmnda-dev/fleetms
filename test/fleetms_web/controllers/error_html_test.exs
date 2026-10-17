defmodule FleetmsWeb.ErrorHTMLTest do
  use FleetmsWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  test "renders 404.html" do
    html = render_to_string(FleetmsWeb.ErrorHTML, "404", "html", [])
    assert html =~ "404"
    assert html =~ "Page not found"
    assert html =~ "Back to home"
    # A full, self-contained page (renders outside the app layout).
    assert html =~ "<!DOCTYPE html>"
  end

  test "renders 403.html" do
    html = render_to_string(FleetmsWeb.ErrorHTML, "403", "html", [])
    assert html =~ "403"
    assert html =~ "Access denied"
  end

  test "renders 500.html" do
    html = render_to_string(FleetmsWeb.ErrorHTML, "500", "html", [])
    assert html =~ "500"
    assert html =~ "Something went wrong"
  end

  test "renders 503.html" do
    html = render_to_string(FleetmsWeb.ErrorHTML, "503", "html", [])
    assert html =~ "503"
    assert html =~ "maintenance"
  end
end
