defmodule Fleetms.Tagging.Tag.Changes.AssignColor do
  @moduledoc """
  Gives a new tag a colour when none was supplied. The colour is derived from the tag's
  name so the same name always lands on the same colour (stable chips), while still
  spreading different names across the palette.
  """
  use Ash.Resource.Change

  @colors Fleetms.Tagging.TagColor.values()

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :color) do
      nil ->
        name = changeset |> Ash.Changeset.get_attribute(:name) |> to_string()
        color = Enum.at(@colors, :erlang.phash2(name, length(@colors)))
        Ash.Changeset.force_change_attribute(changeset, :color, color)

      _already_set ->
        changeset
    end
  end
end
