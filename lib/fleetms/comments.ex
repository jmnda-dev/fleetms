defmodule Fleetms.Comments do
  @moduledoc """
  The comments domain: a single `Comment` resource shared by every page that has a
  discussion thread — issues, work orders, vehicles and inspections. See
  `Fleetms.Comments.Comment` for how the polymorphic parent is modelled.
  """
  use Ash.Domain, otp_app: :fleetms, extensions: [AshPhoenix]

  resources do
    resource Fleetms.Comments.Comment do
      # The caller passes exactly one parent id (e.g. %{issue_id: id}).
      define :list_comments, action: :list
      define :create_comment, action: :create
      define :update_comment, action: :update
      define :delete_comment, action: :destroy
    end
  end
end
