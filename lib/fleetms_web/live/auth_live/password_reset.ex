defmodule FleetmsWeb.AuthLive.PasswordReset do
  use FleetmsWeb, :live_view

  import Phoenix.HTML.Form

  def render(assigns) do
    ~H"""
    <section class="bg-gray-50 dark:bg-gray-900">
      <div class="grid max-w-screen-xl px-4 py-8 mx-auto lg:gap-20 lg:py-16 lg:grid-cols-12">
        <div class="w-full place-self-center lg:col-span-6">
          <div class="p-6 mx-auto bg-white rounded-lg shadow dark:bg-gray-800 sm:max-w-xl sm:p-8">
            <a
              href="#"
              class="inline-flex items-center mb-4 text-xl font-semibold text-gray-900 dark:text-white"
            >
              <img class="dark:hidden h-12 mr-2" src="/images/logo_light.svg" alt="Fleetms" />
              <img class="hidden dark:block h-12 mr-2" src="/images/logo_dark.svg" alt="Fleetms" />
            </a>
            <h1 class="mb-1 text-xl font-bold leading-tight tracking-tight text-gray-900 sm:text-2xl dark:text-white">
              Create new password
            </h1>
            <p class="font-light text-gray-500 dark:text-gray-400">
              Your new password must be different from previous used passwords.
            </p>
            <.simple_form
              for={@form}
              phx-change="change"
              phx-submit="submit"
              phx-trigger-action={@trigger_action}
              action={~p"/auth/user/password/reset"}
              method="POST"
              class="mt-4 space-y-4 md:space-y-5 lg:mt-5"
            >
              <.input type="hidden" field={@form[:reset_token]} value={@token} />
              <div>
                <.input
                  type="password"
                  field={@form[:password]}
                  value={input_value(@form, :password)}
                  placeholder="Password"
                />
              </div>
              <div>
                <.input
                  type="password"
                  field={@form[:password_confirmation]}
                  value={input_value(@form, :password_confirmation)}
                  placeholder="Password confirmation"
                />
              </div>
              <.button type="submit" phx-disable-with="Reseting...">Reset Password</.button>
              <p class="text-sm text-center text-gray-500 dark:text-gray-400">
                If you still need help, contact <a
                  href="#"
                  class="font-medium text-primary-600 dark:text-primary-500 hover:underline"
                >Flowbite support</a>.
              </p>
            </.simple_form>
          </div>
        </div>
        <div class="mr-auto place-self-center lg:col-span-6">
          <img
            class="hidden mx-auto lg:flex"
            src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/authentication/illustration.svg"
            alt="illustration"
          />
        </div>
      </div>
    </section>
    """
  end

  def mount(_params, _session, socket) do
    form =
      AshPhoenix.Form.for_action(Fleetms.Accounts.User, :password_reset_with_password,
        domain: Fleetms.Accounts,
        as: "user"
      )
      |> to_form()

    {:ok, assign(socket, form: form, trigger_action: false)}
  end

  def handle_params(%{"token" => token}, _uri, socket) do
    {:noreply, assign(socket, token: token)}
  end

  def handle_event("change", %{"user" => user_params}, socket) do
    %{form: form} = socket.assigns

    form = AshPhoenix.Form.validate(form, user_params)

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("submit", %{"user" => user_params}, socket) do
    %{form: form} = socket.assigns

    socket =
      case AshPhoenix.Form.submit(form, params: user_params) do
        {:ok, _} ->
          socket
          |> assign(form: form, trigger_action: true)

        {:error, form} ->
          socket
          |> assign(form: form, trigger_action: true)
          |> maybe_show_token_error()
      end

    {:noreply, socket}
  end

  defp maybe_show_token_error(socket) do
    %{form: form} = socket.assigns

    case form |> AshPhoenix.Form.errors() |> Enum.find(fn {:reset_token, _} -> true end) do
      nil -> socket
      {_, error_message} -> put_flash(socket, :error, "Reset token #{error_message}")
    end
  end
end
