defmodule FleetmsWeb.UserLive.NewUserFormComponent do
  use FleetmsWeb, :live_component
  alias Fleetms.Accounts.User

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_form()}
  end

  @impl Phoenix.LiveComponent
  def handle_event("validate", %{"user" => user_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, user_params)

    {:noreply, assign(socket, :form, form)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("save", %{"user" => user_params}, socket) do
    organization_id = socket.assigns.current_user.organization_id
    updated_params = Map.put(user_params, "organization_id", organization_id)

    case AshPhoenix.Form.submit(socket.assigns.form, params: updated_params) do
      {:ok, user} ->
        notify_parent({:saved, user})

        {:noreply,
         socket
         |> put_flash(:info, "User created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(socket) do
    form =
      User
      |> AshPhoenix.Form.for_create(:organization_internal_user,
        as: "user",
        forms: [auto?: true]
      )
      |> AshPhoenix.Form.add_form(:user_profile)

    assign(socket, :form, to_form(form))
  end
end
