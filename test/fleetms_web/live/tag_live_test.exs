defmodule FleetmsWeb.TagLiveTest do
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Fleetms.Scope
  alias Fleetms.Tagging

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), org: org, scope: Scope.new(owner, org, true)}
  end

  defp tag_names(scope), do: Tagging.list_tags!(scope: scope) |> Enum.map(&to_string(&1.name))

  test "lists tags with their usage count", %{conn: conn, org: org, scope: scope} do
    Tagging.create_tag!(%{name: "warranty"}, scope: scope)

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/tags")

    assert html =~ "warranty"
    assert html =~ "0 records"
  end

  test "adds a tag", %{conn: conn, org: org, scope: scope} do
    {:ok, view, _html} = live(conn, ~p"/o/#{org}/tags")

    view
    |> form("#new-tag-form", %{tag: %{name: "recall", color: "blue"}})
    |> render_submit()

    assert "recall" in tag_names(scope)
  end

  test "renames and recolours a tag", %{conn: conn, org: org, scope: scope} do
    tag = Tagging.create_tag!(%{name: "warrenty", color: :slate}, scope: scope)

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/tags")

    render_click(view, "edit", %{"id" => tag.id})

    view
    |> form("#edit-tag-#{tag.id}", %{tag: %{name: "warranty", color: "green"}})
    |> render_submit()

    updated = Tagging.get_tag!(tag.id, scope: scope)
    assert to_string(updated.name) == "warranty"
    assert updated.color == :green
  end

  test "deletes a tag", %{conn: conn, org: org, scope: scope} do
    tag = Tagging.create_tag!(%{name: "obsolete"}, scope: scope)

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/tags")
    render_click(view, "delete", %{"id" => tag.id})

    refute "obsolete" in tag_names(scope)
  end

  test "shows a friendly error when renaming to an existing name", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    Tagging.create_tag!(%{name: "brakes"}, scope: scope)
    tag = Tagging.create_tag!(%{name: "breaks"}, scope: scope)

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/tags")
    render_click(view, "edit", %{"id" => tag.id})

    html =
      view
      |> form("#edit-tag-#{tag.id}", %{tag: %{name: "brakes", color: "slate"}})
      |> render_submit()

    # The rename is rejected (identity), and both tags still exist.
    assert Enum.sort(tag_names(scope)) == ["brakes", "breaks"]
    assert html =~ "already"
  end
end
