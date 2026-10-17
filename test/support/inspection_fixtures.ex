defmodule Fleetms.InspectionFixtures do
  @moduledoc """
  Test fixtures for the inspections domain. All take a `Fleetms.Scope` so they run
  with a real actor + tenant, exactly as the web layer would.

  Submitting an inspection is form-driven: it needs a *published* form version to
  fill against. `published_version_fixture/1` builds a small three-item DVIR and
  publishes it; `inspection_fixture/3` submits an inspection against a version.
  """
  import Fleetms.VehicleFixtures

  alias Fleetms.Inspections

  @schema %{
    "sections" => [
      %{
        "id" => "s1",
        "title" => "Checks",
        "items" => [
          %{"id" => "brakes", "label" => "Brakes", "config" => %{"type" => "pass_fail"}}
        ]
      }
    ]
  }

  @doc "Creates and publishes a form; returns `{form, version}`."
  def published_version_fixture(scope) do
    form =
      %{title: "DVIR #{System.unique_integer([:positive])}"}
      |> Inspections.create_inspection_form!(scope: scope)
      |> Inspections.update_inspection_form!(%{draft_schema: @schema}, scope: scope)
      |> Inspections.publish_inspection_form!(scope: scope)

    [version] = Inspections.get_inspection_form!(form.id, scope: scope).versions
    {form, version}
  end

  @doc """
  Submits an inspection against `version` for a (fresh, unless given) vehicle.
  Answers default to a single passing item.
  """
  def inspection_fixture(scope, version, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        vehicle_id: attrs[:vehicle_id] || vehicle_fixture(scope).id,
        inspection_form_version_id: version.id,
        answers: [%{"item_id" => "brakes", "value" => "pass"}]
      })

    Inspections.submit_inspection!(attrs, scope: scope)
  end
end
