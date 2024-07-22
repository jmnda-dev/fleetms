defmodule Fleetms.Service.WorkOrder do
  use Ash.Resource,
    domain: Fleetms.Service,
    data_layer: AshPostgres.DataLayer,
    authorizers: [
      Ash.Policy.Authorizer
    ]

  # TODO: In the future, allow users to create a completed work order, meaning they can select status, date and time completed, then
  # the added line items e.g issues, service reminders will be resolved and reset respectively

  alias Fleetms.Accounts.User.Policies.{IsAdmin, IsFleetManager, IsTechnician}
  require Ash.Query

  @default_listing_limit 20
  @default_sorting_params %{sort_by: :desc, sort_order: :created_at}
  @default_paginate_params %{page: 1, per_page: @default_listing_limit}

  attributes do
    uuid_primary_key :id

    attribute :work_order_number, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 999_999_999

      description "The work order number is a unique number that is generated for each work order. It is used to identify a work order."

      writable? false
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:Open, :Pending, :Completed]
      writable? false
    end

    attribute :description, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 2000
    end

    attribute :comments, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 2000
    end

    attribute :start_mileage, :decimal do
      allow_nil? true
      public? true
      constraints min: 0, max: 999_999_999
    end

    attribute :start_hours, :decimal do
      allow_nil? true
      public? true
      constraints min: 0, max: 999_999_999
    end

    attribute :repair_category, :atom do
      allow_nil? true
      public? true
      constraints one_of: Fleetms.Enums.repair_categories()
    end

    attribute :date_and_time_issued, :utc_datetime do
      allow_nil? false
      public? true
      default fn -> DateTime.utc_now() end
    end

    attribute :date_and_time_started, :utc_datetime do
      allow_nil? true
      public? true
    end

    attribute :date_and_time_completed, :utc_datetime do
      allow_nil? true
      public? true
    end

    attribute :documents, {:array, Fleetms.Service.WorkOrderDocument} do
      allow_nil? true
      public? true
    end

    attribute :labels, {:array, :string} do
      allow_nil? true
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :vehicle, Fleetms.Vehicles.Vehicle do
      domain Fleetms.Vehicles
      allow_nil? false
    end

    belongs_to :assigned_to, Fleetms.Accounts.User do
      domain Fleetms.Accounts
      allow_nil? true
      source_attribute :assigned_to_id
      destination_attribute :id
    end

    belongs_to :issued_by, Fleetms.Accounts.User do
      domain Fleetms.Accounts
      allow_nil? false
      source_attribute :issued_by_id
      destination_attribute :id
    end

    has_many :issues, Fleetms.Issues.Issue do
      domain Fleetms.Issues
    end

    has_many :work_order_photos, Fleetms.Service.WorkOrderPhoto

    has_many :service_reminder_history, Fleetms.Service.ServiceReminderHistory

    many_to_many :service_tasks, Fleetms.Service.ServiceTask do
      through Fleetms.Service.WorkOrderServiceTask
      join_relationship :work_order_service_tasks
      source_attribute_on_join_resource :work_order_id
      destination_attribute_on_join_resource :service_task_id
    end
  end

  policies do
    policy action_type(:action) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action(:create) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
      authorize_if IsTechnician
    end

    policy action(:update) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
      authorize_if relates_to_actor_via(:assigned_to)
    end

    policy action(:complete_work_order) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
      authorize_if relates_to_actor_via(:assigned_to)
    end

    policy action([:save_work_order_photos, :maybe_delete_existing_photos]) do
      authorize_if always()
    end

    policy action(:reopen_work_order) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
    end

    policy action(:destroy) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
    end
  end

  postgres do
    table "work_orders"
    repo Fleetms.Repo
  end

  actions do
    defaults [:read]

    action :validate_sorting_params, :map do
      description "Validates the Sorting params from the URL e.g /?sort_by=name&sort_order=desc"
      argument :url_params, :map, allow_nil?: false

      run fn input, _context ->
        params =
          %{
            sort_order: Map.get(input.arguments.url_params, "sort_order", "desc"),
            sort_by: Map.get(input.arguments.url_params, "sort_by", "updated_at")
          }

        types = %{
          sort_order:
            Ecto.ParameterizedType.init(Ecto.Enum, values: [asc: "Ascending", desc: "Descending"]),
          sort_by:
            Ecto.ParameterizedType.init(Ecto.Enum,
              values: [
                created_at: "Date Created",
                updated_at: "Date Updated",
                date_and_time_issued: "Date Issued",
                date_and_time_started: "Date Started",
                date_and_time_completed: "Date Completed",
                status: "Status",
                count_of_service_tasks: "Number of Service Tasks",
                repair_category: "Repair Category"
              ]
            )
        }

        data = %{}

        {data, types}
        |> Ecto.Changeset.cast(params, Map.keys(types))
        |> Ecto.Changeset.apply_action(:create)
        |> case do
          {:ok, sort_params} ->
            {:ok, sort_params}

          {:error, changeset} ->
            {:ok, @default_sorting_params}
        end
      end
    end

    action :validate_pagination_params, :map do
      description "Validates the Pagination params from the URL e.g /?page=1&per_page=10"
      argument :url_params, :map, allow_nil?: false

      run fn input, _context ->
        params =
          %{
            page: Map.get(input.arguments.url_params, "page", 1),
            per_page: Map.get(input.arguments.url_params, "per_page", @default_listing_limit)
          }

        types = %{
          page: :integer,
          per_page: :integer
        }

        data = %{}

        {data, types}
        |> Ecto.Changeset.cast(params, Map.keys(types))
        |> Ecto.Changeset.apply_action(:create)
        |> case do
          {:ok, paginate_params} ->
            {:ok, paginate_params}

          {:error, _changeset} ->
            {:ok, @default_paginate_params}
        end
      end
    end

    action :get_dashboard_stats, :map do
      import Ecto.Query

      argument :tenant, :string, allow_nil?: false

      run fn input, _context ->
        tenant = input.arguments.tenant

        {:ok, work_order_ecto_query} =
          Fleetms.Service.WorkOrder
          |> Ash.Query.set_tenant(tenant)
          |> Ash.Query.data_layer_query()

        status_counts_query =
          from w in subquery(work_order_ecto_query),
            select: %{
              total: count(w.id, :distinct),
              open: count(w.id, :distinct) |> filter(w.status == :Open),
              completed: count(w.id, :distinct) |> filter(w.status == :Completed)
            }

        {:ok, Fleetms.Repo.one(status_counts_query)}
      end
    end

    create :create do
      primary? true
      accept :*

      argument :work_order_service_tasks, {:array, :map}
      argument :issues, {:array, :map}

      argument :vehicle_id, :uuid do
        allow_nil? false
      end

      argument :assigned_to_id, :uuid do
        allow_nil? true
      end

      argument :issued_by_id, :uuid do
        allow_nil? false
      end

      argument :photos, {:array, :map} do
        allow_nil? true
      end

      argument :documents, {:array, :map} do
        allow_nil? true
      end

      argument :labels, {:array, :string} do
        allow_nil? true
      end

      change manage_relationship(:vehicle_id, :vehicle, type: :append_and_remove)
      change manage_relationship(:assigned_to_id, :assigned_to, type: :append_and_remove)
      change manage_relationship(:issued_by_id, :issued_by, type: :append_and_remove)
      change manage_relationship(:work_order_service_tasks, type: :direct_control)

      change manage_relationship(:issues,
               on_lookup: {:relate, :update_from_work_order},
               on_no_match: :error,
               on_match: :ignore,
               on_missing: {:unrelate, :update_from_work_order}
             )

      change fn changeset, _context ->
        Ash.Changeset.force_change_attribute(changeset, :status, :Open)
      end

      change Fleetms.Service.WorkOrder.Changes.SetWorkOrderNumber do
        only_when_valid? true
      end
    end

    update :update do
      require_atomic? false
      primary? true
      accept :*

      argument :work_order_service_tasks, {:array, :map}
      argument :issues, {:array, :map}

      argument :vehicle_id, :uuid do
        allow_nil? false
      end

      argument :assigned_to_id, :uuid do
        allow_nil? true
      end

      argument :issued_by_id, :uuid do
        allow_nil? false
      end

      argument :photos, {:array, :map} do
        allow_nil? true
      end

      argument :documents, {:array, :map} do
        allow_nil? true
      end

      argument :labels, {:array, :string} do
        allow_nil? true
      end

      change manage_relationship(:vehicle_id, :vehicle, type: :append_and_remove)
      change manage_relationship(:assigned_to_id, :assigned_to, type: :append_and_remove)
      change manage_relationship(:issued_by_id, :issued_by, type: :append_and_remove)
      change manage_relationship(:work_order_service_tasks, type: :direct_control)

      change manage_relationship(:issues,
               on_lookup: {:relate, :update_from_work_order},
               on_no_match: :error,
               on_match: :ignore,
               on_missing: {:unrelate, :update_from_work_order}
             )
    end

    update :complete_work_order do
      require_atomic? false
      accept [:status]

      change fn changeset, _context ->
        Ash.Changeset.force_change_attribute(changeset, :status, :Completed)
        |> Ash.Changeset.force_change_attribute(:date_and_time_completed, DateTime.utc_now())
      end

      change fn changeset, _context ->
        Ash.Changeset.after_action(changeset, fn changeset, work_order ->
          resolve_issues(changeset)
          reset_service_reminders(changeset)
          update_inventory(changeset)
          {:ok, work_order}
        end)
      end
    end

    update :reopen_work_order do
      require_atomic? false

      change fn changeset, _context ->
        work_order_id = Ash.Changeset.get_data(changeset, :id)

        issues =
          Ash.Changeset.get_data(changeset, :issues)
          |> Enum.map(&%{work_order_id: work_order_id, id: &1.id})

        Ash.Changeset.force_change_attribute(changeset, :status, :Open)
        |> Ash.Changeset.force_change_attribute(:date_and_time_completed, nil)
        |> Ash.Changeset.manage_relationship(:issues, issues,
          on_lookup: :ignore,
          on_match: {:update, :update_from_work_order_reopen}
        )
      end

      change Fleetms.Service.WorkOrder.Changes.RestoreServiceReminders do
        only_when_valid? true
      end
    end

    update :save_work_order_photos do
      require_atomic? false
      argument :work_order_photos, {:array, :map}, allow_nil?: false

      change manage_relationship(:work_order_photos, type: :direct_control)
    end

    read :list do
      pagination offset?: true, default_limit: 50, countable: true

      argument :paginate_sort_opts, :map, allow_nil?: false
      argument :search_query, :string, default: ""
      argument :advanced_filter_params, :map, default: %{}

      prepare fn query, _context ->
        %{sort_order: sort_order, sort_by: sort_by} =
          query.arguments.paginate_sort_opts

        search_query = Ash.Query.get_argument(query, :search_query)
        advanced_filter_params = Ash.Query.get_argument(query, :advanced_filter_params)

        query =
          Enum.reduce(advanced_filter_params, query, fn
            {_, nil}, accumulated_query ->
              accumulated_query

            {_, []}, accumulated_query ->
              accumulated_query

            {_, "All"}, accumulated_query ->
              accumulated_query

            {_, :All}, accumulated_query ->
              accumulated_query

            {:vehicles, vehicle_ids}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(vehicle_id in ^vehicle_ids))

            {:assigned_to, assigned_to_ids}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(assigned_to_id in ^assigned_to_ids))

            {:issued_by, issued_by_ids}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(issued_by_id in ^issued_by_ids))

            {:statuses, statuses}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(status in ^statuses))

            {:repair_categories, repair_categories}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(repair_category in ^repair_categories))

            {:date_and_time_issued_from, date_and_time_issued_from}, accumulated_query ->
              Ash.Query.filter(
                accumulated_query,
                expr(date_and_time_issued >= ^date_and_time_issued_from)
              )

            {:date_and_time_issued_to, date_and_time_issued_to}, accumulated_query ->
              Ash.Query.filter(
                accumulated_query,
                expr(date_and_time_issued <= ^date_and_time_issued_to)
              )

            {:date_and_time_started_from, date_and_time_started_from}, accumulated_query ->
              Ash.Query.filter(
                accumulated_query,
                expr(date_and_time_started >= ^date_and_time_started_from)
              )

            {:date_and_time_started_to, date_and_time_started_to}, accumulated_query ->
              Ash.Query.filter(
                accumulated_query,
                expr(date_and_time_started <= ^date_and_time_started_to)
              )

            {:date_and_time_completed_from, date_and_time_completed_from}, accumulated_query ->
              Ash.Query.filter(
                accumulated_query,
                expr(date_and_time_completed >= ^date_and_time_completed_from)
              )

            {:date_and_time_completed_to, date_and_time_completed_to}, accumulated_query ->
              Ash.Query.filter(
                accumulated_query,
                expr(date_and_time_completed <= ^date_and_time_completed_to)
              )
          end)
          |> Ash.Query.sort([{sort_by, sort_order}])
          |> Ash.Query.load([
            :count_of_service_tasks,
            vehicle: [:full_name],
            issued_by: [user_profile: [:full_name]],
            assigned_to: [user_profile: [:full_name]]
          ])

        if search_query == "" or is_nil(search_query) do
          query
        else
          Ash.Query.filter(
            query,
            expr(
              trigram_similarity(vehicle.name, ^search_query) > 0.1 or
                trigram_similarity(vehicle.vehicle_model.name, ^search_query) > 0.1 or
                trigram_similarity(vehicle.vehicle_model.vehicle_make.name, ^search_query) > 0.1 or
                trigram_similarity(status, ^search_query) > 0.3 or
                trigram_similarity(repair_category, ^search_query) > 0.3 or
                trigram_similarity(assigned_to.user_profile.first_name, ^search_query) > 0.3 or
                trigram_similarity(assigned_to.user_profile.last_name, ^search_query) > 0.3 or
                trigram_similarity(issued_by.user_profile.first_name, ^search_query) > 0.3 or
                trigram_similarity(issued_by.user_profile.last_name, ^search_query) > 0.3 or
                trigram_similarity(description, ^search_query) > 0.3 or
                trigram_similarity(comments, ^search_query) > 0.3
            )
          )
        end
      end
    end

    read :list_vehicle_work_orders do
      argument :vehicle_id, :uuid
      pagination offset?: true, default_limit: 20, countable: true

      prepare build(
                load: [
                  :count_of_service_tasks,
                  issued_by: [user_profile: [:full_name]]
                ]
              )
    end

    read :get_by_id do
      argument :id, :uuid, allow_nil?: false

      filter expr(id == ^arg(:id))

      prepare build(
                load: [
                  :issues,
                  :work_order_photos,
                  :total_cost_parts,
                  vehicle: [:full_name],
                  assigned_to: [user_profile: [:full_name]],
                  issued_by: [user_profile: [:full_name]],
                  work_order_service_tasks: [
                    :service_task,
                    :service_reminder,
                    :total_parts,
                    :total_cost_parts,
                    :total_cost_labor,
                    work_order_service_task_parts: [
                      :inventory_location,
                      part: [:part_manufacturer]
                    ],
                    work_order_service_task_technician_labor_details: [
                      technician: [:user_profile]
                    ],
                    work_order_service_task_vendor_labor_details: [:vendor]
                  ]
                ]
              )
    end

    update :maybe_delete_existing_photos do
      require_atomic? false
      argument :current_photos, {:array, :map}, allow_nil?: false

      change manage_relationship(:current_photos, :work_order_photos, type: :direct_control)
    end

    destroy :destroy do
      primary? true

      change fn changeset, _context ->
        Ash.Changeset.after_action(changeset, fn changeset, deleted_work_order ->
          # Here, I access photos to delete by calling `deleted_work_order.work_order_photos` because `work_order_photos` relationship is already loaded when the
          # WorkOrder to delete was queried with `get_by_id/1` and passed to `Ash.destroy` in the FleetmsWeb.WorkOrderLive.Index LiveView.
          # If calling this action from somewhere else, make sure `work_order_photos` is loaded otherwise this action will fail.
          Enum.map(deleted_work_order.work_order_photos, fn
            work_order_photo ->
              Fleetms.WorkOrderPhoto.delete({work_order_photo.filename, deleted_work_order})
          end)

          {:ok, deleted_work_order}
        end)
      end
    end
  end

  aggregates do
    count :count_of_service_tasks, :service_tasks

    sum :total_cost_parts,
        [:work_order_service_tasks, :work_order_service_task_parts],
        :subtotal do
      default "0.0"
    end
  end

  code_interface do
    define :get_by_id, action: :get_by_id, args: [:id], get?: true
    define :validate_sorting_params, action: :validate_sorting_params, args: [:url_params]
    define :validate_pagination_params, action: :validate_pagination_params, args: [:url_params]
    define :get_dashboard_stats, action: :get_dashboard_stats, args: [:tenant]
  end

  multitenancy do
    strategy :context
  end

  def resolve_issues(work_order_changeset) do
    work_order_id = Ash.Changeset.get_data(work_order_changeset, :id)

    Ash.Changeset.get_data(work_order_changeset, :issues)
    |> Enum.map(fn issue ->
      params = %{date_resolved: Date.utc_today(), work_order_id: work_order_id}

      issue
      |> Ash.Changeset.for_update(:resolve_from_work_order, params)
      |> Ash.update!()
    end)

  end

  def reset_service_reminders(changeset) do

    reminders =
      Ash.Changeset.get_data(changeset, :work_order_service_tasks)
      |> Stream.filter(&(not is_nil(&1.service_reminder)))
      |> Enum.map(& &1.service_reminder)

    work_order_id =
      Ash.Changeset.get_data(changeset, :id)

    # TODO: Revisit this implememtation. Handle cases where interval is nil
    # Also save the reminder to service history
    Enum.map(reminders, fn reminder ->
      reset_reminder(reminder, work_order_id, changeset.tenant)
    end)

  end

  @doc """
  Reset a service reminder. We pattern match to call the appropriate function to reset the servce reminder.
  """
  def reset_reminder(reminder, work_order_id, tenant) do
    reminder
    # We create the history before resetting the reminder
    |> create_reminder_history(work_order_id, tenant)
    |> Ash.Changeset.for_update(:update_by_work_order_completion)
    |> Ash.update!(tenant: tenant)
  end

  defp create_reminder_history(reminder, work_order_id, tenant) do
    reminder_history_params =
      Map.take(reminder, [
        :next_due_date,
        :next_due_mileage,
        :next_due_hours,
        :vehicle_mileage,
        :last_completed_hours,
        :last_completed_mileage,
        :last_completed_date
      ])
      |> Map.put(:service_reminder_id, reminder.id)
      |> Map.put(:work_order_id, work_order_id)

    Fleetms.Service.ServiceReminderHistory
    |> Ash.Changeset.for_create(:create, reminder_history_params)
    |> Ash.create!(tenant: tenant)

    reminder
  end

  defp update_inventory(work_order_changeset) do
    work_order_service_tasks_parts =
      Ash.Changeset.get_data(work_order_changeset, :work_order_service_tasks)
      |> Enum.map(& &1.work_order_service_task_parts)
      |> List.flatten()
      |> Enum.filter(&(&1.update_inventory == true))

    Enum.map(work_order_service_tasks_parts, fn %Fleetms.Service.WorkOrderServiceTaskPart{} =
                                                  work_order_service_task_part ->
      part_id = work_order_service_task_part.part_id
      inventory_location_id = work_order_service_task_part.inventory_location_id
      quantity = work_order_service_task_part.quantity

      part_inventory_location =
        Fleetms.Inventory.PartInventoryLocation.get_by_part_and_location!(
          part_id,
          inventory_location_id,
          tenant: work_order_changeset.tenant
        )

      part_inventory_location
      |> Ash.Changeset.for_update(:update_stock_quantity, %{quantity: quantity, part_id: part_id})
      |> Ash.update!()
    end)
  end
end
