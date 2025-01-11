defmodule Fleetms.Dashboard.InspectionStats do
  @derive {Jason.Encoder, only: [:colors, :series]}
  defstruct colors: [], series: [], total: 0

  def get_dashboard_stats(tenant, opts \\ []) do
    {total, data} =
      Fleetms.VehicleInspection.InspectionSubmission.get_dashboard_stats!(
        tenant,
        opts[:period]
      )

    series =
      data
      |> format_data_for_bar_chart_series()
      |> create_series()

    %__MODULE__{
      colors: opts[:colors] || ["#1A56DB", "#FDBA8C", "#FDBA8C"],
      series: series,
      total: total
    }
  end

  defp format_data_for_bar_chart_series(data) do
    initial_accumulator = %{total_series: [], passed_series: [], failed_series: []}

    Enum.reduce(
      data,
      initial_accumulator,
      fn %{
           failed: failed,
           passed: passed,
           total: total,
           duration: duration
         },
         acc ->
        accumulated_total_series = acc.total_series
        accumulated_passed_series = acc.passed_series
        accumulated_failed_series = acc.failed_series

        %{
          acc
          | total_series: List.insert_at(accumulated_total_series, -1, %{x: duration, y: total}),
            passed_series:
              List.insert_at(accumulated_passed_series, -1, %{x: duration, y: passed}),
            failed_series:
              List.insert_at(accumulated_failed_series, -1, %{x: duration, y: failed})
        }
      end
    )
  end

  defp create_series(
         %{failed_series: f_series, passed_series: p_series, total_series: t_series} = _series
       ) do
    [
      Fleetms.Dashboard.Series.new("Total Inspections", color: "#1A56DB", data: t_series),
      Fleetms.Dashboard.Series.new("Passed Inspections", color: "#17B0BD", data: p_series),
      Fleetms.Dashboard.Series.new("Failed Inspections", color: "#FDBA8C", data: f_series)
    ]
  end
end
