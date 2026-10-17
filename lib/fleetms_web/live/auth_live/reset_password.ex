defmodule FleetmsWeb.AuthLive.ResetPassword do
  @moduledoc """
  Sets a new password from a reset link. The token comes from the URL and is
  posted (hidden) alongside the new password to the AshAuthentication controller.
  """
  use FleetmsWeb, :live_view

  alias FleetmsWeb.Layouts

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Create new password"))
     |> assign(:token, token)
     |> assign(:trigger_action, false)
     |> assign(:form, to_form(%{}, as: "user"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.auth_shell flash={@flash}>
      <h1 class="mb-2 text-2xl font-bold tracking-tight text-gray-900 dark:text-white">
        {gettext("Create new password")}
      </h1>
      <p class="mb-6 text-sm text-gray-500 dark:text-gray-400">
        {gettext("Choose a new password for your account.")}
      </p>

      <.form
        :let={f}
        for={@form}
        action={~p"/auth/user/password/reset"}
        method="post"
        phx-change="validate"
        phx-submit="submit"
        phx-trigger-action={@trigger_action}
        class="space-y-4"
      >
        <input type="hidden" name="user[reset_token]" value={@token} />

        <.input
          field={f[:password]}
          type="password"
          label={gettext("New password")}
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

        <.button type="submit" class="w-full" phx-disable-with={gettext("Updating...")}>
          {gettext("Reset password")}
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
