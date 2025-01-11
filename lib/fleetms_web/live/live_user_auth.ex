defmodule FleetmsWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in liveviews
  """

  import Phoenix.Component
  use FleetmsWeb, :verified_routes
  alias Fleetms.FeatureFlags

  def on_mount(:require_authenticated_user, _params, _session, socket) do
    if user = socket.assigns[:current_user] do
      current_user = Ash.load!(user, :organization)
      socket =
        socket
        |> assign(:current_user, current_user)
        |> assign(:tenant, socket.assigns[:current_tenant])

      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:user_optional, _params, _session, socket) do
    if user = socket.assigns[:current_user] do
      current_user = Ash.load!(user, :organization)
      socket =
        socket
        |> assign(:current_user, current_user)
        |> assign(:tenant, socket.assigns[:current_tenant])

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

  def on_mount(:vehicles_module, _params, _session, socket) do
    if FeatureFlags.VehicleManagement.module_enabled?(socket.assigns.current_user.organization) do
      {:cont, socket}
    else
      socket = LiveToast.put_toast(socket, :error, "Feature Disabled")
      {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
    end
  end

  def on_mount(:inspections_module, _params, _session, socket) do
    if FeatureFlags.VehicleInspections.module_enabled?(socket.assigns.current_user.organization) do
      {:cont, socket}
    else
      socket = LiveToast.put_toast(socket, :error, "Feature Disabled")
      {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
    end
  end

  def on_mount(:issues_module, _params, _session, socket) do
    if FeatureFlags.VehicleIssues.module_enabled?(socket.assigns.current_user.organization) do
      {:cont, socket}
    else
      socket = LiveToast.put_toast(socket, :error, "Feature Disabled")
      {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
    end
  end

  def on_mount(:service_module, _params, _session, socket) do
    if FeatureFlags.VehicleMaintenance.module_enabled?(socket.assigns.current_user.organization) do
      {:cont, socket}
    else
      socket = LiveToast.put_toast(socket, :error, "Feature Disabled")
      {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
    end
  end

  def on_mount(:inventory_module, _params, _session, socket) do
    if FeatureFlags.Inventory.module_enabled?(socket.assigns.current_user.organization) do
      {:cont, socket}
    else
      socket = LiveToast.put_toast(socket, :error, "Feature Disabled")
      {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
    end
  end

  def on_mount(:fuel_tracking_module, _params, _session, socket) do
    if FeatureFlags.FuelManagement.module_enabled?(socket.assigns.current_user.organization) do
      {:cont, socket}
    else
      socket = LiveToast.put_toast(socket, :error, "Feature Disabled")
      {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
    end
  end

  def on_mount(:reports, _params, _session, socket) do
    if FeatureFlags.Common.reports_enabled?(socket.assigns.current_user.organization) do
      {:cont, socket}
    else
      socket = LiveToast.put_toast(socket, :error, "Feature Disabled")
      {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
    end
  end

  def on_mount(:user_management, _params, _session, socket) do
    if FeatureFlags.Accounts.user_management_enabled?(socket.assigns.current_user.organization) do
      {:cont, socket}
    else
      socket = LiveToast.put_toast(socket, :error, "Feature Disabled")
      {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
    end
  end

  def on_mount(:user_registration, _params, _session, socket) do
    if FeatureFlags.Accounts.user_registration_enabled?(socket.assigns.current_user.organization) do
      {:cont, socket}
    else
      socket = LiveToast.put_toast(socket, :error, "Feature Disabled")
      {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
    end
  end
end
