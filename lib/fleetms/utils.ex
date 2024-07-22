defmodule Fleetms.Utils do
  @moduledoc """
  This modules contains utility/helper functions used the Elixir code of this project.
  """

  def parse_reminder_time_interval_shift_unit(unit) do
    case unit do
      :"Day(s)" ->
        :days

      :"Week(s)" ->
        :weeks

      :"Month(s)" ->
        :months

      :"Year(s)" ->
        :years
    end
  end

  def parse_int(int_string, opts \\ [default: 0]) do
    case Integer.parse(int_string) do
      {integer, _rest} ->
        integer

      :error ->
        opts[:default]
    end
  end

  @doc """
  Calculates the total number of pages from the given values.
  """
  def calc_total_pages(total_items, per_page) do
    (total_items / per_page) |> Float.ceil() |> round()
  end

  @doc """
  Converts dates in a given map to strings
  """
  def dates_in_map_to_string(map, keys) do
    Enum.reduce(keys, map, fn key, acc ->
      Map.update(acc, key, nil, fn value ->
        if value == "" or is_nil(value), do: nil, else: Date.to_string(value)
      end)
    end)
  end

  def beginning_of_year(date \\ Date.utc_today()) do
    Timex.beginning_of_year(date)
  end

  def end_of_year(date \\ Date.utc_today()) do
    Timex.end_of_year(date)
  end

  def beginning_of_month(date \\ Date.utc_today()) do
    Timex.beginning_of_month(date)
  end

  def end_of_month(date \\ Date.utc_today()) do
    Timex.end_of_month(date)
  end

  def beginning_of_week(date \\ Date.utc_today()) do
    Timex.beginning_of_week(date)
  end

  def end_of_week(date \\ Date.utc_today()) do
    Timex.end_of_week(date)
  end

  @doc """
  Converts a list of atoms into a Keyword list that can be used for example, in HTML select inputs.

  ## Examples
      iex> atom_list_to_options_for_select([:due_for_service, :upcoming, :overdue])
      [
        {"Due For Service", :due_for_service},
        {"Upcoming", :upcoming},
        {"Overdue", :overdue}
      ]
  """
  def atom_list_to_options_for_select(list) do
    Enum.map(list, &{humanize_string(&1), &1})
  end

  @doc """
  Humanizes a string

  ## Examples
      iex> humanize_string(:due_for_service)
      "Due For Service"

      iex> humanize_string("due_for_service")
      "Due For Service"
  """
  def humanize_string(string) when is_atom(string) do
    string
    |> Atom.to_string()
    |> humanize_string()
  end

  def humanize_string(string) do
    new_string =
      string
      |> String.replace(~r/_/, " ")
      |> String.split()
      |> Enum.map(&String.capitalize(&1))
      |> Enum.join(" ")

    new_string
  end
end
