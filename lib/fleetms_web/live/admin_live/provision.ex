defmodule FleetmsWeb.AdminLive.Provision do
  @moduledoc """
  Platform admin: onboard a new managed-service client in one step.

  Creates the client's organization, records their KYC details, and invites the
  primary contact as a restricted `Client` member (staff run the org). See
  `Fleetms.Provisioning` for the orchestration and why the client is not an owner.
  """
  use FleetmsWeb, :live_view

  @business_type {"Business / corporate", "business"}
  @individual_type {"Individual (personal fleet)", "individual"}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: gettext("Provision a client"), account_types: account_types())
     |> assign_form(%{"account_type" => "business"})}
  end

  # "Individual" is only offered while the individual-registration workflow is on;
  # otherwise only businesses (each with their own org/schema) can be provisioned.
  defp account_types do
    if Fleetms.FeatureFlags.individual_registration?() do
      [@business_type, @individual_type]
    else
      [@business_type]
    end
  end

  @impl true
  def handle_event("validate", %{"provision" => params}, socket) do
    {:noreply, assign_form(socket, params)}
  end

  @impl true
  def handle_event("submit", %{"provision" => params}, socket) do
    case Fleetms.Provisioning.provision_client(params, socket.assigns.current_user) do
      {:ok, result} ->
        {:noreply,
         socket
         |> put_flash(:info, provisioned_message(result))
         |> push_navigate(to: ~p"/admin/organizations")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, error_message(reason))
         |> assign_form(params)}
    end
  end

  defp assign_form(socket, params) do
    socket
    |> assign(:individual?, params["account_type"] == "individual")
    |> assign(:form, to_form(params, as: :provision))
  end

  # Business client
  defp provisioned_message(%{organization: org, invite: {:invited, _}}) do
    gettext("%{name} is set up. An invitation was emailed to the client's contact.",
      name: org.name
    )
  end

  defp provisioned_message(%{organization: org, invite: {:added, _}}) do
    gettext("%{name} is set up. The existing account was added as the client.", name: org.name)
  end

  # Individual client (joins the shared pool; keyed on the person, not the org)
  defp provisioned_message(%{invite: {:account_created, client}}) do
    gettext(
      "Individual client %{email} is set up. They can set a password from the sign-in page whenever they want to log in.",
      email: client.email
    )
  end

  defp provisioned_message(%{invite: {:existing_account, client}}) do
    gettext("Individual client %{email} is set up (existing account).", email: client.email)
  end

  defp error_message({:required, :name}), do: gettext("An organization name is required.")
  defp error_message({:required, :client_email}), do: gettext("The client's email is required.")
  defp error_message({:required, :contact_name}), do: gettext("A contact name is required.")
  defp error_message(:client_role_missing), do: gettext("Could not find the Client role for the new organization.")
  defp error_message(:forbidden), do: gettext("You don't have access to provision clients.")

  defp error_message(:individual_registration_disabled),
    do: gettext("Individual client registration is currently disabled.")
  defp error_message(_), do: gettext("Something went wrong while provisioning the client.")

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin_shell active={:organizations}>
      <Layouts.flash_group flash={@flash} />

      <div class="mx-auto max-w-2xl">
        <.header>
          {gettext("Provision a client")}
          <:subtitle>
            {gettext(
              "Create the organization, capture KYC details, and invite the client's contact as a restricted member."
            )}
          </:subtitle>
        </.header>

        <.form
          for={@form}
          id="provision-form"
          phx-change="validate"
          phx-submit="submit"
          class="mt-6 space-y-8"
        >
          <section class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800">
            <h2 class="mb-4 text-sm font-semibold text-heading">{gettext("Account")}</h2>
            <div class="space-y-4">
              <.input
                field={@form[:account_type]}
                type="select"
                label={gettext("Account type")}
                options={@account_types}
              />
              <%!-- Individuals join the shared pool, so they don't name an organization. --%>
              <.input
                :if={!@individual?}
                field={@form[:name]}
                label={gettext("Organization name")}
                required
              />
              <p :if={@individual?} class="text-xs text-body">
                {gettext("Individual clients are added to the managed individuals space.")}
              </p>
            </div>
          </section>

          <section class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800">
            <h2 class="mb-1 text-sm font-semibold text-heading">{gettext("Client contact")}</h2>
            <p class="mb-4 text-xs text-body">
              {gettext(
                "They receive an invitation to set a password and sign in with the restricted Client role."
              )}
            </p>
            <div class="space-y-4">
              <.input
                field={@form[:client_email]}
                type="email"
                label={gettext("Login email (invitation is sent here)")}
                required
              />
              <.input field={@form[:contact_name]} label={gettext("Contact name")} required />
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <.input
                  field={@form[:contact_email]}
                  type="email"
                  label={gettext("Contact email (if different)")}
                />
                <.input field={@form[:contact_phone]} label={gettext("Contact phone")} />
              </div>
            </div>
          </section>

          <section class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800">
            <h2 class="mb-4 text-sm font-semibold text-heading">{gettext("KYC details")}</h2>
            <div class="space-y-4">
              <.input field={@form[:address]} label={gettext("Address")} />
              <.input
                field={@form[:reg_number]}
                label={gettext("Registration number / national ID")}
              />
              <.input field={@form[:notes]} type="textarea" label={gettext("Notes")} />
            </div>
          </section>

          <div class="flex items-center justify-end gap-3">
            <.button navigate={~p"/admin/organizations"} variant="secondary">
              {gettext("Cancel")}
            </.button>
            <.button type="submit" phx-disable-with={gettext("Provisioning…")}>
              {gettext("Provision client")}
            </.button>
          </div>
        </.form>
      </div>
    </Layouts.admin_shell>
    """
  end
end
