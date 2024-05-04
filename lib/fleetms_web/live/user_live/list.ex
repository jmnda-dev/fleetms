defmodule FleetmsWeb.UserLive.List do
  use FleetmsWeb, :live_view

  alias Fleetms.Accounts
  alias Fleetms.Accounts.User

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if Ash.can?({User, :list}, socket.assigns.current_user) do
      {:ok, socket}
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError, "Not Authorized"
    end
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    users = Ash.read!(User, actor: socket.assigns.current_user)

    socket = stream(socket, :users, users)
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl Phoenix.LiveView
  def handle_info({FleetmsWeb.UserLive.FormComponent, {:saved, user}}, socket) do
    {:noreply, stream_insert(socket, :users, user)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    current_user = socket.assigns.current_user

    if Ash.can?({User, :update}, current_user) do
      user = Accounts.get_user_by_id!(id, actor: current_user)

      socket
      |> assign(:page_title, "Edit User")
      |> assign(:user, user)
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError, "Not Authorized"
    end
  end

  defp apply_action(socket, :new, _params) do
    if Ash.can?({User, :create_organization_user}, socket.assigns.current_user) do
      socket
      |> assign(:page_title, "New User")
      |> assign(:user, nil)
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError, "Not Authorized"
    end
  end

  defp apply_action(socket, :listing, _params) do
    socket
    |> assign(:page_title, "User Listing")
    |> assign(:user, nil)
  end
end
