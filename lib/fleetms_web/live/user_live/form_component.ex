defmodule FleetmsWeb.UserLive.FormComponent do
  use FleetmsWeb, :live_component
  alias Fleetms.Accounts.User

  import Fleetms.Utils, only: [atom_list_to_options_for_select: 1]

  @impl Phoenix.LiveComponent
  def update(%{user: user} = assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_form(user)

    {:ok, socket}
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

  defp assign_form(socket, user) do
    form =
      if not is_nil(user) do
        user
        |> AshPhoenix.Form.for_update(:update,
          as: "user",
          forms: [auto?: true]
        )
      else
        User
        |> AshPhoenix.Form.for_create(:organization_internal_user,
          as: "user",
          forms: [auto?: true]
        )
        |> AshPhoenix.Form.add_form(:user_profile)
      end

    assign(socket, :form, to_form(form))
  end

  defp user_roles_options, do: Fleetms.Enums.basic_user_roles()
end
