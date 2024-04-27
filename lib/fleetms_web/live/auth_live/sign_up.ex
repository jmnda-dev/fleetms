defmodule FleetmsWeb.AuthLive.SignUp do
  @moduledoc """
  A Sign Up LiveView.
  """
  use FleetmsWeb, :live_view
  alias Fleetms.Accounts.{User, UserProfile, Organization}

  @impl true
  def mount(_params, _session, socket) do
    form =
      User
      |> AshPhoenix.Form.for_action(:register_with_password,
        domain: Fleetms.Accounts,
        as: "user",
        forms: [
          organization: [
            type: :single,
            resource: Organization,
            create_action: :create
          ],
          user_profile: [
            type: :single,
            resource: UserProfile,
            create_action: :create
          ]
        ]
      )
      |> to_form()
      |> AshPhoenix.Form.add_form(:organization)
      |> AshPhoenix.Form.add_form(:user_profile)

    socket = assign(socket, form: form, trigger_action: false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, user_params)

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, user_params)

    {:noreply, assign(socket, form: form, trigger_action: form.source.valid?)}
  end
end
