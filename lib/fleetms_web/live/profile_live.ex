defmodule FleetmsWeb.ProfileLive do
  @moduledoc """
  Self-service page where the signed-in user views and edits their own profile
  (name, contact details, address). The profile is created on first save if it
  doesn't exist yet.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, gettext("My Profile"))}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    profile = load_profile(socket.assigns.current_scope.user)
    {:noreply, socket |> assign(:profile, profile) |> assign_form()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      organizations={@organizations}
      unread_notifications_count={@unread_notifications_count}
      recent_notifications={@recent_notifications}
      notifications_open={@notifications_open}
    >
      <.breadcrumbs items={[
        %{label: gettext("Dashboard"), path: ~p"/o/#{@current_scope.organization}", icon: "fa-house"},
        %{label: gettext("My Profile")}
      ]} />

      <.header>
        {gettext("My Profile")}
        <:subtitle>{gettext("Your personal details.")}</:subtitle>
      </.header>

      <div class="mt-6 max-w-3xl rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800">
        <div class="mb-6 flex items-center gap-4">
          <span class="flex h-16 w-16 items-center justify-center rounded-full bg-brand-softer text-xl font-semibold text-fg-brand-strong">
            {initials(@profile, @current_scope.user)}
          </span>
          <div>
            <p class="font-semibold text-heading">{display_name(@profile, @current_scope.user)}</p>
            <p class="text-sm text-body">{identifier(@current_scope.user)}</p>
          </div>
        </div>

        <.form
          :let={f}
          for={@form}
          id="profile-form"
          phx-change="validate"
          phx-submit="save"
          class="space-y-4"
        >
          <div class="grid gap-x-4 sm:grid-cols-2">
            <.input field={f[:first_name]} label={gettext("First name")} required />
            <.input field={f[:last_name]} label={gettext("Last name")} />
          </div>
          <.input field={f[:other_name]} label={gettext("Other name")} />
          <div class="grid gap-x-4 sm:grid-cols-2">
            <.input field={f[:phone_number]} label={gettext("Phone number")} />
            <.input field={f[:secondary_phone_number]} label={gettext("Secondary phone")} />
          </div>
          <.input field={f[:date_of_birth]} type="date" label={gettext("Date of birth")} />
          <.input field={f[:address]} label={gettext("Address")} />
          <div class="grid gap-x-4 sm:grid-cols-3">
            <.input field={f[:city]} label={gettext("City")} />
            <.input field={f[:state]} label={gettext("State")} />
            <.input field={f[:postal_code]} label={gettext("Postal code")} />
          </div>

          <div class="border-t border-default pt-4">
            <.button type="submit" phx-disable-with={gettext("Saving...")}>
              {gettext("Save profile")}
            </.button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"profile" => params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"profile" => params}, socket) do
    user = socket.assigns.current_scope.user
    params = if socket.assigns.profile, do: params, else: Map.put(params, "user_id", user.id)

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, profile} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Profile saved."))
         |> assign(:profile, profile)
         |> assign_form()}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp load_profile(user) do
    case Accounts.get_user_profile(user.id, actor: user, not_found_error?: false) do
      {:ok, profile} -> profile
      _ -> nil
    end
  end

  defp assign_form(socket) do
    user = socket.assigns.current_scope.user

    form =
      case socket.assigns.profile do
        nil ->
          AshPhoenix.Form.for_create(Fleetms.Accounts.UserProfile, :create,
            actor: user,
            as: "profile"
          )

        profile ->
          AshPhoenix.Form.for_update(profile, :update, actor: user, as: "profile")
      end

    assign(socket, :form, form)
  end

  defp display_name(%{first_name: first} = profile, _user) when is_binary(first) do
    [first, profile.last_name] |> Enum.reject(&is_nil/1) |> Enum.join(" ")
  end

  defp display_name(_profile, user), do: identifier(user)

  defp identifier(user), do: to_string(user.email || user.username)

  defp initials(profile, user) do
    profile
    |> display_name(user)
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join("", &String.first/1)
    |> String.upcase()
    |> case do
      "" -> "?"
      letters -> letters
    end
  end
end
