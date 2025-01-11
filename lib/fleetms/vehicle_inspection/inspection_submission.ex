defmodule Fleetms.VehicleInspection.InspectionSubmission do
  use Ash.Resource,
    domain: Fleetms.VehicleInspection,
    data_layer: AshPostgres.DataLayer,
    authorizers: [
      Ash.Policy.Authorizer
    ]

  alias Fleetms.Accounts.User.Policies.{IsAdmin, IsFleetManager, IsTechnician}
  @pass_value "Pass"
  @fail_value "Fail"

  attributes do
    uuid_primary_key :id
    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :vehicle, Fleetms.VehicleManagement.Vehicle do
      domain Fleetms.VehicleManagement
      allow_nil? false
    end

    # TODO: Figure out a better relationship name e.g driver, mechanic
    belongs_to :user, Fleetms.Accounts.User do
      domain Fleetms.Accounts
      allow_nil? false
    end

    belongs_to :inspection_form, Fleetms.VehicleInspection.InspectionForm do
      allow_nil? false
    end

    has_many :radio_input_values, Fleetms.VehicleInspection.RadioInputValue
    has_many :dropdown_input_values, Fleetms.VehicleInspection.DropdownInputValue
    has_many :number_input_values, Fleetms.VehicleInspection.NumberInputValue
    has_many :signature_input_values, Fleetms.VehicleInspection.SignatureInputValue
    has_many :text_input_values, Fleetms.VehicleInspection.TextInputValue
  end

  postgres do
    table "inspection_submissions"
    repo Fleetms.Repo

    references do
      reference :inspection_form, on_delete: :nilify
    end
  end

  actions do
    defaults [:destroy]

    action :get_dashboard_stats, :map do
      argument :tenant, :string, allow_nil?: false

      argument :period, :atom,
        allow_nil?: false,
        constraints: [one_of: [:seven_days, :thirty_days, :twelve_months]]

      run fn input, context ->
        tenant = input.arguments.tenant
        period = input.arguments.period

        today = Date.utc_today()

        {start_date, end_date} =
          case period do
            :seven_days ->
              {Timex.shift(today, days: -7), today}

            :thirty_days ->
              {Timex.shift(today, days: -30), today}

            :twelve_months ->
              {Timex.shift(today, months: -12), today}
          end

        new_ecto_query =
          inspection_stats_query(tenant, period, start_date, end_date)

        total_inspections =
          Fleetms.VehicleInspection.InspectionSubmission
          |> Ash.Query.set_tenant(tenant)
          |> Ash.count!()

        {:ok, {total_inspections, Fleetms.Repo.all(new_ecto_query)}}
      end
    end

    create :create do
      primary? true

      argument :vehicle_id, :uuid, allow_nil?: false
      argument :user_id, :uuid, allow_nil?: false
      argument :inspection_form_id, :uuid, allow_nil?: false
      argument :radio_input_values, {:array, :map}
      argument :dropdown_input_values, {:array, :map}
      argument :number_input_values, {:array, :map}
      argument :signature_input_values, {:array, :map}

      change manage_relationship(:radio_input_values, :radio_input_values, type: :create)
      change manage_relationship(:dropdown_input_values, :dropdown_input_values, type: :create)
      change manage_relationship(:number_input_values, :number_input_values, type: :create)
      change manage_relationship(:signature_input_values, :signature_input_values, type: :create)
      change manage_relationship(:vehicle_id, :vehicle, type: :append_and_remove)
      change manage_relationship(:user_id, :user, type: :append_and_remove)
      change manage_relationship(:inspection_form_id, :inspection_form, type: :append_and_remove)
    end

    update :update do
      primary? true
      require_atomic? false

      argument :vehicle_id, :uuid, allow_nil?: false
      argument :user_id, :uuid
      argument :inspection_form_id, :uuid, allow_nil?: false
      argument :radio_input_values, {:array, :map}
      argument :dropdown_input_values, {:array, :map}
      argument :number_input_values, {:array, :map}
      argument :signature_input_values, {:array, :map}

      change manage_relationship(:radio_input_values, :radio_input_values, type: :direct_control)

      change manage_relationship(:dropdown_input_values, :dropdown_input_values,
               type: :direct_control
             )

      change manage_relationship(:number_input_values, :number_input_values,
               type: :direct_control
             )

      change manage_relationship(:signature_input_values, :signature_input_values,
               type: :direct_control
             )

      change manage_relationship(:vehicle_id, :vehicle, type: :append_and_remove)
      change manage_relationship(:user_id, :user, type: :append_and_remove)
      change manage_relationship(:inspection_form_id, :inspection_form, type: :append_and_remove)
    end

    read :list do
      primary? true
      pagination offset?: true, default_limit: 50, countable: true
      prepare build(load: [:inspection_form, :user, vehicle: [:full_name]])
    end

    read :get_all

    read :get_by_id do
      argument :id, :uuid, allow_nil?: false

      filter expr(id == ^arg(:id))

      prepare build(
                load: [
                  :inspection_form,
                  :radio_input_values,
                  :dropdown_input_values,
                  :number_input_values,
                  :signature_input_values,
                  vehicle: [:full_name],
                  user: [user_profile: [:full_name]]
                ]
              )
    end

    read :for_delete do
      argument :id, :uuid, allow_nil?: false
      filter expr(id == ^arg(:id))
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

    policy action(:update) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
      authorize_if relates_to_actor_via(:user)
    end

    policy action(:destroy) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
    end
  end

  code_interface do
    define :get_all, action: :get_all
    define :get_by_id, action: :get_by_id, args: [:id], get?: true
    define :for_delete, action: :for_delete, args: [:id], get?: true

    define :get_dashboard_stats,
      action: :get_dashboard_stats,
      args: [:tenant, :period]
  end

  multitenancy do
    strategy :context
  end

  defp inspection_stats_query(tenant, period, start_date, end_date) do
    import Ecto.Query

    {:ok, inspections_query} =
      Fleetms.VehicleInspection.InspectionSubmission
      |> Ash.Query.new()
      |> Ash.Query.set_tenant(tenant)
      |> Ash.Query.data_layer_query()

    {:ok, radio_input_values_query} =
      Fleetms.VehicleInspection.RadioInputValue
      |> Ash.Query.new()
      |> Ash.Query.set_tenant(tenant)
      |> Ash.Query.data_layer_query()

    {:ok, dropdown_input_values_query} =
      Fleetms.VehicleInspection.DropdownInputValue
      |> Ash.Query.new()
      |> Ash.Query.set_tenant(tenant)
      |> Ash.Query.data_layer_query()

    {:ok, number_input_values_query} =
      Fleetms.VehicleInspection.NumberInputValue
      |> Ash.Query.new()
      |> Ash.Query.set_tenant(tenant)
      |> Ash.Query.data_layer_query()

    if period in [:seven_days, :thirty_days] do
      from(
        dates in fragment(
          "SELECT generate_series((?)::date, (?)::date, '1 day'::interval) AS duration",
          ^start_date,
          ^end_date
        ),
        join: inspection in subquery(inspections_query),
        as: :inspection_submission,
        on: true,
        group_by: dates.duration,
        select: %{
          duration:
            fragment(
              "CONCAT(SUBSTRING(trim(TO_CHAR(?, 'Day')), 1, 3), ' ', SUBSTRING(trim(TO_CHAR(?, 'Month')), 1, 3), ' ', EXTRACT(day FROM ?)::integer)",
              dates.duration,
              dates.duration,
              dates.duration
            ),
          total:
            count(inspection.id, :distinct)
            |> filter(fragment("DATE(?)", inspection.created_at) == dates.duration),
          passed:
            filter(
              count(inspection.id),
              fragment("DATE(?)", inspection.created_at) == dates.duration and
                @pass_value ==
                  all(
                    from(p in radio_input_values_query,
                      where: parent_as(:inspection_submission).id == p.inspection_submission_id,
                      select: p.status,
                      group_by: [p.status]
                    )
                  ) and
                @pass_value ==
                  all(
                    from(d in dropdown_input_values_query,
                      where: parent_as(:inspection_submission).id == d.inspection_submission_id,
                      select: d.status,
                      group_by: [d.status]
                    )
                  ) and
                @pass_value ==
                  all(
                    from(n in number_input_values_query,
                      where: parent_as(:inspection_submission).id == n.inspection_submission_id,
                      select: n.status,
                      group_by: [n.status]
                    )
                  )
            ),
          failed:
            filter(
              count(inspection.id),
              fragment("DATE(?)", inspection.created_at) == dates.duration and
                (@fail_value ==
                   any(
                     from(p in radio_input_values_query,
                       where: parent_as(:inspection_submission).id == p.inspection_submission_id,
                       select: p.status,
                       group_by: [p.status]
                     )
                   ) or
                   @fail_value ==
                     any(
                       from(d in dropdown_input_values_query,
                         where:
                           parent_as(:inspection_submission).id == d.inspection_submission_id,
                         select: d.status,
                         group_by: [d.status]
                       )
                     ) or
                   @fail_value ==
                     any(
                       from(n in number_input_values_query,
                         where:
                           parent_as(:inspection_submission).id == n.inspection_submission_id,
                         select: n.status,
                         group_by: [n.status]
                       )
                     ))
            )
        }
      )
    else
      from(
        dates in fragment(
          "SELECT generate_series((?)::date, (?)::date, '1 month'::interval) AS duration",
          ^start_date,
          ^end_date
        ),
        join: inspection in subquery(inspections_query),
        as: :inspection_submission,
        on: true,
        group_by: dates.duration,
        order_by: dates.duration,
        select: %{
          duration:
            fragment(
              "CONCAT(SUBSTRING(trim(TO_CHAR(?, 'Month')), 1, 3), ' ', trim(TO_CHAR(?, 'YYYY')))",
              dates.duration,
              dates.duration
            ),
          total:
            count(inspection.id, :distinct)
            |> filter(
              fragment("TO_CHAR(DATE(?), 'YYYY-MM')", inspection.created_at) ==
                fragment("TO_CHAR(?, 'YYYY-MM')", dates.duration)
            ),
          passed:
            filter(
              count(inspection.id),
              fragment("TO_CHAR(DATE(?), 'YYYY-MM')", inspection.created_at) ==
                fragment("TO_CHAR(?, 'YYYY-MM')", dates.duration) and
                @pass_value ==
                  all(
                    from(p in radio_input_values_query,
                      where: parent_as(:inspection_submission).id == p.inspection_submission_id,
                      select: p.status,
                      group_by: [p.status]
                    )
                  ) and
                @pass_value ==
                  all(
                    from(d in dropdown_input_values_query,
                      where: parent_as(:inspection_submission).id == d.inspection_submission_id,
                      select: d.status,
                      group_by: [d.status]
                    )
                  ) and
                @pass_value ==
                  all(
                    from(n in number_input_values_query,
                      where: parent_as(:inspection_submission).id == n.inspection_submission_id,
                      select: n.status,
                      group_by: [n.status]
                    )
                  )
            ),
          failed:
            filter(
              count(inspection.id),
              fragment("TO_CHAR(DATE(?), 'YYYY-MM')", inspection.created_at) ==
                fragment("TO_CHAR(?, 'YYYY-MM')", dates.duration) and
                (@fail_value ==
                   any(
                     from(p in radio_input_values_query,
                       where: parent_as(:inspection_submission).id == p.inspection_submission_id,
                       select: p.status,
                       group_by: [p.status]
                     )
                   ) or
                   @fail_value ==
                     any(
                       from(d in dropdown_input_values_query,
                         where:
                           parent_as(:inspection_submission).id == d.inspection_submission_id,
                         select: d.status,
                         group_by: [d.status]
                       )
                     ) or
                   @fail_value ==
                     any(
                       from(n in number_input_values_query,
                         where:
                           parent_as(:inspection_submission).id == n.inspection_submission_id,
                         select: n.status,
                         group_by: [n.status]
                       )
                     ))
            )
        }
      )
    end
  end
end
