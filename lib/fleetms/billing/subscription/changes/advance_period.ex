defmodule Fleetms.Billing.Subscription.Changes.AdvancePeriod do
  @moduledoc """
  Sets a subscription's billing period from its plan's interval.

  Option `:from`:

    * `:now`        — start a fresh period at `now` (activation). Sets
                      `current_period_start` and `started_at` (the latter only if
                      not already set).
    * `:period_end` — extend from the current period end (renewal). If the period
                      has already lapsed, it extends from `now` instead so the new
                      period is always in the future.
  """
  use Ash.Resource.Change

  @impl true
  def init(opts) do
    if opts[:from] in [:now, :period_end] do
      {:ok, opts}
    else
      {:error, "`:from` must be :now or :period_end"}
    end
  end

  @impl true
  def change(changeset, opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      plan = plan_for(changeset)
      now = DateTime.utc_now()
      base = base_time(opts[:from], changeset, now)
      period_end = shift(base, plan.interval, plan.interval_count)

      changeset
      |> then(fn cs ->
        if opts[:from] == :now do
          Ash.Changeset.force_change_attribute(cs, :current_period_start, base)
        else
          cs
        end
      end)
      |> Ash.Changeset.force_change_attribute(:current_period_end, period_end)
      |> set_started_at(now)
    end)
  end

  defp plan_for(changeset) do
    plan_id = Ash.Changeset.get_attribute(changeset, :plan_id)
    Ash.get!(Fleetms.Billing.Plan, plan_id, authorize?: false)
  end

  defp base_time(:now, _changeset, now), do: now

  defp base_time(:period_end, changeset, now) do
    case Ash.Changeset.get_attribute(changeset, :current_period_end) do
      %DateTime{} = period_end -> if DateTime.after?(period_end, now), do: period_end, else: now
      _ -> now
    end
  end

  defp shift(base, :month, count), do: DateTime.shift(base, month: count)
  defp shift(base, :year, count), do: DateTime.shift(base, year: count)

  defp set_started_at(changeset, now) do
    case Ash.Changeset.get_attribute(changeset, :started_at) do
      %DateTime{} -> changeset
      _ -> Ash.Changeset.force_change_attribute(changeset, :started_at, now)
    end
  end
end
