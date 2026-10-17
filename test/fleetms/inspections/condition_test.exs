defmodule Fleetms.Inspections.ConditionTest do
  use ExUnit.Case, async: true

  alias Fleetms.Inspections.Condition

  defp ctx(answers, statuses), do: %{answers: answers, statuses: statuses}

  test "nil or empty condition is always visible" do
    assert Condition.visible?(nil, ctx(%{}, %{}))
    assert Condition.visible?(%{}, ctx(%{}, %{}))
  end

  test "eq / neq compare the referenced item's value" do
    context = ctx(%{"trailer" => "yes"}, %{})
    assert Condition.visible?(rule("trailer", "eq", "yes"), context)
    refute Condition.visible?(rule("trailer", "eq", "no"), context)
    assert Condition.visible?(rule("trailer", "neq", "no"), context)
  end

  test "answered / failed use status" do
    context = ctx(%{}, %{"brakes" => :fail, "lights" => :skipped})
    assert Condition.visible?(rule("brakes", "failed", nil), context)
    assert Condition.visible?(rule("brakes", "answered", nil), context)
    refute Condition.visible?(rule("lights", "answered", nil), context)
    refute Condition.visible?(rule("lights", "failed", nil), context)
  end

  test "numeric comparisons parse string values" do
    context = ctx(%{"psi" => "26"}, %{})
    assert Condition.visible?(rule("psi", "lt", 30), context)
    assert Condition.visible?(rule("psi", "lte", 26), context)
    refute Condition.visible?(rule("psi", "gt", 30), context)
  end

  test "in checks membership" do
    context = ctx(%{"tyre" => "worn"}, %{})
    assert Condition.visible?(rule("tyre", "in", ["worn", "damaged"]), context)
    refute Condition.visible?(rule("tyre", "in", ["good"]), context)
  end

  test "all / any / not combine rules" do
    context = ctx(%{"a" => "1", "b" => "2"}, %{})

    all = %{"op" => "all", "rules" => [rule("a", "eq", "1"), rule("b", "eq", "2")]}
    assert Condition.visible?(all, context)

    any = %{"op" => "any", "rules" => [rule("a", "eq", "9"), rule("b", "eq", "2")]}
    assert Condition.visible?(any, context)

    negate = %{"op" => "not", "rules" => [rule("a", "eq", "9")]}
    assert Condition.visible?(negate, context)

    refute Condition.visible?(%{"op" => "all", "rules" => [rule("a", "eq", "9")]}, context)
  end

  test "nested groups" do
    context = ctx(%{"a" => "1", "b" => "2", "c" => "3"}, %{})

    condition = %{
      "op" => "all",
      "rules" => [
        rule("a", "eq", "1"),
        %{"op" => "any", "rules" => [rule("b", "eq", "9"), rule("c", "eq", "3")]}
      ]
    }

    assert Condition.visible?(condition, context)
  end

  defp rule(item, op, value),
    do: %{"op" => "all", "rules" => [%{"item" => item, "op" => op, "value" => value}]}
end
