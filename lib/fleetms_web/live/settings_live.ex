defmodule FleetmsWeb.SettingsLive do
  @moduledoc """
  Self-service account settings: shows the signed-in user's account identity,
  lets them change their password, and manage API keys for the JSON:API.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Accounts
  alias Fleetms.Notifications

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Account Settings"), new_api_key: nil)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket |> assign_password_form() |> load_api_keys() |> load_notification_prefs()}
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
        %{label: gettext("Account Settings")}
      ]} />

      <.header>
        {gettext("Account Settings")}
        <:subtitle>{gettext("Manage your account and password.")}</:subtitle>
      </.header>

      <div class="mt-6 max-w-2xl space-y-6">
        <section class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800">
          <h2 class="mb-4 text-lg font-semibold text-heading">{gettext("Account")}</h2>
          <.list>
            <:item :if={@current_scope.user.email} title={gettext("Email")}>
              {to_string(@current_scope.user.email)}
            </:item>
            <:item :if={@current_scope.user.username} title={gettext("Username")}>
              {@current_scope.user.username}
            </:item>
          </.list>
          <p class="mt-3 text-sm text-body">
            {gettext("Edit your name and contact details on your")}
            <.link
              navigate={~p"/o/#{@current_scope.organization}/profile"}
              class="font-medium text-brand hover:underline"
            >
              {gettext("profile")}
            </.link>.
          </p>
        </section>

        <section class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800">
          <h2 class="mb-4 text-lg font-semibold text-heading">{gettext("Change password")}</h2>
          <.form
            :let={f}
            for={@password_form}
            id="password-form"
            phx-change="validate"
            phx-submit="change-password"
            class="space-y-4"
          >
            <.input
              field={f[:current_password]}
              type="password"
              label={gettext("Current password")}
              autocomplete="current-password"
              required
            />
            <.input
              field={f[:password]}
              type="password"
              label={gettext("New password")}
              autocomplete="new-password"
              required
            />
            <.input
              field={f[:password_confirmation]}
              type="password"
              label={gettext("Confirm new password")}
              autocomplete="new-password"
              required
            />
            <.button type="submit" phx-disable-with={gettext("Updating...")}>
              {gettext("Update password")}
            </.button>
          </.form>
        </section>

        <section class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800">
          <h2 class="text-lg font-semibold text-heading">{gettext("Notifications")}</h2>
          <p class="mb-4 text-sm text-body">
            {gettext("Choose which notifications reach your bell. Changes save as you toggle.")}
          </p>
          <form phx-change="save-notification-prefs" class="space-y-3">
            <label
              :for={{key, label} <- Notifications.categories()}
              class="flex items-center gap-3 text-sm text-heading"
            >
              <input
                type="checkbox"
                name={to_string(key)}
                checked={@notif_prefs[key]}
                class="h-4 w-4 rounded-xs border-default-medium bg-neutral-secondary-medium text-brand focus:ring-brand-soft"
              />
              {label}
            </label>
          </form>
        </section>

        <section
          :if={Fleetms.FeatureFlags.api_keys?()}
          class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800"
        >
          <div class="flex items-center justify-between">
            <div>
              <h2 class="text-lg font-semibold text-heading">{gettext("API keys")}</h2>
              <p class="text-sm text-body">
                {gettext("For server-to-server access to the JSON:API. Keys act as you.")}
              </p>
            </div>
            <.button phx-click="generate-api-key" size="sm">
              <.icon name="fa-plus" class="me-1 text-xs" /> {gettext("Generate key")}
            </.button>
          </div>

          <div
            :if={@new_api_key}
            class="mt-4 rounded-base border border-amber-300 bg-amber-50 p-3 dark:border-amber-800 dark:bg-amber-900/20"
          >
            <p class="text-sm font-medium text-amber-900 dark:text-amber-200">
              {gettext("Copy this key now — it won't be shown again.")}
            </p>
            <code class="mt-1 block break-all rounded bg-white p-2 text-xs text-heading dark:bg-gray-900">
              {@new_api_key}
            </code>
          </div>

          <table :if={@api_keys != []} class="mt-4 w-full text-left text-sm text-body">
            <thead class="text-xs uppercase text-heading">
              <tr>
                <th class="py-2 font-semibold">{gettext("Created")}</th>
                <th class="py-2 font-semibold">{gettext("Expires")}</th>
                <th class="py-2 text-right font-semibold">
                  <span class="sr-only">{gettext("Actions")}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr :for={key <- @api_keys} class="border-t border-default">
                <td class="py-2">{Calendar.strftime(key.inserted_at, "%Y-%m-%d")}</td>
                <td class="py-2">{Calendar.strftime(key.expires_at, "%Y-%m-%d")}</td>
                <td class="py-2 text-right">
                  <.button
                    size="xs"
                    variant="danger"
                    phx-click="revoke-api-key"
                    phx-value-id={key.id}
                    data-confirm={gettext("Revoke this key? Anything using it stops working.")}
                  >
                    {gettext("Revoke")}
                  </.button>
                </td>
              </tr>
            </tbody>
          </table>

          <p :if={@api_keys == []} class="mt-4 text-sm text-body">
            {gettext("No API keys yet.")}
          </p>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"password" => params}, socket) do
    {:noreply,
     assign(socket, password_form: AshPhoenix.Form.validate(socket.assigns.password_form, params))}
  end

  def handle_event("change-password", %{"password" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.password_form, params: params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Password updated."))
         |> assign_password_form()}

      {:error, form} ->
        {:noreply, assign(socket, password_form: form)}
    end
  end

  def handle_event("generate-api-key", _params, socket) do
    user = socket.assigns.current_scope.user
    expires = DateTime.add(DateTime.utc_now(), 365, :day)

    case Accounts.create_api_key(%{user_id: user.id, expires_at: expires}, actor: user) do
      {:ok, key} ->
        {:noreply,
         socket
         |> assign(:new_api_key, key.__metadata__.plaintext_api_key)
         |> load_api_keys()
         |> put_flash(:info, gettext("API key generated."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not generate an API key."))}
    end
  end

  def handle_event("revoke-api-key", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user

    with {:ok, key} <- Ash.get(Fleetms.Accounts.ApiKey, id, actor: user),
         :ok <- Accounts.delete_api_key(key, actor: user) do
      {:noreply,
       socket
       |> assign(:new_api_key, nil)
       |> load_api_keys()
       |> put_flash(:info, gettext("API key revoked."))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not revoke that key."))}
    end
  end

  def handle_event("save-notification-prefs", params, socket) do
    scope = socket.assigns.current_scope

    attrs =
      Notifications.categories()
      |> Enum.map(fn {key, _label} -> {key, Map.has_key?(params, to_string(key))} end)
      |> Map.new()
      |> Map.put(:user_id, scope.user.id)

    case Notifications.upsert_notification_preference(attrs, scope: scope) do
      {:ok, _pref} ->
        {:noreply,
         socket
         |> assign(:notif_prefs, Map.delete(attrs, :user_id))
         |> put_flash(:info, gettext("Notification preferences saved."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not save your preferences."))}
    end
  end

  defp assign_password_form(socket) do
    user = socket.assigns.current_scope.user

    form =
      AshPhoenix.Form.for_update(user, :change_password, actor: user, as: "password")

    assign(socket, :password_form, form)
  end

  defp load_api_keys(socket) do
    user = socket.assigns.current_scope.user
    assign(socket, :api_keys, Accounts.list_user_api_keys!(user.id, actor: user))
  end

  # A member's saved preferences, defaulting to all-on when they've never set any.
  defp load_notification_prefs(socket) do
    scope = socket.assigns.current_scope
    defaults = Map.new(Notifications.categories(), fn {key, _} -> {key, true} end)

    prefs =
      case Notifications.get_notification_preference(scope.user.id, scope: scope) do
        {:ok, %{} = pref} -> Map.new(defaults, fn {key, _} -> {key, Map.get(pref, key, true)} end)
        _ -> defaults
      end

    assign(socket, :notif_prefs, prefs)
  end
end
