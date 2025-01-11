defmodule FleetmsWeb.AuthLive.RequestPasswordReset do
  use FleetmsWeb, :live_view

  def mount(_params, _session, socket) do
    form = blank_form()

    {:ok, assign(socket, form: form, trigger_action: false)}
  end

  def render(assigns) do
    ~H"""
    <section class="bg-gray-50 dark:bg-gray-900">
      <div class="flex flex-col items-center justify-center px-6 py-8 mx-auto md:h-screen lg:py-0">
        <a
          href="#"
          class="flex items-center mb-6 text-2xl font-semibold text-gray-900 dark:text-white"
        >
          <img class="dark:hidden h-12 mr-2" src="/images/logo_light.svg" alt="Fleetms" />
          <img class="hidden dark:block h-12 mr-2" src="/images/logo_dark.svg" alt="Fleetms" />
        </a>
        <div class="w-full p-6 bg-white rounded-lg shadow dark:border md:mt-0 sm:max-w-md dark:bg-gray-800 dark:border-gray-700 sm:p-8">
          <h2 class="mb-1 text-xl font-bold leading-tight tracking-tight text-gray-900 md:text-2xl dark:text-white">
            Request Password Reset
          </h2>
          <.simple_form
            for={@form}
            phx-change="change"
            phx-submit="submit"
            phx-trigger-action={@trigger_action}
            action={~p"/auth/user/password/reset_request"}
            method="POST"
            class="mt-4 space-y-4 lg:mt-5 md:space-y-5"
          >
            <div>
              <.input field={@form[:email]} type="email" label="Email" placeholder="Enter your email" />
            </div>
            <.button type="submit" phx-disable-with="Requesting...">
              Request Password Reset
            </.button>
          </.simple_form>
        </div>
      </div>
    </section>
    """
  end

  def handle_event("change", %{"user" => user_params}, socket) do
    %{form: form} = socket.assigns

    form = AshPhoenix.Form.validate(form, user_params, errors: false)

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("submit", %{"user" => user_params}, socket) do
    result =
      socket.assigns.form
      |> AshPhoenix.Form.validate(user_params)
      |> AshPhoenix.Form.submit()

    socket =
      case result do
        {:ok, _} ->
          socket
          |> put_toast(:info, "Password reset request sent")
          |> assign(form: blank_form(), trigger_action: true)

        {:error, _} ->
          socket
          |> put_toast(:error, "Password reset request failed")
          |> assign(form: blank_form(), trigger_action: false)
      end

    {:noreply, socket}
  end

  defp blank_form do
    AshPhoenix.Form.for_action(Fleetms.Accounts.User, :request_password_reset_with_password,
      domain: Fleetms.Accounts,
      as: "user"
    )
    |> to_form()
  end
end
