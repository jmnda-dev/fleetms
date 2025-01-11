defmodule Fleetms.Dashboard.FuelStats do
  @derive {Jason.Encoder, only: [:colors, :series]}
  defstruct colors: [], series: [], categories: [], period: nil

  def get_dashboard_stats(tenant, opts \\ []) do
    formatted_data =
      Fleetms.FuelManagement.FuelHistory.get_dashboard_stats!(tenant, opts[:period])
      |> format_data_for_bar_chart_series()

    series = create_series(formatted_data)
    categories = Map.get(formatted_data, :categories, [])

    %__MODULE__{
      colors: opts[:colors],
      series: series,
      categories: categories,
      period: opts[:period]
    }
  end

  defp format_data_for_bar_chart_series(data) do
    initial_accumulator = %{
      total_cost_series: [],
      # total_quantity_series: [],
      total_cost_diesel_series: [],
      # total_quantity_diesel_series: [],
      total_cost_gasoline_series: [],
      # total_quantity_gasoline_series: [],
      total_cost_other_series: [],
      # total_quantity_other_series: [],
      categories: []
    }

    Enum.reduce(
      data,
      initial_accumulator,
      fn %{
           duration: duration,
           total_cost: total_cost,
          #  total_quantity: total_quantity,
           total_cost_diesel: total_cost_diesel,
          #  total_quantity_diesel: total_quantity_diesel,
           total_cost_gasoline: total_cost_gasoline,
          #  total_quantity_gasoline: total_quantity_gasoline,
           total_cost_other: total_cost_other,
          #  total_quantity_other: total_quantity_other
         },
         acc ->
        accumulated_total_cost_series = acc.total_cost_series
        # accumulated_total_quantity_series = acc.total_quantity_series
        accumulated_total_cost_diesel_series = acc.total_cost_diesel_series
        # accumulated_total_quantity_diesel_series = acc.total_quantity_diesel_series
        accumulated_total_cost_gasoline_series = acc.total_cost_gasoline_series
        # accumulated_total_quantity_gasoline_series = acc.total_quantity_gasoline_series
        accumulated_total_cost_other_series = acc.total_cost_other_series
        # accumulated_total_quantity_other_series = acc.total_quantity_other_series
        accumulated_categories = acc.categories

        %{
          acc
          | total_cost_series: List.insert_at(accumulated_total_cost_series, -1, total_cost),
            # total_quantity_series:
            #   List.insert_at(accumulated_total_quantity_series, -1, total_quantity),
            total_cost_diesel_series:
              List.insert_at(accumulated_total_cost_diesel_series, -1, total_cost_diesel),
            # total_quantity_diesel_series:
            #   List.insert_at(accumulated_total_quantity_diesel_series, -1, total_quantity_diesel),
            total_cost_gasoline_series:
              List.insert_at(accumulated_total_cost_gasoline_series, -1, total_cost_gasoline),
            # total_quantity_gasoline_series:
            #   List.insert_at(
            #     accumulated_total_quantity_gasoline_series,
            #     -1,
            #     total_quantity_gasoline
            #   ),
            total_cost_other_series:
              List.insert_at(accumulated_total_cost_other_series, -1, total_cost_other),
            # total_quantity_other_series:
            #   List.insert_at(accumulated_total_quantity_other_series, -1, total_quantity_other),
            categories: List.insert_at(accumulated_categories, -1, duration)
        }
      end
    )
  end

  defp create_series(formatted_series) do
    # See https://apexcharts.com/javascript-chart-demos/column-charts/grouped-stacked-columns regarding how data
    # should be formatted.
    %{
      total_cost_series: total_cost_series,
      # total_quantity_series: total_quantity_series,
      total_cost_diesel_series: total_cost_diesel_series,
      # total_quantity_diesel_series: total_quantity_diesel_series,
      total_cost_gasoline_series: total_cost_gasoline_series,
      # total_quantity_gasoline_series: total_quantity_gasoline_series,
      total_cost_other_series: total_cost_other_series,
      # total_quantity_other_series: total_quantity_other_series
    } = formatted_series

    [
      Fleetms.Dashboard.Series.new("Total Cost",
        data: total_cost_series,
        group: :total,
        fuel: true
      ),
      # Fleetms.Dashboard.Series.new("Total Quantity",
      #   data: total_quantity_series,
      #   group: :total,
      #   fuel: true
      # ),
      Fleetms.Dashboard.Series.new("Total Cost Diesel",
        data: total_cost_diesel_series,
        group: :total_diesel,
        fuel: true
      ),
      # Fleetms.Dashboard.Series.new("Total Quantity Diesel",
      #   data: total_quantity_diesel_series,
      #   group: :total_diesel,
      #   fuel: true
      # ),
      Fleetms.Dashboard.Series.new("Total Cost Gasoline",
        data: total_cost_gasoline_series,
        group: :total_gasoline,
        fuel: true
      ),
      # Fleetms.Dashboard.Series.new("Total Quantity Gasoline",
      #   data: total_quantity_gasoline_series,
      #   group: :total_gasoline,
      #   fuel: true
      # ),
      Fleetms.Dashboard.Series.new("Total Cost Other",
        data: total_cost_other_series,
        group: :total_other,
        fuel: true
      ),
      # Fleetms.Dashboard.Series.new("Total Quantity Other",
      #   data: total_quantity_other_series,
      #   group: :total_other,
      #   fuel: true
      # )
    ]
  end
end
