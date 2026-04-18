defmodule FleetmsWeb.PageController do
  use FleetmsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def index conn, _params do
    conn |> put_root_layout(html: {FleetmsWeb.Layouts, :spa_root}) |> render(:index)
  end
end
