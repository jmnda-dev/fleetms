defmodule Fleetms.Contacts.ContactTest do
  @moduledoc "Contacts: create, search, filter by type, archive/restore."
  use Fleetms.DataCase, async: true

  alias Fleetms.Contacts

  setup :shared_org

  defp contact_attrs(overrides \\ %{}) do
    Enum.into(overrides, %{name: "Acme Parts", contact_type: :supplier})
  end

  test "creates and searches contacts", %{scope: scope} do
    Contacts.create_contact!(contact_attrs(%{name: "Acme Parts"}), scope: scope)

    Contacts.create_contact!(contact_attrs(%{name: "ZedInsure", contact_type: :insurer}),
      scope: scope
    )

    assert length(Contacts.list_contacts!(%{}, scope: scope).results) == 2

    found = Contacts.list_contacts!(%{search_query: "ZedInsure"}, scope: scope).results
    assert [%{name: "ZedInsure"}] = found
  end

  test "filters by contact type", %{scope: scope} do
    Contacts.create_contact!(contact_attrs(%{name: "Acme Parts", contact_type: :supplier}),
      scope: scope
    )

    Contacts.create_contact!(contact_attrs(%{name: "ZedInsure", contact_type: :insurer}),
      scope: scope
    )

    insurers = Contacts.list_contacts!(%{contact_type: :insurer}, scope: scope).results
    assert [%{name: "ZedInsure"}] = insurers
  end

  test "archiving hides a contact from the active list and restore brings it back", %{
    scope: scope
  } do
    contact = Contacts.create_contact!(contact_attrs(), scope: scope)

    :ok = Contacts.delete_contact!(contact, scope: scope)
    assert Contacts.list_contacts!(%{}, scope: scope).results == []
    assert [%{id: id} = archived] = Contacts.list_archived_contacts!(%{}, scope: scope).results
    assert id == contact.id

    Contacts.restore_contact!(archived, %{}, scope: scope)
    assert [%{id: ^id}] = Contacts.list_contacts!(%{}, scope: scope).results
  end

  test "requires a name", %{scope: scope} do
    assert {:error, %Ash.Error.Invalid{}} =
             Contacts.create_contact(%{contact_type: :vendor}, scope: scope)
  end
end
