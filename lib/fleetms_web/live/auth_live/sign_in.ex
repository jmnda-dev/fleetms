defmodule FleetmsWeb.AuthLive.SignIn do
  @moduledoc """
  A Sign in LiveView
  """
  use FleetmsWeb, :live_view
  alias Fleetms.FeatureFlags

  @impl true
  def mount(_params, _session, socket) do
    form =
      Fleetms.Accounts.User
      |> AshPhoenix.Form.for_action(:sign_in_with_password, domain: Fleetms.Accounts, as: "user")
      |> to_form()

    socket = assign(socket, form: form, trigger_action: false)
    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, user_params, errors: false)

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("submit", %{"user" => user_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, user_params)

    {:noreply, assign(socket, form: form, trigger_action: form.source.valid?)}
  end
end
