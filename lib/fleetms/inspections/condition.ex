defmodule Fleetms.Inspections.Condition do
  @moduledoc """
  Evaluates an item's (or section's) `visible_when` predicate — the conditional
  logic that shows or hides it based on other items' answers.

  A condition is a small serializable tree: a group `%{"op" => "all"|"any"|"not",
  "rules" => [...]}` whose rules are either nested groups or leaf comparisons
  `%{"item" => id, "op" => cmp, "value" => v}`. Leaf ops:

    * `answered` / `failed` — check the referenced item's status
    * `eq` / `neq` / `in` — compare its answer value
    * `gt` / `gte` / `lt` / `lte` — numeric comparison of its answer value

  The same evaluator is used server-side while grading (so hidden items are
  skipped) and while filling (so items appear and disappear as answers change).
  A `nil`/empty condition means always visible.

  `context` is `%{answers: %{item_id => value}, statuses: %{item_id => status}}`.
  Maps use string keys (conditions are stored as plain jsonb).
  """

  def visible?(condition, _context) when condition in [nil, %{}], do: true

  def visible?(condition, context) do
    rules = get(condition, "rules") || []

    case get(condition, "op") do
      "any" -> Enum.any?(rules, &eval(&1, context))
      "not" -> not Enum.any?(rules, &eval(&1, context))
      _all -> Enum.all?(rules, &eval(&1, context))
    end
  end

  # A rule with "rules" is a nested group; otherwise it's a leaf comparison.
  defp eval(rule, context) do
    if is_nil(get(rule, "rules")),
      do: leaf(rule, context),
      else: visible?(rule, context)
  end

  defp leaf(rule, context) do
    item_id = get(rule, "item")
    value = Map.get(context.answers, item_id)
    status = Map.get(context.statuses, item_id)

    case get(rule, "op") do
      "answered" -> status not in [nil, :skipped]
      "failed" -> status == :fail
      "eq" -> to_string(value) == to_string(get(rule, "value"))
      "neq" -> to_string(value) != to_string(get(rule, "value"))
      "in" -> value in List.wrap(get(rule, "value"))
      "gt" -> compare(value, get(rule, "value")) == :gt
      "gte" -> compare(value, get(rule, "value")) in [:gt, :eq]
      "lt" -> compare(value, get(rule, "value")) == :lt
      "lte" -> compare(value, get(rule, "value")) in [:lt, :eq]
      _ -> true
    end
  end

  # Numeric comparison of two values that may be strings; unparseable -> :error
  # (never satisfies gt/lt/gte/lte).
  defp compare(a, b) do
    with x when not is_nil(x) <- to_number(a),
         y when not is_nil(y) <- to_number(b) do
      cond do
        x > y -> :gt
        x < y -> :lt
        true -> :eq
      end
    else
      _ -> :error
    end
  end

  defp to_number(value) when is_number(value), do: value

  defp to_number(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _rest} -> number
      :error -> nil
    end
  end

  defp to_number(_value), do: nil

  defp get(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, safe_atom(key))
  defp get(_map, _key), do: nil

  defp safe_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end
end
