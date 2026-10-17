defmodule Fleetms.VehicleManagement do
  @moduledoc """
  The fleet domain: vehicles and the entities that describe and organize them
  (makes, models, groups, photos, documents).
  """
  use Ash.Domain, otp_app: :fleetms, extensions: [AshPhoenix, AshJsonApi.Domain]

  # Public REST (JSON:API) surface. The caller's bearer token (or API key) sets the
  # actor and the `x-organization` header sets the tenant (see
  # FleetmsWeb.Plugs.ApiTenant), so policies and multitenancy apply unchanged.
  json_api do
    routes do
      base_route "/vehicles", Fleetms.VehicleManagement.Vehicle do
        index :list
        get(:get_by_id)
        post(:create)
        patch(:update)
        patch(:update_status, route: "/:id/status")
        delete(:destroy)
      end

      base_route "/vehicle-groups", Fleetms.VehicleManagement.VehicleGroup do
        index :read
        get(:get_by_id)
        post(:create)
        patch(:update)
        delete(:destroy)
      end

      base_route "/assignments", Fleetms.VehicleManagement.VehicleAssignment do
        index :list
        get(:get_by_id)
        post(:create)
        patch(:update)
        delete(:destroy)
      end

      base_route "/renewals", Fleetms.VehicleManagement.VehicleRenewal do
        index :list
        get(:get_by_id)
        post(:create)
        patch(:update)
        patch(:mark_renewed, route: "/:id/mark-renewed")
        delete(:destroy)
      end
    end
  end

  resources do
    resource Fleetms.VehicleManagement.Vehicle do
      # All inputs (search_query, filters, sort_by, sort_order) are passed as a
      # single map, keeping the call site unambiguous alongside opts.
      define :list_vehicles, action: :list
      define :list_assignable_vehicles, action: :list_assignable
      define :list_selectable_vehicles, action: :list_selectable

      define :get_vehicle, action: :get_by_id, args: [:id]
      define :create_vehicle, action: :create
      define :update_vehicle, action: :update
      define :update_vehicle_status, action: :update_status
      define :delete_vehicle, action: :destroy
    end

    resource Fleetms.VehicleManagement.VehicleMake do
      define :list_vehicle_makes, action: :read
      define :get_vehicle_make, action: :get_by_id, args: [:id]
      define :upsert_vehicle_make, action: :create
      define :delete_vehicle_make, action: :destroy
    end

    resource Fleetms.VehicleManagement.VehicleModel do
      define :get_vehicle_model, action: :get_by_id, args: [:id]
      define :list_vehicle_models_by_make, action: :list_by_make, args: [:vehicle_make_id]
      define :upsert_vehicle_model, action: :create
      define :delete_vehicle_model, action: :destroy
    end

    resource Fleetms.VehicleManagement.VehicleSpec

    # Audit-trail version rows (AshPaperTrail), read for the History timeline.
    resource Fleetms.VehicleManagement.Vehicle.Version

    resource Fleetms.VehicleManagement.VehicleGroup do
      define :list_vehicle_groups, action: :read
      define :get_vehicle_group, action: :get_by_id, args: [:id]
      define :create_vehicle_group, action: :create
      define :update_vehicle_group, action: :update
      define :delete_vehicle_group, action: :destroy
    end

    resource Fleetms.VehicleManagement.VehicleAssignment do
      define :list_vehicle_assignments, action: :list
      define :list_assignments_for_vehicle, action: :list_by_vehicle, args: [:vehicle_id]
      define :get_vehicle_assignment, action: :get_by_id, args: [:id]
      define :create_vehicle_assignment, action: :create
      define :update_vehicle_assignment, action: :update
      define :delete_vehicle_assignment, action: :destroy
    end

    resource Fleetms.VehicleManagement.VehicleAssignment.Version

    resource Fleetms.VehicleManagement.RenewalType do
      define :list_renewal_types, action: :read
      define :get_renewal_type, action: :get_by_id, args: [:id]
      define :upsert_renewal_type, action: :create
      define :update_renewal_type, action: :update
      define :delete_renewal_type, action: :destroy
    end

    resource Fleetms.VehicleManagement.VehicleRenewal do
      define :list_vehicle_renewals, action: :list
      define :list_archived_vehicle_renewals, action: :list_archived
      define :get_vehicle_renewal, action: :get_by_id, args: [:id]
      define :create_vehicle_renewal, action: :create
      define :update_vehicle_renewal, action: :update
      define :mark_renewal_completed, action: :mark_renewed
      define :delete_vehicle_renewal, action: :destroy
      define :restore_vehicle_renewal, action: :restore
    end

    resource Fleetms.VehicleManagement.VehiclePhoto do
      define :create_vehicle_photo, action: :create
      define :upload_vehicle_photo, action: :upload
      define :update_vehicle_photo, action: :update
      define :delete_vehicle_photo, action: :destroy
    end

    resource Fleetms.VehicleManagement.VehicleDocument do
      define :get_vehicle_document, action: :get_by_id, args: [:id]
      define :list_vehicle_documents, action: :list_by_vehicle, args: [:vehicle_id]
      define :create_vehicle_document, action: :create
      define :upload_vehicle_document, action: :upload
      define :update_vehicle_document, action: :update
      define :delete_vehicle_document, action: :destroy
    end
  end
end
