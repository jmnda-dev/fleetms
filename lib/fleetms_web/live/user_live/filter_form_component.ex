defmodule FleetmsWeb.UserLive.FilterFormComponent do
  use FleetmsWeb, :live_component
  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
      </.header>
      <.simple_form
        for={@filter_form}
        id="filter-form"
        phx-change="validate"
        phx-submit="apply"
        phx-target={@myself}
        tabindex="-1"
        aria-hidden="true"
      >
        <div class="px-4 space-y-4 md:px-6">
          <div class="grid gap-6 md:grid-cols-2">
            <div class="w-full" id="roles-select" phx-update="ignore">
              <.input
                field={@filter_form[:roles]}
                options={Fleetms.Enums.basic_user_roles()}
                type="select"
                label="Roles"
                multiple
                phx-hook="select2JS"
                style="width: 100%;"
                value={
                  @filter_form.source.changes[:roles] ||
                    @filter_form.data[:roles]
                }
              />
            </div>

            <div class="w-full" id="status-select" phx-update="ignore">
              <.input
                field={@filter_form[:status]}
                options={Fleetms.Enums.user_statuses()}
                type="select"
                label="Status"
                multiple
                phx-hook="select2JS"
                style="width: 100%;"
                value={
                  @filter_form.source.changes[:status] ||
                    @filter_form.data[:status]
                }
              />
            </div>
          </div>
        </div>
        <!-- Modal footer -->
        <div class="flex items-center p-6 space-x-4 rounded-b dark:border-gray-600">
          <.button type="submit">
            Apply
          </.button>
          <.button type="reset">
            Reset
          </.button>
        </div>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    filter_form =
      build_filter_changeset(assigns.filter_form_data, %{})
      |> to_form(as: "filter_form")

    socket =
      assign(socket, assigns)
      |> assign(:filter_form, filter_form)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"filter_form" => form_params}, socket) do
    filter_form =
      build_filter_changeset(socket.assigns.filter_form_data, form_params)
      |> Map.put(:action, :validate)
      |> to_form(as: "filter_form")

    {:noreply, assign(socket, :filter_form, filter_form)}
  end

  @impl true
  def handle_event("apply", %{"filter_form" => form_params}, socket) do
    build_filter_changeset(%{}, form_params)
    |> Ecto.Changeset.apply_action(:create)
    |> case do
      {:ok, new_filter_form_data} ->
        new_url_params =
          new_filter_form_data
          |> Map.merge(socket.assigns.paginate_sort_opts)
          |> Map.merge(socket.assigns.search_params)

        {:noreply, push_patch(socket, to: ~p"/users?#{new_url_params}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :filter_form, changeset |> to_form(as: "filter_form"))}
    end
  end

  @impl true
  def handle_event(event, params, socket) do
    Logger.warning("Unhandled event: #{inspect(event)}, Params: #{inspect(params)}")

    new_url_params =
      Map.merge(socket.assigns.paginate_sort_opts, socket.assigns.search_params)

    {:noreply, push_patch(socket, to: ~p"/users?#{new_url_params}")}
  end

  def build_filter_changeset(data, submit_params) do
    types = %{
      roles: {:array, Ecto.ParameterizedType.init(Ecto.Enum, values: Fleetms.Enums.basic_user_roles())},
      status:
        {:array, Ecto.ParameterizedType.init(Ecto.Enum, values: Fleetms.Enums.user_statuses())}
    }

    {data, types}
    |> Ecto.Changeset.cast(submit_params, Map.keys(types))
  end
end
