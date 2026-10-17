defmodule Fleetms.VehicleIssues.IssueTagsTest do
  @moduledoc """
  Issues carry tags from the shared vocabulary: typing names on create/update relates
  existing tags or creates new ones, and syncing removes the ones dropped (without
  deleting the tag itself).
  """
  use Fleetms.DataCase, async: true

  import Fleetms.IssueFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.Tagging
  alias Fleetms.VehicleIssues

  setup :shared_org

  defp tag_names(issue), do: issue.tags |> Enum.map(&to_string(&1.name)) |> Enum.sort()

  test "creating an issue with tag names creates the tags and attaches them", %{scope: scope} do
    vehicle = vehicle_fixture(scope)

    {:ok, issue} =
      VehicleIssues.create_issue(
        %{title: "Brake noise", vehicle_id: vehicle.id, tags: ["brakes", "warranty"]},
        scope: scope
      )

    issue = VehicleIssues.get_issue!(issue.id, scope: scope, load: [:tags])
    assert tag_names(issue) == ["brakes", "warranty"]
    # Both are now in the org's vocabulary.
    assert Tagging.list_tags!(scope: scope) |> length() == 2
  end

  test "an existing tag is reused, not duplicated", %{scope: scope} do
    {:ok, existing} = Tagging.create_tag(%{name: "warranty"}, scope: scope)
    issue = issue_fixture(scope, %{tags: ["Warranty"]})

    issue = VehicleIssues.get_issue!(issue.id, scope: scope, load: [:tags])
    assert [tag] = issue.tags
    assert tag.id == existing.id
    assert Tagging.list_tags!(scope: scope) |> length() == 1
  end

  test "updating tags syncs attachments but keeps the tag in the vocabulary", %{scope: scope} do
    issue = issue_fixture(scope, %{tags: ["brakes", "warranty"]})

    {:ok, _} = VehicleIssues.update_issue(issue, %{tags: ["brakes"]}, scope: scope)

    issue = VehicleIssues.get_issue!(issue.id, scope: scope, load: [:tags])
    assert tag_names(issue) == ["brakes"]
    # "warranty" was only unlinked — it stays available for reuse.
    assert Tagging.list_tags!(scope: scope) |> Enum.map(&to_string(&1.name)) |> Enum.sort() ==
             ["brakes", "warranty"]
  end

  test "updating other fields without the tags argument leaves tags untouched", %{scope: scope} do
    issue = issue_fixture(scope, %{tags: ["brakes", "warranty"]})

    {:ok, _} = VehicleIssues.update_issue(issue, %{title: "Renamed"}, scope: scope)

    issue = VehicleIssues.get_issue!(issue.id, scope: scope, load: [:tags])
    assert tag_names(issue) == ["brakes", "warranty"]
  end

  test "clearing tags removes all attachments", %{scope: scope} do
    issue = issue_fixture(scope, %{tags: ["brakes"]})

    {:ok, _} = VehicleIssues.update_issue(issue, %{tags: []}, scope: scope)

    issue = VehicleIssues.get_issue!(issue.id, scope: scope, load: [:tags])
    assert issue.tags == []
  end
end
