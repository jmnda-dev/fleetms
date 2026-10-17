defmodule Fleetms.Contacts.ContactType do
  @moduledoc "What kind of external party a contact represents."
  use Ash.Type.Enum,
    values: [:vendor, :supplier, :insurer, :inspector, :towing, :regulator, :other]
end
