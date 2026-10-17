defmodule Fleetms.Billing.Workers.SweepSubscriptions do
  @moduledoc """
  Periodic sweep (daily cron) that advances subscriptions through their lifecycle:
  lapsed active → past_due (+ renewal invoice), and past_due beyond grace → expired.
  The work itself lives in `Fleetms.Billing.Lifecycle`.
  """
  use Oban.Worker, queue: :billing, max_attempts: 3

  @impl Oban.Worker
  def perform(_job), do: Fleetms.Billing.Lifecycle.run()
end
