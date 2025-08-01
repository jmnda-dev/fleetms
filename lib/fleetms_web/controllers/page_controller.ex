defmodule FleetmsWeb.PageController do
  use FleetmsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
