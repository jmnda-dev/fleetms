defmodule Fleetms.Utils.DateTimeHelper do
  def humanize_duration(_start_date, end_date) when is_nil(end_date), do: "Ongoing"

  def humanize_duration(start_date, end_date) do
    duration = Timex.diff(end_date, start_date, :days)

    months = trunc(duration / 30)
    days = rem(duration, 30)

    months_str = if months > 0, do: "#{months} #{pluralize(months, "month")}, ", else: ""
    days_str = "#{days} #{pluralize(days, "day")}"

    "#{months_str}#{days_str}"
  end

  defp pluralize(1, singular), do: singular
  defp pluralize(_, singular), do: singular <> "s"
end
