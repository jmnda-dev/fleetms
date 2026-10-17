defmodule Fleetms.Permissions.Dsl do
  @moduledoc """
  Spark DSL extension. Add to any Ash Resource that has guarded actions.

  ## Example

      use Ash.Resource,
        extensions: [Fleetms.Permissions.Dsl]

      permissions do
        permission :create_vehicle,
          action: :create,
          label: "Create Vehicle",
          group: "Fleet Management"

        permission :view_vehicles,
          action: :read,
          label: "View Vehicles",
          group: "Fleet Management"

        # One permission covering multiple actions:
        permission :manage_vehicle_documents,
          action: [:create, :update],
          label: "Manage Vehicle Documents",
          group: "Fleet Management"
      end
  """

  alias Fleetms.Permissions.Dsl.PermissionEntity

  @permission %Spark.Dsl.Entity{
    name: :permission,
    target: PermissionEntity,
    args: [:name],
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "Unique internal identifier for this permission (atom)."
      ],
      action: [
        type: {:or, [:atom, {:list, :atom}]},
        required: true,
        doc: "The Ash action name(s) this permission guards."
      ],
      label: [
        type: :string,
        required: true,
        doc: "Human-readable label shown in the UI."
      ],
      description: [
        type: {:or, [:string, nil]},
        doc: "Optional longer description for tooltips."
      ],
      group: [
        type: {:or, [:string, nil]},
        doc: "UI grouping category. Auto-derived from module name if omitted."
      ]
    ]
  }

  @permissions_section %Spark.Dsl.Section{
    name: :permissions,
    describe: "Declare permissions tied to this resource's actions.",
    entities: [@permission],
    schema: []
  }

  use Spark.Dsl.Extension,
    sections: [@permissions_section],
    verifiers: [Fleetms.Permissions.Dsl.Verifier]
end
