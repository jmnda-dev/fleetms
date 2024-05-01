defmodule FleetmsWeb.UserLive do
  use FleetmsWeb, :live_view

  def render(assigns) do
    ~H"""
    <h1 class="text-xl text-gray-800 dark:text-gray-100">Users</h1>
    """
  end
end
