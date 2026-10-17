defmodule FleetmsWeb.AuthLive.ForgotPassword do
  @moduledoc """
  Requests a password-reset email. Posts to the AshAuthentication controller,
  which always responds the same way whether or not the email exists (no account
  enumeration).
  """
  use FleetmsWeb, :live_view

  alias FleetmsWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Reset your password"))
     |> assign(:trigger_action, false)
     |> assign(:form, to_form(%{}, as: "user"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.auth_shell flash={@flash}>
      <h1 class="mb-2 text-2xl font-bold tracking-tight text-gray-900 dark:text-white">
        {gettext("Reset your password")}
      </h1>
      <p class="mb-6 text-sm text-gray-500 dark:text-gray-400">
        {gettext("Enter your email and we'll send you a link to reset your password.")}
      </p>

      <.form
        :let={f}
        for={@form}
        action={~p"/auth/user/password/reset_request"}
        method="post"
        phx-change="validate"
        phx-submit="submit"
        phx-trigger-action={@trigger_action}
        class="space-y-4"
      >
        <.input
          field={f[:email]}
          type="email"
          label={gettext("Email address")}
          placeholder="name@company.com"
          autocomplete="username"
          required
        />

        <.button type="submit" class="w-full" phx-disable-with={gettext("Sending...")}>
          {gettext("Send reset link")}
        </.button>
      </.form>

      <p class="mt-6 text-center text-sm text-gray-500 dark:text-gray-400">
        <.link navigate={~p"/sign-in"} class="font-medium text-brand hover:underline">
          {gettext("Back to sign in")}
        </.link>
      </p>
    </Layouts.auth_shell>
    """
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_action: false)}
  end

  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_action: true)}
  end
end
