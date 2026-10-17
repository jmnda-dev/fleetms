defmodule Fleetms.Inspections.GradeTest do
  use ExUnit.Case, async: true

  alias Fleetms.Inspections.{Grade, Schema}

  defp schema(items, settings \\ %{}) do
    {:ok, s} =
      Ash.Type.cast_input(
        Schema,
        %{"settings" => settings, "sections" => [%{"id" => "s1", "items" => items}]},
        []
      )

    s
  end

  defp item(id, config), do: %{"id" => id, "label" => id, "config" => config}
  defp answer(id, value), do: %{"item_id" => id, "value" => value}

  defp grade(items, answers, opts \\ []) do
    Grade.grade(schema(items), answers, opts)
  end

  defp status_of(result, id) do
    Enum.find(result.answers, &(&1.item_id == id)).status
  end

  test "pass_fail: fail answer fails the item and the inspection" do
    items = [item("brakes", %{"type" => "pass_fail"})]

    fail = grade(items, [answer("brakes", "fail")])
    assert status_of(fail, "brakes") == :fail
    assert fail.result == :failed
    assert [%{item_id: "brakes", item_label: "brakes"}] = fail.failures

    pass = grade(items, [answer("brakes", "pass")])
    assert status_of(pass, "brakes") == :pass
    assert pass.result == :passed
    assert pass.failures == []
  end

  test "pass_fail: na and unanswered do not fail" do
    items = [item("x", %{"type" => "pass_fail"})]
    assert status_of(grade(items, [answer("x", "na")]), "x") == :na
    assert status_of(grade(items, []), "x") == :skipped
    assert grade(items, []).result == :passed
  end

  test "number: outside the passing range fails" do
    items = [item("psi", %{"type" => "number", "pass_min" => 30, "pass_max" => 35})]

    assert status_of(grade(items, [answer("psi", "26")]), "psi") == :fail
    assert status_of(grade(items, [answer("psi", "32")]), "psi") == :pass
    assert status_of(grade(items, [answer("psi", "40")]), "psi") == :fail
  end

  test "number: no passing range is informational" do
    items = [item("reading", %{"type" => "number"})]
    assert status_of(grade(items, [answer("reading", "999")]), "reading") == :pass
  end

  test "meter: a decreasing reading fails only when must_increase and mileage are known" do
    items = [item("odo", %{"type" => "meter", "must_increase" => true})]

    below = grade(items, [answer("odo", "900")], vehicle_mileage: Decimal.new(1000))
    assert status_of(below, "odo") == :fail

    above = grade(items, [answer("odo", "1100")], vehicle_mileage: Decimal.new(1000))
    assert status_of(above, "odo") == :pass

    # no known mileage -> cannot fail
    assert status_of(grade(items, [answer("odo", "900")]), "odo") == :pass
  end

  test "single_select: choosing a failing option fails" do
    config = %{
      "type" => "single_select",
      "options" => [
        %{"value" => "good", "label" => "Good"},
        %{"value" => "damaged", "label" => "Damaged", "fail?" => true}
      ]
    }

    items = [item("tyre", config)]
    assert status_of(grade(items, [answer("tyre", "damaged")]), "tyre") == :fail
    assert status_of(grade(items, [answer("tyre", "good")]), "tyre") == :pass
  end

  test "multi_select: any chosen failing option fails" do
    config = %{
      "type" => "multi_select",
      "fail_if_any_fail_option" => true,
      "options" => [
        %{"value" => "a", "label" => "A"},
        %{"value" => "b", "label" => "B", "fail?" => true}
      ]
    }

    result =
      Grade.grade(schema([item("m", config)]), [%{"item_id" => "m", "values" => ["a", "b"]}])

    assert status_of(result, "m") == :fail

    ok = Grade.grade(schema([item("m", config)]), [%{"item_id" => "m", "values" => ["a"]}])
    assert status_of(ok, "m") == :pass
  end

  test "date: fails on the wrong side of today" do
    items = [item("exp", %{"type" => "date", "fail_if_past" => true})]
    yesterday = Date.utc_today() |> Date.add(-1) |> Date.to_iso8601()
    tomorrow = Date.utc_today() |> Date.add(1) |> Date.to_iso8601()

    assert status_of(grade(items, [answer("exp", yesterday)]), "exp") == :fail
    assert status_of(grade(items, [answer("exp", tomorrow)]), "exp") == :pass
  end

  test "text is informational and instructions are not answerable" do
    items = [
      item("notes", %{"type" => "text"}),
      item("info", %{"type" => "instruction", "body" => "Read me"})
    ]

    result = grade(items, [answer("notes", "all good")])
    assert status_of(result, "notes") == :answered
    assert result.result == :passed
    # instruction items are skipped entirely — no answer row
    refute Enum.any?(result.answers, &(&1.item_id == "info"))
  end

  test "an item hidden by its condition is skipped and never fails" do
    # leak_detail (a pass/fail) is only shown when has_leak == "yes"
    detail =
      Map.put(item("leak_detail", %{"type" => "pass_fail"}), "visible_when", %{
        "op" => "all",
        "rules" => [%{"item" => "has_leak", "op" => "eq", "value" => "yes"}]
      })

    items = [
      item("has_leak", %{
        "type" => "single_select",
        "options" => [
          %{"value" => "yes", "label" => "Yes"},
          %{"value" => "no", "label" => "No"}
        ]
      }),
      detail
    ]

    # has_leak = no -> leak_detail hidden -> skipped even though answered "fail"
    hidden = grade(items, [answer("has_leak", "no"), answer("leak_detail", "fail")])
    assert status_of(hidden, "leak_detail") == :skipped
    assert hidden.result == :passed
    assert hidden.failures == []

    # has_leak = yes -> leak_detail visible and its fail counts
    shown = grade(items, [answer("has_leak", "yes"), answer("leak_detail", "fail")])
    assert status_of(shown, "leak_detail") == :fail
    assert shown.result == :failed
  end

  test "items in a section hidden by its condition are skipped and never fail" do
    # A two-section form: the second section is only shown when has_trailer == "yes".
    {:ok, s} =
      Ash.Type.cast_input(
        Schema,
        %{
          "sections" => [
            %{
              "id" => "main",
              "items" => [
                item("has_trailer", %{
                  "type" => "single_select",
                  "options" => [
                    %{"value" => "yes", "label" => "Yes"},
                    %{"value" => "no", "label" => "No"}
                  ]
                })
              ]
            },
            %{
              "id" => "trailer",
              "visible_when" => %{
                "op" => "all",
                "rules" => [%{"item" => "has_trailer", "op" => "eq", "value" => "yes"}]
              },
              "items" => [item("trailer_brakes", %{"type" => "pass_fail"})]
            }
          ]
        },
        []
      )

    # has_trailer = no -> trailer section hidden -> its item skipped despite a "fail"
    hidden = Grade.grade(s, [answer("has_trailer", "no"), answer("trailer_brakes", "fail")])
    assert status_of(hidden, "trailer_brakes") == :skipped
    assert hidden.result == :passed
    assert hidden.failures == []

    # has_trailer = yes -> section visible and the fail counts
    shown = Grade.grade(s, [answer("has_trailer", "yes"), answer("trailer_brakes", "fail")])
    assert status_of(shown, "trailer_brakes") == :fail
    assert shown.result == :failed
  end

  test "threshold policy tolerates up to N failures" do
    items = [
      item("a", %{"type" => "pass_fail"}),
      item("b", %{"type" => "pass_fail"})
    ]

    answers = [answer("a", "fail"), answer("b", "fail")]

    strict = Grade.grade(schema(items, %{"pass_policy" => "all_pass"}), answers)
    assert strict.result == :failed

    tolerant =
      Grade.grade(schema(items, %{"pass_policy" => "threshold", "fail_threshold" => 2}), answers)

    assert tolerant.result == :passed

    over =
      Grade.grade(schema(items, %{"pass_policy" => "threshold", "fail_threshold" => 1}), answers)

    assert over.result == :failed
  end
end
