defmodule Fleetms.Maintenance.ServiceReminderStatus do
  @moduledoc """
  How due a service reminder is, derived live from the vehicle's current meter and
  today's date against the reminder's next-due point:

    * `:upcoming` — not yet within the "due soon" lead.
    * `:due_soon` — inside the mileage/time threshold before it falls due.
    * `:overdue` — at or past the next-due mileage or date.
  """
  use Ash.Type.Enum, values: [:upcoming, :due_soon, :overdue]
end
