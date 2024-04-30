defmodule FleetmsWeb.DashboardLive do
  use FleetmsWeb, :live_view

  def render(assigns) do
    ~H"""
    <h1 class="text-xl text-gray-800 dark:text-gray-100">Dashboard</h1>
    """
  end
end
