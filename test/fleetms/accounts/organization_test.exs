defmodule Fleetms.Accounts.OrganizationTest do
  # Not async: this suite provisions real organization tenant schemas (DDL), and
  # running several of those concurrently can deadlock on the shared migration
  # locks. See Fleetms.SharedTenant for why feature tests don't pay this cost.
  use ExUnit.Case, async: false

  alias Fleetms.Accounts.Organization

  test "display settings have sensible defaults (metric, ZMW, UTC, iso)" do
    assert Ash.Resource.Info.attribute(Organization, :unit_system).default == :metric
    assert Ash.Resource.Info.attribute(Organization, :currency).default == "ZMW"
    assert Ash.Resource.Info.attribute(Organization, :timezone).default == "Etc/UTC"
    assert Ash.Resource.Info.attribute(Organization, :date_format).default == :iso
  end

  test "generates an opaque 12-char public_id when building a create changeset" do
    changeset =
      Ash.Changeset.for_create(Organization, :create, %{
        name: "Acme",
        owner_user_id: Ash.UUID.generate()
      })

    public_id = Ash.Changeset.get_attribute(changeset, :public_id)

    assert is_binary(public_id)
    assert public_id =~ ~r/^[a-z2-7]{12}$/
  end

  test "generates a different public_id each time" do
    gen = fn ->
      Organization
      |> Ash.Changeset.for_create(:create, %{name: "Acme", owner_user_id: Ash.UUID.generate()})
      |> Ash.Changeset.get_attribute(:public_id)
    end

    assert gen.() != gen.()
  end

  test "Phoenix.Param renders the public_id" do
    org = %Organization{public_id: "abc123def456"}
    assert Phoenix.Param.to_param(org) == "abc123def456"
  end
end
