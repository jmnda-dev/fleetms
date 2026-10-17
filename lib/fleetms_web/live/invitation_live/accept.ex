defmodule FleetmsWeb.InvitationLive.Accept do
  @moduledoc """
  Public page where an invited person sets up their account from the link emailed
  to them. On success the account and membership are created (via
  `Fleetms.Membership`) and they're sent to sign in.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Accounts
  alias Fleetms.Membership
  alias FleetmsWeb.Layouts

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Accounts.get_invitation_by_token(token, authorize?: false) do
      {:ok, invitation} ->
        {:ok,
         socket
         |> assign(:page_title, gettext("Accept invitation"))
         |> assign(:token, token)
         |> assign(:invitation, invitation)
         |> assign(:form, to_form(%{}, as: "signup"))}

      {:error, _} ->
        {:ok,
         socket
         |> assign(:page_title, gettext("Invitation"))
         |> assign(:invitation, nil)}
    end
  end

  @impl true
  def render(%{invitation: nil} = assigns) do
    ~H"""
    <Layouts.auth_shell flash={@flash}>
      <h1 class="mb-2 text-2xl font-bold tracking-tight text-gray-900 dark:text-white">
        {gettext("Invitation not found")}
      </h1>
      <p class="mb-6 text-sm text-gray-500 dark:text-gray-400">
        {gettext(
          "This invitation link is invalid or has expired. Ask whoever invited you to send a new one."
        )}
      </p>
      <.link navigate={~p"/sign-in"} class="font-medium text-brand hover:underline">
        {gettext("Back to sign in")}
      </.link>
    </Layouts.auth_shell>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.auth_shell flash={@flash}>
      <h1 class="mb-2 text-2xl font-bold tracking-tight text-gray-900 dark:text-white">
        {gettext("Accept your invitation")}
      </h1>
      <p class="mb-6 text-sm text-gray-500 dark:text-gray-400">
        {gettext("Set up your account for %{email}.", email: to_string(@invitation.email))}
      </p>

      <.form :let={f} for={@form} phx-submit="accept" class="space-y-4">
        <div class="grid grid-cols-2 gap-3">
          <.input field={f[:first_name]} label={gettext("First name")} required />
          <.input field={f[:last_name]} label={gettext("Last name")} />
        </div>
        <.input
          field={f[:password]}
          type="password"
          label={gettext("Password")}
          autocomplete="new-password"
          required
        />
        <.input
          field={f[:password_confirmation]}
          type="password"
          label={gettext("Confirm password")}
          autocomplete="new-password"
          required
        />

        <.button type="submit" class="w-full" phx-disable-with={gettext("Setting up...")}>
          {gettext("Accept and create account")}
        </.button>
      </.form>
    </Layouts.auth_shell>
    """
  end

  @impl true
  def handle_event("accept", %{"signup" => params}, socket) do
    attrs = %{
      password: params["password"],
      password_confirmation: params["password_confirmation"],
      profile: %{
        first_name: params["first_name"],
        last_name: blank_to_nil(params["last_name"])
      }
    }

    case Membership.accept_invitation(socket.assigns.token, attrs) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Account created. Sign in to get started."))
         |> push_navigate(to: ~p"/sign-in")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error_message(reason))}
    end
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp error_message(%Ash.Error.Invalid{} = error), do: Exception.message(error)
  defp error_message(_), do: gettext("We couldn't complete your sign-up. Please try again.")
end
