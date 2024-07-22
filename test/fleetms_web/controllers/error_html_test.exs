defmodule FleetmsWeb.ErrorHTMLTest do
  use FleetmsWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template

  test "renders 403.html" do
    assert render_to_string(FleetmsWeb.ErrorHTML, "403", "html", []) =~
             "Your are not authorized to perform that action."
  end

  test "renders 404.html" do
    assert render_to_string(FleetmsWeb.ErrorHTML, "404", "html", []) =~
             "Whoops! That page doesn't exist."
  end

  test "renders 500.html" do
    assert render_to_string(FleetmsWeb.ErrorHTML, "500", "html", []) =~
             "Whoops! Something went wrong on our end"
  end
end
