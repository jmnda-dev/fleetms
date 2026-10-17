defmodule FleetmsWeb.AuthLive.SignIn do
  @moduledoc """
  Custom sign-in page. Collects credentials and, on submit, hands off to the
  AshAuthentication controller via `phx-trigger-action` (a real form POST is the
  only way to establish the session cookie). Supports signing in with either an
  email or a username, chosen with a mode toggle.
  """
  use FleetmsWeb, :live_view

  alias FleetmsWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Sign in"))
     |> assign(:mode, :email)
     |> assign(:trigger_action, false)
     |> assign(:form, to_form(%{}, as: "user"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.auth_shell flash={@flash}>
      <h1 class="mb-2 text-2xl font-bold tracking-tight text-gray-900 dark:text-white">
        {gettext("Welcome back")}
      </h1>
      <p
        :if={Fleetms.FeatureFlags.user_registration?()}
        class="mb-6 text-sm text-gray-500 dark:text-gray-400"
      >
        {gettext("Don't have an account?")}
        <.link navigate={~p"/register"} class="font-medium text-brand hover:underline">
          {gettext("Sign up")}
        </.link>
      </p>

      <.form
        :let={f}
        for={@form}
        action={action_url(@mode)}
        method="post"
        phx-change="validate"
        phx-submit="submit"
        phx-trigger-action={@trigger_action}
        class="space-y-4"
      >
        <%= if @mode == :email do %>
          <.input
            field={f[:email]}
            type="email"
            label={gettext("Email")}
            placeholder="name@company.com"
            autocomplete="username"
            required
          />
        <% else %>
          <.input
            field={f[:username]}
            type="text"
            label={gettext("Username")}
            placeholder={gettext("your-username")}
            autocomplete="username"
            required
          />
        <% end %>

        <.input
          field={f[:password]}
          type="password"
          label={gettext("Password")}
          placeholder="••••••••"
          autocomplete="current-password"
          required
        />

        <div class="flex items-center justify-end">
          <.link
            navigate={~p"/forgot-password"}
            class="text-sm font-medium text-brand hover:underline"
          >
            {gettext("Forgot password?")}
          </.link>
        </div>

        <.button type="submit" class="w-full" phx-disable-with={gettext("Signing in...")}>
          {gettext("Sign in to your account")}
        </.button>
      </.form>

      <p class="mt-6 text-center text-sm text-gray-500 dark:text-gray-400">
        <button type="button" phx-click="toggle-mode" class="font-medium text-brand hover:underline">
          <%= if @mode == :email do %>
            {gettext("Sign in with a username instead")}
          <% else %>
            {gettext("Sign in with an email instead")}
          <% end %>
        </button>
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

  def handle_event("toggle-mode", _params, socket) do
    mode = if socket.assigns.mode == :email, do: :username, else: :email
    {:noreply, assign(socket, mode: mode, trigger_action: false, form: to_form(%{}, as: "user"))}
  end

  defp action_url(:email), do: ~p"/auth/user/password/sign_in"
  defp action_url(:username), do: ~p"/auth/user/username_password/sign_in"
end
