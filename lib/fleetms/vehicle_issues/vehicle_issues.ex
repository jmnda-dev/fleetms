defmodule Fleetms.VehicleIssues do
  @moduledoc """
  The issues domain: faults and tasks raised against vehicles, their lifecycle
  (open → resolved → closed) and their photo/document attachments.
  """
  use Ash.Domain, otp_app: :fleetms, extensions: [AshPhoenix, AshJsonApi.Domain]

  json_api do
    routes do
      base_route "/issues", Fleetms.VehicleIssues.Issue do
        index :list
        get(:get_by_id)
        post(:create)
        patch(:update)
        patch(:resolve, route: "/:id/resolve")
        patch(:close, route: "/:id/close")
        patch(:reopen, route: "/:id/reopen")
        patch(:restore, route: "/:id/restore")
        delete(:destroy)
      end
    end
  end

  resources do
    resource Fleetms.VehicleIssues.Issue do
      # All list inputs (search_query, filters, sort_by, sort_order) are passed as
      # a single map, keeping the call site unambiguous alongside opts.
      define :list_issues, action: :list
      define :list_archived_issues, action: :list_archived

      define :get_issue, action: :get_by_id, args: [:id]
      define :list_vehicle_issues, action: :list_by_vehicle, args: [:vehicle_id]
      define :create_issue, action: :create
      define :update_issue, action: :update
      define :resolve_issue, action: :resolve
      define :close_issue, action: :close
      define :reopen_issue, action: :reopen
      define :delete_issue, action: :destroy
      define :purge_issue, action: :purge
      define :restore_issue, action: :restore
    end

    resource Fleetms.VehicleIssues.IssueWatcher do
      define :watch_issue, action: :watch
      define :unwatch_issue, action: :destroy
      define :list_issue_watchers, action: :read
    end

    # Audit-trail version rows (AshPaperTrail), read for the History timeline.
    resource Fleetms.VehicleIssues.Issue.Version

    resource Fleetms.VehicleIssues.IssuePhoto do
      define :create_issue_photo, action: :create
      define :upload_issue_photo, action: :upload
      define :update_issue_photo, action: :update
      define :delete_issue_photo, action: :destroy
    end

    resource Fleetms.VehicleIssues.IssueDocument do
      define :get_issue_document, action: :get_by_id, args: [:id]
      define :list_issue_documents, action: :list_by_issue, args: [:issue_id]
      define :create_issue_document, action: :create
      define :upload_issue_document, action: :upload
      define :update_issue_document, action: :update
      define :delete_issue_document, action: :destroy
    end
  end
end
