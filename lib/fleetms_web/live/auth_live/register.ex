defmodule FleetmsWeb.AuthLive.Register do
  @moduledoc """
  Custom sign-up page. Validates with the `register_with_password` action for
  inline feedback, then hands off to the AshAuthentication controller via
  `phx-trigger-action` to create the account and establish the session.
  """
  use FleetmsWeb, :live_view

  alias FleetmsWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    if Fleetms.FeatureFlags.user_registration?() do
      {:ok,
       socket
       |> assign(:page_title, gettext("Create an account"))
       |> assign(:trigger_action, false)
       |> assign(:form, build_form())}
    else
      {:ok,
       socket
       |> put_flash(:error, gettext("Sign-up is currently disabled."))
       |> redirect(to: ~p"/sign-in")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.auth_shell flash={@flash}>
      <h1 class="mb-2 text-2xl font-bold tracking-tight text-gray-900 dark:text-white">
        {gettext("Create an account")}
      </h1>
      <p class="mb-6 text-sm text-gray-500 dark:text-gray-400">
        {gettext("Already have an account?")}
        <.link navigate={~p"/sign-in"} class="font-medium text-brand hover:underline">
          {gettext("Sign in")}
        </.link>
      </p>

      <.form
        :let={f}
        for={@form}
        action={~p"/auth/user/password/register"}
        method="post"
        phx-change="validate"
        phx-submit="submit"
        phx-trigger-action={@trigger_action}
        class="space-y-4"
      >
        <.input
          field={f[:email]}
          type="email"
          label={gettext("Email")}
          placeholder="name@company.com"
          autocomplete="username"
          required
        />
        <.input
          field={f[:password]}
          type="password"
          label={gettext("Password")}
          placeholder="••••••••"
          autocomplete="new-password"
          required
        />
        <.input
          field={f[:password_confirmation]}
          type="password"
          label={gettext("Confirm password")}
          placeholder="••••••••"
          autocomplete="new-password"
          required
        />

        <.button type="submit" class="w-full" phx-disable-with={gettext("Creating account...")}>
          {gettext("Create account")}
        </.button>
      </.form>
    </Layouts.auth_shell>
    """
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("submit", %{"user" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, form: form, trigger_action: form.valid?)}
  end

  defp build_form do
    Fleetms.Accounts.User
    |> AshPhoenix.Form.for_create(:register_with_password, domain: Fleetms.Accounts, as: "user")
  end
end
