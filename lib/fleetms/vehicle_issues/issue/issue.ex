defmodule Fleetms.VehicleIssues.Issue do
  use Ash.Resource,
    domain: Fleetms.VehicleIssues,
    data_layer: AshPostgres.DataLayer,
    authorizers: [
      Ash.Policy.Authorizer
    ]

  alias Fleetms.Accounts.User.Policies.{IsAdmin, IsFleetManager, IsTechnician}
  require Ash.Query

  attributes do
    uuid_primary_key :id

    attribute :issue_number, :integer do
      allow_nil? false
      public? true
      default 0
      description "The issue number."
      writable? false
    end

    attribute :date_reported, :utc_datetime do
      allow_nil? false
      public? true
      description "The date and time the issue was opened."
    end

    attribute :title, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
      description "A short title describing the issue."
    end

    attribute :description, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 1000
      description "A description of the issue."
    end

    attribute :labels, {:array, :string} do
      allow_nil? true
      public? true
      default []
      description "A list of labels that describe the issue."
    end

    attribute :mileage, :decimal do
      allow_nil? true
      public? true
      description "The mileage of the vehicle when the issue was opened."
    end

    attribute :hours, :decimal do
      allow_nil? true
      public? true
      description "The hours of the vehicle when the issue was opened."
    end

    attribute :due_date, :date do
      allow_nil? true
      public? true
      description "The date the issue should not exceed without being resolved or closed."
    end

    attribute :date_resolved, :utc_datetime do
      allow_nil? true
      public? true
      description "The date and time the issue was resolved."
    end

    attribute :priority, :atom do
      allow_nil? true
      public? true
      default :Low
      constraints one_of: Fleetms.Enums.issue_priority()
      description "The priority of the issue."
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: Fleetms.Enums.issue_statuses()
      description "The status of the issue."
    end

    attribute :resolve_comments, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 1000
      description "Notes about how the issue was resolved."
    end

    attribute :close_comments, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 1000
      description "Notes about why the issue was closed."
    end

    attribute :date_closed, :utc_datetime do
      allow_nil? true
      public? true
      description "The date and time the issue was closed."
    end

    attribute :documents, {:array, IssueDocument} do
      allow_nil? true
      public? true
      description "A list of documents related to the issue."
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :vehicle, Fleetms.VehicleManagement.Vehicle do
      domain Fleetms.VehicleManagement
      allow_nil? false
      description "The vehicle that was assigned."
    end

    belongs_to :assigned_to, Fleetms.Accounts.User do
      domain Fleetms.Accounts
      allow_nil? true
      source_attribute :assigned_to_id
      destination_attribute :id
      description "The user assigned to this issue."
    end

    belongs_to :reported_by, Fleetms.Accounts.User do
      domain Fleetms.Accounts
      allow_nil? false
      source_attribute :reported_by_id
      destination_attribute :id
      description "The user that reported this issue."
    end

    belongs_to :work_order, Fleetms.VehicleMaintenance.WorkOrder do
      domain Fleetms.VehicleMaintenance
      allow_nil? true
      destination_attribute :id
      description "The work order this issue is associated with."
    end

    has_many :issue_photos, Fleetms.VehicleIssues.IssuePhoto
  end

  postgres do
    table "issues"
    repo Fleetms.Repo

    references do
      reference :vehicle, on_delete: :delete
      reference :work_order, on_delete: :nilify
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      description "Open a new issue."
      accept [:date_reported, :title, :description, :labels, :mileage, :due_date, :priority]

      argument :vehicle_id, :uuid do
        allow_nil? false
        description "The ID of the vehicle to assign the issue to."
      end

      argument :reported_by_id, :uuid do
        allow_nil? false
        description "The ID of the user that reported the issue."
      end

      argument :assigned_to_id, :uuid do
        allow_nil? true
        description "The ID of the user to assign the issue to."
      end

      argument :documents, {:array, :map} do
        allow_nil? true
        description "A list of documents to attach to the issue."
      end

      change manage_relationship(:vehicle_id, :vehicle, type: :append_and_remove)
      change manage_relationship(:reported_by_id, :reported_by, type: :append_and_remove)
      change manage_relationship(:assigned_to_id, :assigned_to, type: :append_and_remove)
      change set_attribute(:documents, arg(:documents))
      change set_attribute(:status, :Open)

      change Fleetms.VehicleIssues.Issue.Changes.SetIssueNumber do
        only_when_valid? true
      end
    end

    read :list do
      argument :paginate_sort_opts, :map, allow_nil?: false
      argument :search_query, :string, default: ""
      argument :advanced_filter_params, :map, default: %{}

      pagination offset?: true, default_limit: 50, countable: true

      prepare fn query, _context ->
        %{sort_order: sort_order, sort_by: sort_by} =
          query.arguments.paginate_sort_opts

        search_query = Ash.Query.get_argument(query, :search_query)
        advanced_filter_params = Ash.Query.get_argument(query, :advanced_filter_params)

        query =
          Enum.reduce(advanced_filter_params, query, fn
            {_, nil}, accumulated_query ->
              accumulated_query

            {_, "All"}, accumulated_query ->
              accumulated_query

            {_, :All}, accumulated_query ->
              accumulated_query

            {:status, status}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(status == ^status))

            {:priority, priority}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(priority == ^priority))

            {:mileage_min, mileage_min}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(mileage >= ^mileage_min))

            {:mileage_max, mileage_max}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(mileage <= ^mileage_max))

            {:date_reported_from, date_reported_from}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(date_reported >= ^date_reported_from))

            {:date_reported_to, date_reported_to}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(date_reported <= ^date_reported_to))

            {:due_date_from, due_date_from}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(due_date >= ^due_date_from))

            {:due_date_to, due_date_to}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(due_date <= ^due_date_to))

            {:vehicle_id, vehicle_id}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(vehicle_id == ^vehicle_id))

            _, accumulated_query ->
              accumulated_query
          end)
          |> Ash.Query.sort([{sort_by, sort_order}])

        if search_query == "" or is_nil(search_query) do
          query
        else
          Ash.Query.filter(
            query,
            expr(
              trigram_similarity(title, ^search_query) > 0.1 or
                trigram_similarity(description, ^search_query) > 0.3 or
                trigram_similarity(fragment("CAST(? AS VARCHAR)", issue_number), ^search_query) >
                  0.3 or
                trigram_similarity(status, ^search_query) > 0.3 or
                trigram_similarity(priority, ^search_query) > 0.3
            )
          )
        end
      end

      prepare build(load: [vehicle: [:full_name]])
    end

    read :get_by_id do
      argument :id, :uuid, allow_nil?: false

      filter expr(id == ^arg(:id))

      prepare build(
                load: [
                  :issue_photos,
                  reported_by: [user_profile: :full_name],
                  assigned_to: [user_profile: :full_name],
                  vehicle: [:full_name]
                ]
              )
    end

    read :get_by_vehicle_id do
      argument :vehicle_id, :uuid, allow_nil?: false

      filter expr(vehicle_id == ^arg(:vehicle_id))
      prepare build(load: [vehicle: [:full_name]])
    end

    read :list_vehicle_issues do
      argument :vehicle_id, :uuid, allow_nil?: false

      filter expr(vehicle_id == ^arg(:vehicle_id))
      pagination offset?: true, default_limit: 50, countable: true
    end

    action :get_dashboard_stats, :map do
      import Ecto.Query
      argument :tenant, :string, allow_nil?: false

      run fn input, context ->
        tenant = input.arguments.tenant

        {:ok, ecto_query} =
          Fleetms.VehicleIssues.Issue
          |> Ash.Query.set_tenant(tenant)
          |> Ash.Query.data_layer_query()

        new_ecto_query =
          from issue in subquery(ecto_query),
            select: %{
              total: count(issue.id, :distinct),
              open: count(issue.id, :distinct) |> filter(issue.status == :Open),
              closed: count(issue.id, :distinct) |> filter(issue.status == :Closed),
              resolved: count(issue.id, :distinct) |> filter(issue.status == :Resolved)
            }

        high_priority_query =
          from issue in subquery(ecto_query),
            where: issue.status == :Open and issue.priority == :High,
            order_by: [desc: issue.updated_at],
            limit: 5

        medium_priority_query =
          from issue in subquery(ecto_query),
            where: issue.status == :Open and issue.priority == :Medium,
            order_by: [desc: issue.updated_at],
            limit: 5

        low_or_none_priority_query =
          from issue in subquery(ecto_query),
            where: issue.status == :Open and issue.priority in [:Low, :None],
            order_by: [desc: issue.updated_at],
            limit: 5

        issues_by_priorities =
          %{
            high: Fleetms.Repo.all(high_priority_query),
            medium: Fleetms.Repo.all(medium_priority_query),
            low_or_none: Fleetms.Repo.all(low_or_none_priority_query)
          }

        {:ok, {Fleetms.Repo.one(new_ecto_query), issues_by_priorities}}
      end
    end

    update :update do
      require_atomic? false
      primary? true

      accept [:date_reported, :title, :description, :labels, :mileage, :due_date, :priority]

      argument :vehicle_id, :uuid do
        allow_nil? false
        description "The ID of the vehicle to assign the issue to."
      end

      argument :reported_by_id, :uuid do
        allow_nil? true
        description "The ID of the user that reported the issue."
      end

      argument :assigned_to_id, :uuid do
        allow_nil? true
        description "The ID of the user to assign the issue to."
      end

      change manage_relationship(:vehicle_id, :vehicle, type: :append_and_remove)
      change manage_relationship(:reported_by_id, :reported_by, type: :append_and_remove)
      change manage_relationship(:assigned_to_id, :assigned_to, type: :append_and_remove)
    end

    update :update_from_work_order do
      require_atomic? false
      accept [:work_order_id]
      argument :work_order_id, :uuid

      change manage_relationship(:work_order_id, :work_order, type: :append_and_remove)
    end

    update :update_from_work_order_reopen do
      require_atomic? false
      argument :work_order_id, :uuid

      change manage_relationship(:work_order_id, :work_order, type: :append_and_remove)
      change set_attribute(:status, :Open)
      change set_attribute(:close_comments, nil)
      change set_attribute(:resolve_comments, nil)
      change set_attribute(:date_resolved, nil)
      change set_attribute(:date_closed, nil)
    end

    update :close_issue do
      require_atomic? false
      description "Closes the issue."

      accept [:close_comments, :date_closed]

      change set_attribute(:status, :Closed)
      change set_attribute(:resolve_comments, nil)
      change set_attribute(:date_resolved, nil)

      change fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :date_closed, Date.utc_today())
      end
    end

    update :resolve_issue_with_comment do
      require_atomic? false
      description "Resolves the issue with notes."

      accept [:resolve_comments]

      change set_attribute(:status, :Resolved)
    end

    update :resolve_issue do
      require_atomic? false
      accept [:date_resolved]

      description "Resolves the issue"
      change set_attribute(:status, :Resolved)
      change set_attribute(:resolve_comments, nil)
      change set_attribute(:close_comments, nil)
      change set_attribute(:date_closed, nil)
    end

    update :resolve_from_work_order do
      require_atomic? false
      accept [:work_order_id, :date_resolved]
      argument :work_order_id, :uuid

      change manage_relationship(:work_order_id, :work_order, type: :append_and_remove)

      change fn changeset, _context ->
        Ash.Changeset.force_change_attribute(changeset, :status, :Resolved)
      end
    end

    update :reopen_issue do
      require_atomic? false
      description "Reopens the issue."

      change set_attribute(:status, :Open)
      change set_attribute(:close_comments, nil)
      change set_attribute(:date_closed, nil)
    end

    update :link_to_work_order do
      require_atomic? false
      description "Links the issue to a work order."
      accept [:work_order_id]

      argument :work_order_id, :uuid do
        allow_nil? false
      end

      change manage_relationship(:work_order_id, :work_order, type: :append_and_remove)
    end

    update :save_issue_photos do
      require_atomic? false
      argument :issue_photos, {:array, :map}, allow_nil?: false

      change manage_relationship(:issue_photos, type: :direct_control)
    end

    update :maybe_delete_existing_photos do
      require_atomic? false
      argument :current_photos, {:array, :map}, allow_nil?: false

      change manage_relationship(:current_photos, :issue_photos, type: :direct_control)
    end

    destroy :destroy do
      require_atomic? false
      primary? true

      change fn changeset, _context ->
        Ash.Changeset.after_action(changeset, fn changeset, deleted_issue ->
          # Here, I access photos to delete by calling `deleted_issue.issue_photos` because `issue_photos` relationship is already loaded when the
          # Issue to delete was queried with `get_by_id/1` and passed to `Ash.destroy` in the FleetmsWeb.IssueLive.Index LiveView.
          # If calling this action from somewhere else, make sure `issue_photos` is loaded otherwise this action will fail.
          Enum.map(deleted_issue.issue_photos, fn
            issue_photo ->
              Fleetms.IssuePhoto.delete({issue_photo.filename, deleted_issue})
          end)

          {:ok, deleted_issue}
        end)
      end
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
      authorize_if IsDriver
    end

    policy action([:save_issue_photos, :maybe_delete_existing_photos]) do
      authorize_if always()
    end

    policy action(:update) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
      authorize_if relates_to_actor_via(:reported_by)
    end

    policy action([
             :update_from_work_order,
             :update_from_work_order_reopen
           ]) do
      authorize_if accessing_from(Fleetms.VehicleMaintenance.WorkOrder, :issues)
    end

    policy action(:resolve_from_work_order) do
      authorize_if always()
    end

    policy action([
             :destroy,
             :close_issue,
             :resolve_issue_with_comment,
             :resolve_issue,
             :reopen_issue
           ]) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
    end
  end

  identities do
    identity :unique_issue_number, [:issue_number]
  end

  code_interface do
    define :get_by_id, action: :get_by_id, args: [:id], get?: true
    define :get_by_vehicle_id, action: :get_by_vehicle_id, args: [:vehicle_id]
    define :save_issue_photos, action: :save_issue_photos, args: [:issue_photos]
    define :get_dashboard_stats, action: :get_dashboard_stats, args: [:tenant]
  end

  multitenancy do
    strategy :context
  end
end
