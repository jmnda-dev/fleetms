defmodule FleetmsWeb.OrgLive.New do
  @moduledoc """
  Create a new organization. Shown when a user has no organization yet, or via
  "Create organization" from the picker/switcher. Renders without the dashboard
  shell — there is no tenant context yet.
  """
  use FleetmsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(
       socket,
       :form,
       to_form(%{"name" => "", "account_type" => "business"}, as: :organization)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.org_shell>
      <Layouts.flash_group flash={@flash} />

      <div class="mx-auto w-full max-w-md">
        <div class="rounded-xl border border-gray-200 bg-white p-8 shadow-sm dark:border-gray-700 dark:bg-gray-800">
          <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
            {gettext("Create your organization")}
          </h1>
          <p class="mt-2 text-sm text-gray-600 dark:text-gray-300">
            {gettext("An organization keeps your vehicles, team and records together.")}
          </p>

          <.form for={@form} phx-submit="create" class="mt-6 space-y-4">
            <.input
              field={@form[:name]}
              label={gettext("Organization name")}
              placeholder={gettext("e.g. Acme Logistics")}
              required
            />

            <div>
              <span class="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-200">
                {gettext("What is this for?")}
              </span>
              <div class="grid gap-3 sm:grid-cols-2">
                <.account_type_card
                  field={@form[:account_type]}
                  value="business"
                  icon="fa-building"
                  title={gettext("A business")}
                  description={gettext("A company or team, with members, roles and administration.")}
                />
                <.account_type_card
                  field={@form[:account_type]}
                  value="individual"
                  icon="fa-user"
                  title={gettext("Just me")}
                  description={gettext("Your own vehicles — a simpler, personal setup.")}
                />
              </div>
            </div>

            <.button variant="primary" class="w-full">{gettext("Create organization")}</.button>
          </.form>
        </div>

        <p class="mt-4 text-center text-sm text-gray-500 dark:text-gray-400">
          <.link navigate={~p"/orgs"} class="font-medium text-fg-brand hover:underline">
            {gettext("Back to your organizations")}
          </.link>
        </p>
      </div>
    </Layouts.org_shell>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :value, :string, required: true
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true

  defp account_type_card(assigns) do
    ~H"""
    <label class="block cursor-pointer">
      <input
        type="radio"
        name={@field.name}
        value={@value}
        checked={to_string(@field.value) == @value}
        class="peer sr-only"
      />
      <div class="h-full rounded-lg border border-gray-300 p-4 hover:border-gray-400 peer-checked:border-brand peer-checked:bg-brand-softer peer-checked:ring-1 peer-checked:ring-brand dark:border-gray-600 dark:hover:border-gray-500">
        <i class={["fa-solid text-lg text-fg-brand", @icon]}></i>
        <p class="mt-2 text-sm font-semibold text-gray-900 dark:text-white">{@title}</p>
        <p class="mt-1 text-xs text-gray-500 dark:text-gray-400">{@description}</p>
      </div>
    </label>
    """
  end

  @impl true
  def handle_event(
        "create",
        %{"organization" => %{"name" => name} = params},
        socket
      ) do
    user = socket.assigns.current_user
    account_type = params["account_type"] || "business"

    case Fleetms.Accounts.create_organization(
           name,
           %{owner_user_id: user.id, account_type: account_type},
           actor: user
         ) do
      {:ok, org} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Organization created."))
         |> push_navigate(to: ~p"/o/#{org}")}

      {:error, _error} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Could not create the organization. Try another name.")
         )}
    end
  end
end
