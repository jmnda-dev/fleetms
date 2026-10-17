defmodule Fleetms.Tagging.TagTest do
  @moduledoc """
  The shared tag vocabulary and the polymorphic tagging join: names are unique per org
  and reused (upsert), a new tag gets a stable colour, and an attachment must belong to
  exactly one record.
  """
  use Fleetms.DataCase, async: true

  import Fleetms.IssueFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.Tagging

  setup :shared_org

  describe "the vocabulary" do
    test "a tag is created with a name and an auto-assigned colour", %{scope: scope} do
      {:ok, tag} = Tagging.create_tag(%{name: "warranty"}, scope: scope)

      assert to_string(tag.name) == "warranty"
      assert tag.color in Tagging.TagColor.values()
    end

    test "the colour is stable for a given name but overridable", %{scope: scope} do
      {:ok, a} = Tagging.create_tag(%{name: "recall"}, scope: scope)
      # Same name, different org member wouldn't matter — colour derives from the name.
      assert a.color == Enum.at(Tagging.TagColor.values(), :erlang.phash2("recall", 10))

      {:ok, b} = Tagging.create_tag(%{name: "campaign", color: :blue}, scope: scope)
      assert b.color == :blue
    end

    test "names are unique per org and reused case-insensitively (upsert)", %{scope: scope} do
      {:ok, first} = Tagging.create_tag(%{name: "Warranty"}, scope: scope)
      {:ok, again} = Tagging.create_tag(%{name: "warranty"}, scope: scope)

      assert again.id == first.id
      assert [_one] = Tagging.list_tags!(scope: scope)
    end

    test "listing is alphabetical", %{scope: scope} do
      for name <- ~w(zeta alpha mike), do: Tagging.create_tag!(%{name: name}, scope: scope)

      names = Tagging.list_tags!(scope: scope) |> Enum.map(&to_string(&1.name))
      assert names == ~w(alpha mike zeta)
    end

    test "a blank name is rejected", %{scope: scope} do
      assert {:error, _} = Tagging.create_tag(%{name: ""}, scope: scope)
    end
  end

  describe "attaching tags to records" do
    test "a tag attaches to an issue", %{scope: scope} do
      issue = issue_fixture(scope)
      {:ok, tag} = Tagging.create_tag(%{name: "urgent"}, scope: scope)

      {:ok, tagging} =
        Tagging.create_tagging(%{tag_id: tag.id, issue_id: issue.id}, scope: scope)

      assert tagging.tag_id == tag.id
      assert tagging.issue_id == issue.id
    end

    test "exactly one parent must be set — zero is rejected", %{scope: scope} do
      {:ok, tag} = Tagging.create_tag(%{name: "orphan"}, scope: scope)
      assert {:error, _} = Tagging.create_tagging(%{tag_id: tag.id}, scope: scope)
    end

    test "exactly one parent must be set — two is rejected", %{scope: scope} do
      issue = issue_fixture(scope)
      vehicle = vehicle_fixture(scope)
      {:ok, tag} = Tagging.create_tag(%{name: "both"}, scope: scope)

      assert {:error, _} =
               Tagging.create_tagging(
                 %{tag_id: tag.id, issue_id: issue.id, vehicle_id: vehicle.id},
                 scope: scope
               )
    end

    test "the same tag can't be attached to the same record twice", %{scope: scope} do
      issue = issue_fixture(scope)
      {:ok, tag} = Tagging.create_tag(%{name: "dup"}, scope: scope)

      {:ok, _} = Tagging.create_tagging(%{tag_id: tag.id, issue_id: issue.id}, scope: scope)

      assert {:error, _} =
               Tagging.create_tagging(%{tag_id: tag.id, issue_id: issue.id}, scope: scope)
    end

    test "the same tag can be attached to different records", %{scope: scope} do
      one = issue_fixture(scope)
      two = issue_fixture(scope)
      {:ok, tag} = Tagging.create_tag(%{name: "shared"}, scope: scope)

      assert {:ok, _} = Tagging.create_tagging(%{tag_id: tag.id, issue_id: one.id}, scope: scope)
      assert {:ok, _} = Tagging.create_tagging(%{tag_id: tag.id, issue_id: two.id}, scope: scope)
    end

    test "deleting a tag removes its attachments", %{scope: scope} do
      issue = issue_fixture(scope)
      {:ok, tag} = Tagging.create_tag(%{name: "going"}, scope: scope)
      {:ok, _} = Tagging.create_tagging(%{tag_id: tag.id, issue_id: issue.id}, scope: scope)

      :ok = Tagging.delete_tag(tag, scope: scope)

      assert Tagging.list_taggings!(scope: scope) == []
      assert {:error, _} = Tagging.get_tag(tag.id, scope: scope)
    end
  end

  describe "isolation" do
    test "tags don't leak across organizations", %{scope: scope} do
      {:ok, _} = Tagging.create_tag(%{name: "mine"}, scope: scope)

      {other_user, other_org} = Fleetms.AccountsFixtures.user_with_org_fixture()
      other_scope = Fleetms.Scope.new(other_user, other_org, true)

      assert Tagging.list_tags!(scope: other_scope) == []
      # A same-named tag in another org is allowed (separate vocabulary).
      assert {:ok, _} = Tagging.create_tag(%{name: "mine"}, scope: other_scope)
    end
  end
end
