defmodule Fleetms.Dashboard.IssueStats do
  defstruct total: 0,
            open: 0,
            closed: 0,
            resolved: 0,
            high_priority: [],
            medium_priority: [],
            low_or_none_priority: [],
            series: [],
            labels: []

  def get_dashboard_stats(tenant, opts \\ []) do
    {issues_by_status, issues_by_priorities} = Fleetms.VehicleIssues.Issue.get_dashboard_stats!(tenant)

    %{total: total, open: open, closed: closed, resolved: resolved} = issues_by_status
    %{high: high, medium: medium, low_or_none: low_or_none} = issues_by_priorities

    series = [open, closed, resolved]

    %__MODULE__{
      labels: opts[:labels] || [],
      total: total,
      open: open,
      closed: closed,
      resolved: resolved,
      series: series,
      high_priority: high,
      medium_priority: medium,
      low_or_none_priority: low_or_none
    }
  end
end
