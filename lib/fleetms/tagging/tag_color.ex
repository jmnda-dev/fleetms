defmodule Fleetms.Tagging.TagColor do
  @moduledoc """
  The palette a tag chip can use. A curated set so chips stay legible in light and dark
  mode; a new tag is auto-assigned one (see `Tag.Changes.AssignColor`) and it can be
  changed later on the tag management page.
  """
  use Ash.Type.Enum,
    values: [:slate, :red, :orange, :amber, :green, :teal, :blue, :indigo, :purple, :pink]
end
