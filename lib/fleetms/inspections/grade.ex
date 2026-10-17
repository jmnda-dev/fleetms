defmodule Fleetms.Inspections.Grade do
  @moduledoc """
  Grades a filled inspection: given a form version's schema and the raw answers,
  computes each answerable item's status, the overall pass/fail result, and the
  list of failure rows.

  Pure and side-effect free — the submit action calls this and persists the
  result. What counts as a *failure* is intrinsic to each item's config (a chosen
  fail option, a number outside its passing range, a decreasing meter reading, a
  date on the wrong side of today). Informational items (text, photo, signature)
  never fail; instructions are not answerable and are skipped entirely.

  Items hidden by a `visible_when` condition grade as `:skipped` and never fail:
  statuses are computed once naively, then any item whose condition is unmet
  (evaluated against those statuses/values) is skipped before the result and
  failures are tallied.
  """
  alias Fleetms.Inspections.{Condition, Schema}

  @answerable ~w(pass_fail number meter single_select multi_select text date photo signature)a

  @doc """
  Returns `%{result:, answers:, failures:}` for `raw_answers` against `schema`.

  `raw_answers` is a list of maps with `item_id` plus a `value` (or `values` for
  multi-select) and optional `comment` (string or atom keys). Pass the vehicle's
  current odometer as `:vehicle_mileage` so meter items can enforce non-decrease.
  """
  def grade(%Schema{} = schema, raw_answers, opts \\ []) do
    mileage = Keyword.get(opts, :vehicle_mileage)
    by_id = index_answers(raw_answers)

    # Pass 1: a naive status for each item (paired with its section), ignoring
    # visibility.
    graded =
      for section <- schema.sections, item <- section.items, answerable?(item) do
        {section, item, grade_item(item, Map.get(by_id, item.id, %{}), mileage)}
      end

    # Pass 2: skip an item whose own or whose section's visible_when is unmet
    # (evaluated against pass 1), so hidden items never fail or count.
    context = %{
      answers: Map.new(graded, fn {_section, _item, g} -> {g.item_id, g.value} end),
      statuses: Map.new(graded, fn {_section, _item, g} -> {g.item_id, g.status} end)
    }

    graded =
      Enum.map(graded, fn {section, item, g} ->
        if visible?(section, item, context), do: g, else: %{g | status: :skipped}
      end)

    failures =
      for g <- graded, g.status == :fail do
        %{item_id: g.item_id, item_label: g.label, value_snapshot: g.snapshot, comment: g.comment}
      end

    answers =
      Enum.map(
        graded,
        &Map.take(&1, [:item_id, :type, :value, :values, :comment, :photos, :signature, :status])
      )

    %{result: overall_result(schema.settings, failures), answers: answers, failures: failures}
  end

  @doc """
  Naive per-item status map (`%{item_id => status}`) ignoring visibility — used by
  the fill UI to decide comment prompts and, together with the answer values, to
  evaluate `visible_when` conditions as the form is filled.
  """
  def statuses(%Schema{} = schema, raw_answers, opts \\ []) do
    mileage = Keyword.get(opts, :vehicle_mileage)
    by_id = index_answers(raw_answers)

    for section <- schema.sections, item <- section.items, answerable?(item), into: %{} do
      {item.id, grade_item(item, Map.get(by_id, item.id, %{}), mileage).status}
    end
  end

  defp answerable?(item), do: item.config.type in @answerable

  # An item counts only when both its section and the item itself are visible.
  defp visible?(section, item, context) do
    Condition.visible?(section.visible_when, context) and
      Condition.visible?(item.visible_when, context)
  end

  defp grade_item(item, raw, mileage) do
    type = item.config.type
    cfg = item.config.value
    value = fetch(raw, "value")
    values = fetch(raw, "values") || []
    comment = fetch(raw, "comment")

    %{
      item_id: item.id,
      type: type,
      value: value,
      values: values,
      comment: comment,
      photos: fetch(raw, "photos") || [],
      signature: fetch(raw, "signature"),
      status: status(type, cfg, value, values, mileage),
      label: item.label,
      snapshot: snapshot(type, value, values)
    }
  end

  defp status(:pass_fail, _cfg, value, _values, _mileage) do
    case value do
      "fail" -> :fail
      "pass" -> :pass
      "na" -> :na
      _ -> :skipped
    end
  end

  defp status(:number, cfg, value, _values, _mileage) do
    case parse_decimal(value) do
      nil -> :skipped
      dec -> if in_range?(dec, cfg.pass_min, cfg.pass_max), do: :pass, else: :fail
    end
  end

  defp status(:meter, cfg, value, _values, mileage) do
    case parse_decimal(value) do
      nil ->
        :skipped

      dec ->
        if cfg.must_increase && mileage && Decimal.compare(dec, mileage) == :lt,
          do: :fail,
          else: :pass
    end
  end

  defp status(:single_select, cfg, value, _values, _mileage) do
    cond do
      blank?(value) -> :skipped
      fail_option?(cfg.options, value) -> :fail
      true -> :pass
    end
  end

  defp status(:multi_select, cfg, _value, values, _mileage) do
    cond do
      values in [nil, []] -> :skipped
      cfg.fail_if_any_fail_option and Enum.any?(values, &fail_option?(cfg.options, &1)) -> :fail
      true -> :pass
    end
  end

  defp status(:date, cfg, value, _values, _mileage) do
    case parse_date(value) do
      nil ->
        :skipped

      date ->
        today = Date.utc_today()

        cond do
          cfg.fail_if_past and Date.compare(date, today) == :lt -> :fail
          cfg.fail_if_future and Date.compare(date, today) == :gt -> :fail
          true -> :pass
        end
    end
  end

  # text, photo, signature — informational, never fail
  defp status(_type, _cfg, value, values, _mileage) do
    if not blank?(value) or values not in [nil, []], do: :answered, else: :skipped
  end

  defp overall_result(%{pass_policy: :threshold, fail_threshold: threshold}, failures) do
    if length(failures) > (threshold || 0), do: :failed, else: :passed
  end

  defp overall_result(_settings, failures) do
    if failures == [], do: :passed, else: :failed
  end

  defp in_range?(dec, min, max) do
    (is_nil(min) or Decimal.compare(dec, min) != :lt) and
      (is_nil(max) or Decimal.compare(dec, max) != :gt)
  end

  defp fail_option?(options, value) do
    Enum.any?(options, fn option -> option.value == value and option.fail? end)
  end

  defp snapshot(:multi_select, _value, values), do: Enum.join(values || [], ", ")
  defp snapshot(_type, value, _values), do: to_string(value || "")

  defp index_answers(raw_answers) do
    Map.new(raw_answers, fn answer -> {fetch(answer, "item_id"), answer} end)
  end

  defp fetch(map, key), do: Map.get(map, key) || Map.get(map, String.to_existing_atom(key))

  defp blank?(value), do: value in [nil, ""]

  defp parse_decimal(value) when is_integer(value), do: Decimal.new(value)
  defp parse_decimal(value) when is_float(value), do: Decimal.from_float(value)

  defp parse_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _rest} -> decimal
      :error -> nil
    end
  end

  defp parse_decimal(_value), do: nil

  defp parse_date(value) when is_binary(value) and byte_size(value) >= 10 do
    case Date.from_iso8601(String.slice(value, 0, 10)) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_date(_value), do: nil
end
