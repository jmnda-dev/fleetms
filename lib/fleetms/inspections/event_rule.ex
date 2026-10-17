defmodule Fleetms.Inspections.EventRule do
  @moduledoc """
  When an item should require a follow-up (a comment or a photo), keyed to the
  answer's pass/fail outcome. Reused by several item configs for their
  `comment_on`/`photo_on` fields.
  """
  use Ash.Type.Enum, values: [:never, :pass, :fail, :always]
end
