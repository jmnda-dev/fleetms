defmodule FleetmsWeb.WorkOrderLive.FilterFormComponent do
  use FleetmsWeb, :live_component
  import Fleetms.Utils, only: [dates_in_map_to_string: 2]

  alias Fleetms.Accounts
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
            <div class="w-full" id="vehicles-select" phx-update="ignore">
              <.input
                field={@filter_form[:vehicles]}
                options={@vehicles}
                type="select"
                label="Vehicles"
                multiple
                phx-hook="select2JS"
                style="width: 100%;"
                value={@filter_form.source.changes[:vehicles] || @filter_form.data[:vehicles]}
              />
            </div>

            <div class="w-full" id="assigned_to-select" phx-update="ignore">
              <.input
                field={@filter_form[:assigned_to]}
                options={@users}
                type="select"
                label="Assigned To"
                multiple
                phx-hook="select2JS"
                style="width: 100%;"
                value={@filter_form.source.changes[:assigned_to] || @filter_form.data[:assigned_to]}
              />
            </div>

            <div class="w-full" id="issued_by-select" phx-update="ignore">
              <.input
                field={@filter_form[:issued_by]}
                options={@users}
                type="select"
                label="Issued By"
                multiple
                phx-hook="select2JS"
                style="width: 100%;"
                value={@filter_form.source.changes[:issued_by] || @filter_form.data[:issued_by]}
              />
            </div>

            <div class="w-full" id="statuses-select" phx-update="ignore">
              <.input
                field={@filter_form[:statuses]}
                options={Fleetms.Enums.work_order_statuses() ++ [:All]}
                type="select"
                label="Statuses"
                multiple
                phx-hook="select2JS"
                style="width: 100%;"
                value={@filter_form.source.changes[:statuses] || @filter_form.data[:statuses]}
              />
            </div>

            <div class="w-full" id="repair_categories-select" phx-update="ignore">
              <.input
                field={@filter_form[:repair_categories]}
                options={Fleetms.Enums.repair_categories() ++ [:All]}
                type="select"
                label="Repair Categories"
                multiple
                phx-hook="select2JS"
                style="width: 100%;"
                value={
                  @filter_form.source.changes[:repair_categories] ||
                    @filter_form.data[:repair_categories]
                }
              />
            </div>
          </div>
          <div class="grid gap-6 md:grid-cols-2">
            <div class="w-full">
              <.input
                field={@filter_form[:date_and_time_issued_from]}
                type="date"
                label="Date and Time Issued From"
                value={
                  @filter_form.source.changes[:date_and_time_issued_from] ||
                    @filter_form.data[:date_and_time_issued_from]
                }
              />
            </div>

            <div class="w-full">
              <.input
                field={@filter_form[:date_and_time_issued_to]}
                type="date"
                label="Date and Time Issued To"
                value={
                  @filter_form.source.changes[:date_and_time_issued_to] ||
                    @filter_form.data[:date_and_time_issued_to]
                }
              />
            </div>

            <div class="w-full">
              <.input
                field={@filter_form[:date_and_time_started_from]}
                type="date"
                label="Date and Time Started From"
                value={
                  @filter_form.source.changes[:date_and_time_started_from] ||
                    @filter_form.data[:date_and_time_started_from]
                }
              />
            </div>

            <div class="w-full">
              <.input
                field={@filter_form[:date_and_time_started_to]}
                type="date"
                label="Date and Time Started To"
                value={
                  @filter_form.source.changes[:date_and_time_started_to] ||
                    @filter_form.data[:date_and_time_started_to]
                }
              />
            </div>

            <div class="w-full">
              <.input
                field={@filter_form[:date_and_time_completed_from]}
                type="date"
                label="Date and Time Completed From"
                value={
                  @filter_form.source.changes[:date_and_time_completed_from] ||
                    @filter_form.data[:date_and_time_completed_from]
                }
              />
            </div>

            <div class="w-full">
              <.input
                field={@filter_form[:date_and_time_completed_to]}
                type="date"
                label="Date and Time Completed To"
                value={
                  @filter_form.source.changes[:date_and_time_completed_to] ||
                    @filter_form.data[:date_and_time_completed_to]
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
    socket = assign(socket, assigns)
    %{tenant: tenant, current_user: actor} = socket.assigns

    filter_form =
      build_filter_changeset(assigns.filter_form_data, %{})
      |> to_form(as: "filter_form")

    vehicles =
      Fleetms.Vehicles.Vehicle.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.full_name, &1.id})

    users =
      Accounts.get_all_users!(tenant: tenant, actor: actor)
      |> Ash.load!([user_profile: [:full_name]], tenant: tenant, actor: actor)
      |> Enum.map(&{&1.user_profile.full_name, &1.id})

    socket =
      socket
      |> assign(:filter_form, filter_form)
      |> assign(:vehicles, vehicles)
      |> assign(:users, users)

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
          |> dates_in_map_to_string([
            :date_and_time_issued_from,
            :date_and_time_issued_to,
            :date_and_time_started_from,
            :date_and_time_started_to,
            :date_and_time_completed_from,
            :date_and_time_completed_to
          ])
          |> Map.merge(socket.assigns.paginate_sort_opts)
          |> Map.merge(socket.assigns.search_params)

        {:noreply, push_patch(socket, to: ~p"/work_orders?#{new_url_params}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :filter_form, changeset |> to_form(as: "filter_form"))}
    end
  end

  def build_filter_changeset(data, submit_params) do
    types = %{
      vehicles: {:array, :string},
      assigned_to: {:array, :string},
      issued_by: {:array, :string},
      statuses:
        {:array,
         Ecto.ParameterizedType.init(Ecto.Enum,
           values: Fleetms.Enums.work_order_statuses() ++ [:All]
         )},
      repair_categories:
        {:array,
         Ecto.ParameterizedType.init(Ecto.Enum,
           values: Fleetms.Enums.repair_categories() ++ [:All]
         )},
      date_and_time_issued_from: :date,
      date_and_time_issued_to: :date,
      date_and_time_started_from: :date,
      date_and_time_started_to: :date,
      date_and_time_completed_from: :date,
      date_and_time_completed_to: :date
    }

    changeset =
      {data, types}
      |> Ecto.Changeset.cast(submit_params, Map.keys(types))

    date_fields = [
      {:date_and_time_issued_from, :date_and_time_issued_to},
      {:date_and_time_started_from, :date_and_time_started_to},
      {:date_and_time_completed_from, :date_and_time_completed_to}
    ]

    Enum.reduce(date_fields, changeset, fn field_pair, changeset ->
      validate_date_range(changeset, field_pair)
    end)
  end

  defp validate_date_range(changeset, {field_from, field_to}) do
    date_from = Ecto.Changeset.get_change(changeset, field_from)
    date_to = Ecto.Changeset.get_change(changeset, field_to)

    if not is_nil(date_to) and not is_nil(date_from) and Date.compare(date_from, date_to) == :gt do
      Ecto.Changeset.add_error(
        changeset,
        field_from,
        "Date From must be less that Date To"
      )
    else
      changeset
    end
  end
end
