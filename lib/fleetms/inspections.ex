defmodule Fleetms.Inspections do
  @moduledoc """
  The inspections domain: building inspection forms and (later) recording the
  inspections filled against them.

  An **inspection form** is a living template whose questions live in a single
  typed jsonb document (`Fleetms.Inspections.Schema`) — an ordered tree of sections
  and items, where each item's shape is a validated union variant. Editing happens
  on the form's mutable `draft_schema`; **publishing** freezes that draft into an
  immutable `InspectionFormVersion`, so historical inspections (added in a later
  phase) always reference the exact document they were taken against.

  This module currently covers form authoring and versioning; filling, workflows,
  and scheduling arrive in subsequent phases.
  """
  use Ash.Domain, otp_app: :fleetms, extensions: [AshPhoenix, AshJsonApi.Domain]

  # Read-only for now — inspections carry versioned JSON form documents, so writes
  # (building a form, filling an inspection) stay in the app until an API shape for
  # them is designed.
  json_api do
    routes do
      base_route "/inspections", Fleetms.Inspections.Inspection do
        index :list
        # Before get/:id so the static "/archived" segment isn't read as an id.
        index :list_archived, route: "/archived"
        get(:get_by_id)
        post(:submit)
        patch(:restore, route: "/:id/restore")
        delete(:destroy)
      end

      base_route "/inspection-forms", Fleetms.Inspections.InspectionForm do
        index :list
        get(:get_by_id)
      end

      # An inspection points at a specific (immutable) form version, whose `schema`
      # holds the questions — fetch it to render an inspection's answers.
      base_route "/inspection-form-versions", Fleetms.Inspections.InspectionFormVersion do
        get(:get_by_id)
      end

      base_route "/inspection-schedules", Fleetms.Inspections.InspectionSchedule do
        index :list
        get(:get_by_id)
      end

      base_route "/inspection-assignments", Fleetms.Inspections.InspectionAssignment do
        index :list
        get(:get_by_id)
      end
    end
  end

  resources do
    resource Fleetms.Inspections.InspectionForm do
      define :list_inspection_forms, action: :list
      define :get_inspection_form, action: :get_by_id, args: [:id]
      define :create_inspection_form, action: :create
      define :duplicate_inspection_form, action: :duplicate
      define :update_inspection_form, action: :update
      define :publish_inspection_form, action: :publish
      define :delete_inspection_form, action: :destroy
    end

    resource Fleetms.Inspections.InspectionFormVersion do
      define :get_inspection_form_version, action: :get_by_id, args: [:id]
    end

    resource Fleetms.Inspections.Inspection do
      define :list_inspections, action: :list
      define :list_archived_inspections, action: :list_archived
      define :get_inspection, action: :get_by_id, args: [:id]
      define :submit_inspection, action: :submit
      define :run_inspection_workflows, action: :run_workflows
      define :delete_inspection, action: :destroy
      define :restore_inspection, action: :restore
    end

    resource Fleetms.Inspections.InspectionFailure do
      define :link_inspection_failure_issue, action: :link_issue
    end

    resource Fleetms.Inspections.InspectionSchedule do
      define :list_inspection_schedules, action: :list
      define :get_inspection_schedule, action: :get_by_id, args: [:id]
      define :create_inspection_schedule, action: :create
      define :update_inspection_schedule, action: :update
      define :delete_inspection_schedule, action: :destroy
    end

    resource Fleetms.Inspections.InspectionAssignment do
      define :list_inspection_assignments, action: :list
      define :get_inspection_assignment, action: :get_by_id, args: [:id]
      define :generate_inspection_assignment, action: :generate
      define :complete_inspection_assignment, action: :complete
    end
  end
end
