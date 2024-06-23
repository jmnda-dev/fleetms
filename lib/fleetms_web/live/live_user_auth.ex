defmodule FleetmsWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in liveviews
  """

  import Phoenix.Component
  use FleetmsWeb, :verified_routes

  def on_mount(:require_authenticated_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:user_optional, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  def on_mount(:redirect_if_authenticated, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
    else
      {:cont, socket}
    end
  end

  def on_mount(:load_user_profile_and_tenant, _params, _session, socket) do
    if user = socket.assigns[:current_user] do
      user = Ash.load!(user, [:full_name, :user_profile, :organization])
      {:cont, assign(socket, :current_user, user)}
    else
      {:cont, socket}
    end
  end
end
