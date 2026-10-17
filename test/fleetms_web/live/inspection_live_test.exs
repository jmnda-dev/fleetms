defmodule FleetmsWeb.InspectionLiveTest do
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fleetms.VehicleFixtures

  alias Fleetms.Inspections
  alias Fleetms.Scope

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), owner: owner, org: org, scope: Scope.new(owner, org, true)}
  end

  defp published_form(scope) do
    schema = %{
      "sections" => [
        %{
          "id" => "s1",
          "title" => "Checks",
          "items" => [
            %{"id" => "brakes", "label" => "Brakes", "config" => %{"type" => "pass_fail"}},
            %{
              "id" => "psi",
              "label" => "Tyre pressure",
              "config" => %{"type" => "number", "pass_min" => 30, "pass_max" => 35}
            }
          ]
        }
      ]
    }

    form =
      %{title: "DVIR #{System.unique_integer([:positive])}"}
      |> Inspections.create_inspection_form!(scope: scope)
      |> Inspections.update_inspection_form!(%{draft_schema: schema}, scope: scope)
      |> Inspections.publish_inspection_form!(scope: scope)

    [version] = Inspections.get_inspection_form!(form.id, scope: scope).versions
    {form, version}
  end

  defp publish_schema(scope, schema) do
    form =
      %{title: "Form #{System.unique_integer([:positive])}"}
      |> Inspections.create_inspection_form!(scope: scope)
      |> Inspections.update_inspection_form!(%{draft_schema: schema}, scope: scope)
      |> Inspections.publish_inspection_form!(scope: scope)

    [version] = Inspections.get_inspection_form!(form.id, scope: scope).versions
    {form, version}
  end

  defp start_fill(conn, org, scope, schema) do
    {form, _version} = publish_schema(scope, schema)
    vehicle = vehicle_fixture(scope, %{name: "Rig #{System.unique_integer([:positive])}"})
    {:ok, view, _html} = live(conn, ~p"/o/#{org}/inspections/new")

    view
    |> element("#inspection-picker")
    |> render_change(%{"form_id" => form.id, "vehicle_id" => vehicle.id})

    view
  end

  defp answer(view, answers) do
    view |> element("#inspection-fill-form") |> render_change(%{"answers" => answers})
  end

  defp png_bytes do
    {:ok, image} = Image.new(24, 24, color: [30, 60, 90])
    {:ok, bytes} = Image.write(image, :memory, suffix: ".png")
    bytes
  end

  defp submit_one(scope, vehicle, version, answers) do
    Inspections.submit_inspection!(
      %{vehicle_id: vehicle.id, inspection_form_version_id: version.id, answers: answers},
      scope: scope
    )
  end

  test "a photo attached in the fill form is uploaded and stored on submit", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    schema = %{
      "sections" => [
        %{
          "id" => "s1",
          "items" => [
            %{"id" => "damage", "label" => "Damage", "config" => %{"type" => "photo"}}
          ]
        }
      ]
    }

    {form, version} = publish_schema(scope, schema)
    vehicle = vehicle_fixture(scope, %{name: "Photorig"})
    {:ok, view, _html} = live(conn, ~p"/o/#{org}/inspections/new")

    view
    |> element("#inspection-picker")
    |> render_change(%{"form_id" => form.id, "vehicle_id" => vehicle.id})

    # Attach a photo — auto_upload sends it straight away, driving progress to 100.
    entry =
      file_input(view, "#inspection-fill-form", :photo_damage, [
        %{name: "damage.png", content: png_bytes(), type: "image/png"}
      ])

    render_upload(entry, "damage.png")

    view |> form("#inspection-fill-form", %{"answers" => %{}}) |> render_submit()

    [inspection] = Inspections.list_inspections!(%{}, scope: scope).results
    loaded = Inspections.get_inspection!(inspection.id, scope: scope)
    answer = Enum.find(loaded.answers, &(&1.item_id == "damage"))
    assert [photo] = answer.photos
    assert photo.image_key =~ "inspections/answers/"
    assert version.id == inspection.inspection_form_version_id
  end

  test "a photo item renders a capture control, not a placeholder", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    schema = %{
      "sections" => [
        %{
          "id" => "s1",
          "items" => [
            %{"id" => "damage", "label" => "Damage photos", "config" => %{"type" => "photo"}}
          ]
        }
      ]
    }

    view = start_fill(conn, org, scope, schema)
    html = render(view)

    assert html =~ "Add photo"
    assert html =~ ~s(type="file")
    refute html =~ "coming soon"
  end

  test "a signature item renders a signature pad, not a placeholder", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    schema = %{
      "sections" => [
        %{
          "id" => "s1",
          "items" => [
            %{"id" => "sign", "label" => "Driver signature", "config" => %{"type" => "signature"}}
          ]
        }
      ]
    }

    view = start_fill(conn, org, scope, schema)
    html = render(view)

    assert html =~ "SignaturePad"
    assert html =~ "data-sig-canvas"
    refute html =~ "coming soon"
  end

  test "a signature drawn in the fill form is decoded and stored on submit", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    schema = %{
      "sections" => [
        %{
          "id" => "s1",
          "items" => [
            %{"id" => "sign", "label" => "Driver signature", "config" => %{"type" => "signature"}}
          ]
        }
      ]
    }

    {form, version} = publish_schema(scope, schema)
    vehicle = vehicle_fixture(scope, %{name: "Signrig"})
    {:ok, view, _html} = live(conn, ~p"/o/#{org}/inspections/new")

    view
    |> element("#inspection-picker")
    |> render_change(%{"form_id" => form.id, "vehicle_id" => vehicle.id})

    # The SignaturePad hook writes a PNG data URL into the hidden field; a change carries
    # it to the server (as it would on the next form change), then the submit handler
    # decodes and stores it like a photo.
    data_url = "data:image/png;base64," <> Base.encode64(png_bytes())
    answer(view, %{"sign" => %{"signature_data" => data_url}})

    view |> form("#inspection-fill-form") |> render_submit()

    [inspection] = Inspections.list_inspections!(%{}, scope: scope).results
    loaded = Inspections.get_inspection!(inspection.id, scope: scope)
    answer = Enum.find(loaded.answers, &(&1.item_id == "sign"))
    assert answer.signature
    assert answer.signature.image_key =~ "inspections/answers/"
    assert version.id == inspection.inspection_form_version_id
  end

  test "a photo required on fail blocks submit until one is attached", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    schema = %{
      "sections" => [
        %{
          "id" => "s1",
          "items" => [
            %{
              "id" => "brakes",
              "label" => "Brakes",
              "config" => %{"type" => "pass_fail", "photo_on" => "fail"}
            }
          ]
        }
      ]
    }

    {form, _version} = publish_schema(scope, schema)
    vehicle = vehicle_fixture(scope, %{name: "Reqrig #{System.unique_integer([:positive])}"})
    {:ok, view, _html} = live(conn, ~p"/o/#{org}/inspections/new")

    view
    |> element("#inspection-picker")
    |> render_change(%{"form_id" => form.id, "vehicle_id" => vehicle.id})

    # Fail the item, then try to submit with no photo — it's blocked.
    answer(view, %{"brakes" => %{"value" => "fail"}})
    html = view |> form("#inspection-fill-form") |> render_submit()

    assert html =~ "A photo is required."
    assert Inspections.list_inspections!(%{}, scope: scope).results == []

    # Attach a photo, and now it goes through.
    entry =
      file_input(view, "#inspection-fill-form", :photo_brakes, [
        %{name: "brakes.png", content: png_bytes(), type: "image/png"}
      ])

    render_upload(entry, "brakes.png")
    view |> form("#inspection-fill-form") |> render_submit()

    assert [_inspection] = Inspections.list_inspections!(%{}, scope: scope).results
  end

  test "a passing answer needs no photo even when photo_on is fail", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    schema = %{
      "sections" => [
        %{
          "id" => "s1",
          "items" => [
            %{
              "id" => "brakes",
              "label" => "Brakes",
              "config" => %{"type" => "pass_fail", "photo_on" => "fail"}
            }
          ]
        }
      ]
    }

    {form, _version} = publish_schema(scope, schema)
    vehicle = vehicle_fixture(scope, %{name: "Passrig #{System.unique_integer([:positive])}"})
    {:ok, view, _html} = live(conn, ~p"/o/#{org}/inspections/new")

    view
    |> element("#inspection-picker")
    |> render_change(%{"form_id" => form.id, "vehicle_id" => vehicle.id})

    answer(view, %{"brakes" => %{"value" => "pass"}})
    view |> form("#inspection-fill-form") |> render_submit()

    assert [_inspection] = Inspections.list_inspections!(%{}, scope: scope).results
  end

  test "a photo item requires a photo before submit", %{conn: conn, org: org, scope: scope} do
    schema = %{
      "sections" => [
        %{
          "id" => "s1",
          "items" => [
            %{"id" => "damage", "label" => "Damage", "config" => %{"type" => "photo"}}
          ]
        }
      ]
    }

    {form, _version} = publish_schema(scope, schema)
    vehicle = vehicle_fixture(scope, %{name: "Minrig #{System.unique_integer([:positive])}"})
    {:ok, view, _html} = live(conn, ~p"/o/#{org}/inspections/new")

    view
    |> element("#inspection-picker")
    |> render_change(%{"form_id" => form.id, "vehicle_id" => vehicle.id})

    html = view |> form("#inspection-fill-form") |> render_submit()

    assert html =~ "A photo is required."
    assert Inspections.list_inspections!(%{}, scope: scope).results == []
  end

  test "lists submitted inspections", %{conn: conn, org: org, scope: scope} do
    {_form, version} = published_form(scope)
    vehicle = vehicle_fixture(scope, %{name: "Rig One"})
    submit_one(scope, vehicle, version, [%{"item_id" => "brakes", "value" => "fail"}])

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/inspections")

    assert html =~ "Inspections"
    assert html =~ "Rig One"
    assert html =~ "Failed"
  end

  test "filling and submitting an inspection grades it and opens the result", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    {form, _version} = published_form(scope)
    vehicle = vehicle_fixture(scope, %{name: "Fillrig"})

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/inspections/new")

    # choose the form and vehicle — the fill form appears
    html =
      view
      |> element("#inspection-picker")
      |> render_change(%{"form_id" => form.id, "vehicle_id" => vehicle.id})

    assert html =~ "Brakes"
    assert html =~ "Tyre pressure"

    view
    |> form("#inspection-fill-form", %{
      "answers" => %{
        "brakes" => %{"value" => "fail"},
        "psi" => %{"value" => "26"}
      }
    })
    |> render_submit()

    assert [inspection] = Inspections.list_inspections!(%{}, scope: scope).results
    assert inspection.result == :failed
    assert_redirect(view, ~p"/o/#{org}/inspections/#{inspection.id}")
  end

  test "a comment box appears when a fail item is answered fail", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    schema = %{
      "sections" => [
        %{
          "id" => "s1",
          "items" => [
            %{
              "id" => "brakes",
              "label" => "Brakes",
              "config" => %{"type" => "pass_fail", "comment_on" => "fail"}
            }
          ]
        }
      ]
    }

    view = start_fill(conn, org, scope, schema)

    refute render(view) =~ "answers[brakes][comment]"
    assert answer(view, %{"brakes" => %{"value" => "fail"}}) =~ "answers[brakes][comment]"
    refute answer(view, %{"brakes" => %{"value" => "pass"}}) =~ "answers[brakes][comment]"
  end

  test "an item stays hidden until its condition is met", %{conn: conn, org: org, scope: scope} do
    schema = %{
      "sections" => [
        %{
          "id" => "s1",
          "items" => [
            %{
              "id" => "has_leak",
              "label" => "Any leaks?",
              "config" => %{
                "type" => "single_select",
                "options" => [
                  %{"value" => "yes", "label" => "Yes"},
                  %{"value" => "no", "label" => "No"}
                ]
              }
            },
            %{
              "id" => "leak_detail",
              "label" => "Describe the leak",
              "visible_when" => %{
                "op" => "all",
                "rules" => [%{"item" => "has_leak", "op" => "eq", "value" => "yes"}]
              },
              "config" => %{"type" => "text"}
            }
          ]
        }
      ]
    }

    view = start_fill(conn, org, scope, schema)

    refute render(view) =~ "Describe the leak"
    assert answer(view, %{"has_leak" => %{"value" => "yes"}}) =~ "Describe the leak"
    refute answer(view, %{"has_leak" => %{"value" => "no"}}) =~ "Describe the leak"
  end

  test "a section hidden by its condition appears and disappears with its trigger", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    schema = %{
      "sections" => [
        %{
          "id" => "main",
          "items" => [
            %{
              "id" => "has_trailer",
              "label" => "Has a trailer?",
              "config" => %{
                "type" => "single_select",
                "options" => [
                  %{"value" => "yes", "label" => "Yes"},
                  %{"value" => "no", "label" => "No"}
                ]
              }
            }
          ]
        },
        %{
          "id" => "trailer",
          "title" => "Trailer checks",
          "visible_when" => %{
            "op" => "all",
            "rules" => [%{"item" => "has_trailer", "op" => "eq", "value" => "yes"}]
          },
          "items" => [
            %{
              "id" => "coupling",
              "label" => "Coupling secure",
              "config" => %{"type" => "pass_fail"}
            }
          ]
        }
      ]
    }

    view = start_fill(conn, org, scope, schema)

    refute render(view) =~ "Trailer checks"
    assert answer(view, %{"has_trailer" => %{"value" => "yes"}}) =~ "Trailer checks"
    refute answer(view, %{"has_trailer" => %{"value" => "no"}}) =~ "Trailer checks"
  end

  test "a single_select set to radio display renders option choices, not a dropdown", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    schema = %{
      "sections" => [
        %{
          "id" => "s1",
          "items" => [
            %{
              "id" => "condition",
              "label" => "Overall condition",
              "config" => %{
                "type" => "single_select",
                "display" => "radio",
                "options" => [
                  %{"value" => "good", "label" => "Good"},
                  %{"value" => "poor", "label" => "Poor", "fail?" => true}
                ]
              }
            }
          ]
        }
      ]
    }

    view = start_fill(conn, org, scope, schema)
    html = render(view)

    # Radio choices for each option, and the value is submitted under the item name.
    assert html =~ ~s(type="radio")
    assert html =~ ~s(name="answers[condition][value]")
    assert html =~ "Good"
    assert html =~ "Poor"
  end

  test "the result page shows answers, statuses and failures", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    {_form, version} = published_form(scope)
    vehicle = vehicle_fixture(scope, %{name: "Showrig"})

    inspection =
      submit_one(scope, vehicle, version, [
        %{"item_id" => "brakes", "value" => "fail"},
        %{"item_id" => "psi", "value" => "33"}
      ])

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/inspections/#{inspection.id}")

    assert html =~ "Showrig"
    assert html =~ "Failed"
    assert html =~ "Brakes"
    # failures section names the failed item
    assert html =~ "Failures"
  end

  test "the result page offers a printable report", %{conn: conn, org: org, scope: scope} do
    {_form, version} = published_form(scope)
    vehicle = vehicle_fixture(scope, %{name: "Printrig"})

    inspection =
      submit_one(scope, vehicle, version, [%{"item_id" => "brakes", "value" => "pass"}])

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/inspections/#{inspection.id}")

    # A Print button and the isolated print document with the org masthead.
    assert html =~ ~s(id="print-inspection")
    assert html =~ ~s(phx-hook="PrintButton")
    assert html =~ ~s(id="inspection-document")
    assert html =~ scope.organization.name
    assert html =~ "Inspector"
  end

  test "archives an inspection, then restores it from the archived view", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    {_form, version} = published_form(scope)
    vehicle = vehicle_fixture(scope, %{name: "Archrig"})

    inspection =
      submit_one(scope, vehicle, version, [%{"item_id" => "brakes", "value" => "pass"}])

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/inspections")
    render_click(view, "archive", %{"id" => inspection.id})

    refute Enum.any?(
             Inspections.list_inspections!(%{}, scope: scope).results,
             &(&1.id == inspection.id)
           )

    {:ok, archived, html} = live(conn, ~p"/o/#{org}/inspections?archived=1")
    assert html =~ "Archived inspections"
    assert html =~ "Archrig"
    assert html =~ "Restore"

    render_click(archived, "restore", %{"id" => inspection.id})

    assert Enum.any?(
             Inspections.list_inspections!(%{}, scope: scope).results,
             &(&1.id == inspection.id)
           )
  end

  test "posts a comment from the inspection detail page", %{conn: conn, org: org, scope: scope} do
    {_form, version} = published_form(scope)
    vehicle = vehicle_fixture(scope, %{name: "Commentrig"})

    inspection =
      submit_one(scope, vehicle, version, [%{"item_id" => "brakes", "value" => "pass"}])

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/inspections/#{inspection.id}")

    view
    |> form("#comments-#{inspection.id}-compose", %{body: "Re-check next service"})
    |> render_submit()

    assert render(view) =~ "Re-check next service"

    assert [%{body: "Re-check next service"}] =
             Fleetms.Comments.list_comments!(%{inspection_id: inspection.id}, scope: scope)
  end

  test "photo_on: fail shows the photo control only when the item fails", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    schema = %{
      "sections" => [
        %{
          "id" => "s1",
          "items" => [
            %{
              "id" => "psi",
              "label" => "Tyre PSI",
              "config" => %{
                "type" => "number",
                "pass_min" => 30,
                "pass_max" => 40,
                "comment_on" => "fail",
                "photo_on" => "fail"
              }
            }
          ]
        }
      ]
    }

    view = start_fill(conn, org, scope, schema)

    # Before any answer: neither the photo control nor the comment box.
    before = render(view)
    refute before =~ "Add photo"
    refute before =~ "answers[psi][comment]"

    # A failing value reveals both.
    failed = answer(view, %{"psi" => %{"value" => "55"}})
    assert failed =~ "Add photo"
    assert failed =~ "answers[psi][comment]"

    # A passing value hides both again.
    passed = answer(view, %{"psi" => %{"value" => "35"}})
    refute passed =~ "Add photo"
    refute passed =~ "answers[psi][comment]"
  end
end
