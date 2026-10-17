defmodule FleetmsWeb.InspectionFormLiveTest do
  # Not async (ConnCase default): LiveView tests need shared-mode sandbox and a
  # logged-in owner with a real auth token, so they create their own org.
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Fleetms.Inspections
  alias Fleetms.Scope

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), owner: owner, org: org, scope: Scope.new(owner, org, true)}
  end

  defp form_fixture(scope, attrs \\ %{}) do
    attrs
    |> Enum.into(%{title: "Form #{System.unique_integer([:positive])}"})
    |> Inspections.create_inspection_form!(scope: scope)
  end

  defp sample_schema do
    %{
      "sections" => [
        %{
          "id" => "s1",
          "title" => "Exterior",
          "items" => [
            %{"id" => "i1", "label" => "Brakes", "config" => %{"type" => "pass_fail"}}
          ]
        }
      ]
    }
  end

  test "lists forms and the new action", %{conn: conn, org: org, scope: scope} do
    form_fixture(scope, %{title: "Daily DVIR"})

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/inspection-forms")

    assert html =~ "Inspection Forms"
    assert html =~ "New form"
    assert html =~ "Daily DVIR"
  end

  test "duplicating a form creates a draft copy and opens the builder", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    source =
      scope
      |> form_fixture(%{title: "Daily DVIR"})
      |> Inspections.update_inspection_form!(%{draft_schema: sample_schema()}, scope: scope)

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/inspection-forms")
    render_click(view, "duplicate", %{"id" => source.id})

    copy =
      Inspections.list_inspection_forms!(%{}, scope: scope).results
      |> Enum.find(&(&1.title == "Daily DVIR (copy)"))

    assert copy
    assert copy.status == :draft
    assert_redirect(view, ~p"/o/#{org}/inspection-forms/#{copy.id}/build")

    # The working draft is copied across.
    loaded = Inspections.get_inspection_form!(copy.id, scope: scope)
    assert [section] = loaded.draft_schema.sections
    assert section.id == "s1"
  end

  test "a duplicate avoids clashing with an existing title", %{conn: conn, org: org, scope: scope} do
    source = form_fixture(scope, %{title: "Roster"})
    # A copy already exists → the next duplicate must not reuse its title.
    form_fixture(scope, %{title: "Roster (copy)"})

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/inspection-forms")
    render_click(view, "duplicate", %{"id" => source.id})

    titles = Enum.map(Inspections.list_inspection_forms!(%{}, scope: scope).results, & &1.title)
    assert "Roster (copy) (2)" in titles
  end

  test "creating a form from a template opens a populated draft", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    {:ok, view, html} = live(conn, ~p"/o/#{org}/inspection-forms")

    assert html =~ "New from template"
    assert html =~ "Daily Vehicle Inspection (DVIR)"

    render_click(view, "from_template", %{"key" => "dvir"})

    copy =
      Inspections.list_inspection_forms!(%{}, scope: scope).results
      |> Enum.find(&(&1.title == "Daily Vehicle Inspection (DVIR)"))

    assert copy
    assert copy.status == :draft
    assert_redirect(view, ~p"/o/#{org}/inspection-forms/#{copy.id}/build")

    loaded = Inspections.get_inspection_form!(copy.id, scope: scope)
    assert length(loaded.draft_schema.sections) == 4
  end

  test "an unknown template key is handled gracefully", %{conn: conn, org: org, scope: scope} do
    {:ok, view, _html} = live(conn, ~p"/o/#{org}/inspection-forms")
    render_click(view, "from_template", %{"key" => "nope"})

    assert render(view) =~ "not available"
    assert Inspections.list_inspection_forms!(%{}, scope: scope).results == []
  end

  test "creating a form opens the builder", %{conn: conn, org: org, scope: scope} do
    {:ok, view, _html} = live(conn, ~p"/o/#{org}/inspection-forms/new")

    view
    |> form("#inspection-form-form", inspection_form: %{title: "Pre-trip"})
    |> render_submit()

    assert [created] = Inspections.list_inspection_forms!(%{}, scope: scope).results
    assert created.title == "Pre-trip"
    assert_redirect(view, ~p"/o/#{org}/inspection-forms/#{created.id}/build")
  end

  test "the builder serializes the draft into the island's data-schema", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    form =
      form_fixture(scope)
      |> Inspections.update_inspection_form!(%{draft_schema: sample_schema()}, scope: scope)

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/inspection-forms/#{form.id}/build")

    assert html =~ ~s(phx-hook="InspectionBuilder")
    # the flat, tagged union config is present in the serialized document
    assert html =~ "pass_fail"
    assert html =~ "Exterior"
  end

  test "save_schema persists the whole document to the draft", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    form = form_fixture(scope)

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/inspection-forms/#{form.id}/build")

    view
    |> element("#inspection-builder-#{form.id}")
    |> render_hook("save_schema", %{"schema" => sample_schema()})

    reloaded = Inspections.get_inspection_form!(form.id, scope: scope)
    assert [section] = reloaded.draft_schema.sections
    assert section.title == "Exterior"
    assert [%{label: "Brakes", config: %Ash.Union{type: :pass_fail}}] = section.items
  end

  test "publish freezes the draft into a new version", %{conn: conn, org: org, scope: scope} do
    form =
      form_fixture(scope)
      |> Inspections.update_inspection_form!(%{draft_schema: sample_schema()}, scope: scope)

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/inspection-forms/#{form.id}/build")

    assert view |> element("button", "Publish") |> render_click() =~ "v1"

    reloaded = Inspections.get_inspection_form!(form.id, scope: scope)
    assert reloaded.status == :active
    assert reloaded.version_count == 1
  end
end
