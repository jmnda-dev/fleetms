defmodule Fleetms.VehicleManagement.VehicleImport do
  @moduledoc """
  Bulk-import vehicles from a CSV file — the onboarding path for a new customer who
  already has a fleet in a spreadsheet.

  The flow is two-step: `preview/1` parses + validates the rows and reports what will
  happen (without touching the database), then `run/2` creates the valid vehicles,
  upserting makes/models by name as it goes and reporting per-row results.

  Columns (header row, case-insensitive, spaces or underscores both fine):

    - `name` *(required)*
    - `type` *(required)* — one of the vehicle types, e.g. "Truck", "Pickup Truck", "Van"
    - `category`, `status` — optional, matched against the allowed values
    - `make`, `model` — optional; looked up / created by name
    - `year`, `license_plate`, `vin`, `color`, `mileage`, `purchase_date`, `notes` — optional

  Unknown columns are ignored, so an export from another tool can usually be fed in as-is.
  """
  alias Fleetms.VehicleManagement
  alias Fleetms.VehicleManagement.{VehicleCategory, VehicleStatus, VehicleType}

  NimbleCSV.define(__MODULE__.Parser, [])

  @known_columns ~w(name type category status make model year license_plate vin color mileage purchase_date notes)

  @doc "The example template a user can download to see the expected columns."
  def template_rows do
    [
      @known_columns,
      [
        "Rigid 8T #1",
        "Truck",
        "Commercial Trucks",
        "Active",
        "Isuzu",
        "FVR",
        "2021",
        "ABC 1234",
        "JALFVR33P07000000",
        "White",
        "82000",
        "2021-03-15",
        "Bought from the Lusaka branch"
      ]
    ]
  end

  @doc """
  Parses + validates CSV content without writing anything. Returns
  `{:ok, [row_result]}` or `{:error, message}` when the file itself can't be read.

  Each `row_result` is `%{line: n, data: %{...}, name:, errors: [..]}`; a row with an
  empty `errors` list will import cleanly.
  """
  def preview(content) when is_binary(content) do
    case parse(content) do
      {:ok, []} ->
        {:error, "The file has a header row but no data rows."}

      {:ok, rows} ->
        {:ok, rows |> Enum.with_index(2) |> Enum.map(fn {row, line} -> validate(row, line) end)}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Creates vehicles from previously-previewed rows. Only rows with no validation errors
  are attempted. Returns `%{created: n, failed: [%{line:, name:, error:}], skipped: n}`.
  """
  def run(scope, row_results) when is_list(row_results) do
    {valid, invalid} = Enum.split_with(row_results, &(&1.errors == []))

    results =
      Enum.map(valid, fn row ->
        case create_one(scope, row) do
          {:ok, _vehicle} -> {:ok, row}
          {:error, message} -> {:error, %{line: row.line, name: row.name, error: message}}
        end
      end)

    %{
      created: Enum.count(results, &match?({:ok, _}, &1)),
      failed: for({:error, f} <- results, do: f),
      skipped: length(invalid)
    }
  end

  # --- parsing ---

  defp parse(content) do
    case __MODULE__.Parser.parse_string(content, skip_headers: false) do
      [] ->
        {:error, "The file is empty."}

      [header | rows] ->
        keys = Enum.map(header, &normalize_key/1)
        {:ok, Enum.map(rows, fn cols -> keys |> Enum.zip(cols) |> Map.new() end)}
    end
  rescue
    _ -> {:error, "That doesn't look like a valid CSV file."}
  end

  defp normalize_key(key) do
    key |> to_string() |> String.trim() |> String.downcase() |> String.replace(~r/[\s-]+/, "_")
  end

  # --- validation (no DB writes) ---

  defp validate(row, line) do
    name = trimmed(row["name"])
    errors = []

    {type, errors} = check_enum(row["type"], VehicleType.values(), :required, "type", errors)

    {_category, errors} =
      check_enum(row["category"], VehicleCategory.values(), :optional, "category", errors)

    {_status, errors} =
      check_enum(row["status"], VehicleStatus.values(), :optional, "status", errors)

    errors = if name in [nil, ""], do: ["name is required" | errors], else: errors
    {_year, errors} = check_integer(row["year"], "year", errors)
    {_mileage, errors} = check_decimal(row["mileage"], "mileage", errors)
    {_date, errors} = check_date(row["purchase_date"], "purchase_date", errors)

    %{line: line, data: row, name: name || "(unnamed)", type: type, errors: Enum.reverse(errors)}
  end

  defp check_enum(value, values, requirement, field, errors) do
    case trimmed(value) do
      v when v in [nil, ""] ->
        if requirement == :required,
          do: {nil, ["#{field} is required" | errors]},
          else: {nil, errors}

      v ->
        case match_enum(v, values) do
          nil ->
            allowed = Enum.map_join(values, ", ", &to_string/1)
            {nil, [~s(#{field} "#{v}" is not one of: #{allowed}) | errors]}

          atom ->
            {atom, errors}
        end
    end
  end

  defp match_enum(value, values) do
    down = String.downcase(value)
    Enum.find(values, &(String.downcase(to_string(&1)) == down))
  end

  defp check_integer(value, _field, errors) when value in [nil, ""], do: {nil, errors}

  defp check_integer(value, field, errors) do
    case Integer.parse(String.trim(value)) do
      {n, ""} -> {n, errors}
      _ -> {nil, [~s(#{field} "#{value}" is not a whole number) | errors]}
    end
  end

  defp check_decimal(value, _field, errors) when value in [nil, ""], do: {nil, errors}

  defp check_decimal(value, field, errors) do
    case Decimal.parse(String.trim(value)) do
      {dec, ""} -> {dec, errors}
      _ -> {nil, [~s(#{field} "#{value}" is not a number) | errors]}
    end
  end

  defp check_date(value, _field, errors) when value in [nil, ""], do: {nil, errors}

  defp check_date(value, field, errors) do
    case Date.from_iso8601(String.trim(value)) do
      {:ok, date} -> {date, errors}
      _ -> {nil, [~s(#{field} "#{value}" must be a date like 2021-03-15) | errors]}
    end
  end

  # --- creation ---

  defp create_one(scope, row) do
    data = row.data

    attrs =
      %{
        name: row.name,
        type: row.type,
        category: match_enum(trimmed(data["category"]) || "", VehicleCategory.values()),
        status: match_enum(trimmed(data["status"]) || "", VehicleStatus.values()),
        license_plate: trimmed(data["license_plate"]),
        vin: trimmed(data["vin"]),
        color: trimmed(data["color"]),
        notes: trimmed(data["notes"]),
        year: parse_int(data["year"]),
        mileage: parse_dec(data["mileage"]),
        purchase_date: parse_date(data["purchase_date"]),
        vehicle_model_id: resolve_model(scope, data["make"], data["model"])
      }
      |> drop_blank()

    case VehicleManagement.create_vehicle(attrs, scope: scope) do
      {:ok, vehicle} -> {:ok, vehicle}
      {:error, error} -> {:error, error_message(error)}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  # Upserts the make then the model (by name) and returns the model id, or nil when no
  # make is given. A model needs a make, so a model without a make is ignored.
  defp resolve_model(scope, make, model) do
    make = trimmed(make)
    model = trimmed(model)

    with true <- make not in [nil, ""],
         {:ok, make_rec} <- VehicleManagement.upsert_vehicle_make(%{name: make}, scope: scope),
         true <- model not in [nil, ""],
         {:ok, model_rec} <-
           VehicleManagement.upsert_vehicle_model(
             %{name: model, vehicle_make_id: make_rec.id},
             scope: scope
           ) do
      model_rec.id
    else
      _ -> nil
    end
  end

  defp drop_blank(attrs) do
    attrs |> Enum.reject(fn {_k, v} -> v in [nil, ""] end) |> Map.new()
  end

  defp trimmed(nil), do: nil
  defp trimmed(v), do: v |> to_string() |> String.trim()

  defp parse_int(v) do
    case Integer.parse(trimmed(v) || "") do
      {n, _} -> n
      _ -> nil
    end
  end

  defp parse_dec(v) do
    case Decimal.parse(trimmed(v) || "") do
      {d, _} -> d
      _ -> nil
    end
  end

  defp parse_date(v) do
    case Date.from_iso8601(trimmed(v) || "") do
      {:ok, d} -> d
      _ -> nil
    end
  end

  defp error_message(error) when is_exception(error) do
    error |> Exception.message() |> first_line()
  rescue
    _ -> "could not be created"
  end

  defp error_message(_), do: "could not be created"

  # Ash errors print a multi-line summary; the first substantive line (minus any
  # bullet/marker) is enough for a per-row message in the results table.
  defp first_line(message) do
    message
    |> String.split("\n", trim: true)
    |> Enum.map(&(&1 |> String.trim() |> String.trim_leading("* ")))
    |> Enum.find(message, &(&1 =~ ~r/[a-zA-Z]/))
  end
end
