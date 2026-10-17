defmodule Fleetms.Tagging do
  @moduledoc """
  The tagging domain: a shared, org-scoped tag vocabulary reused across the app.

  `Tag` is the vocabulary — a named, coloured label an organization defines once and
  reuses everywhere. `Tagging` is the polymorphic join that attaches a tag to one
  record (an issue, work order, vehicle or part), modelled the same way as comments:
  one nullable foreign key per taggable type with a database check constraint that
  exactly one is set. See `Fleetms.Tagging.Tag` and `Fleetms.Tagging.Tagging`.
  """
  use Ash.Domain, otp_app: :fleetms, extensions: [AshPhoenix, AshJsonApi.Domain]

  json_api do
    routes do
      base_route "/tags", Fleetms.Tagging.Tag do
        index :list
        get(:read)
        post(:create)
        patch(:update)
        delete(:destroy)
      end
    end
  end

  resources do
    resource Fleetms.Tagging.Tag do
      define :list_tags, action: :list
      define :get_tag, action: :read, get_by: [:id]
      define :create_tag, action: :create
      define :update_tag, action: :update
      define :delete_tag, action: :destroy
    end

    resource Fleetms.Tagging.Tagging do
      define :list_taggings, action: :read
      define :create_tagging, action: :create
      define :delete_tagging, action: :destroy
    end
  end
end
