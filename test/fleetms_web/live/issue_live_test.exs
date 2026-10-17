defmodule FleetmsWeb.IssueLiveTest do
  # Not async (ConnCase default): LiveView tests need shared-mode sandbox and a
  # logged-in owner with a real auth token, so they create their own org.
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fleetms.VehicleFixtures
  import Fleetms.IssueFixtures

  alias Fleetms.Comments
  alias Fleetms.Scope
  alias Fleetms.VehicleIssues

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), org: org, scope: Scope.new(owner, org, true)}
  end

  describe "index" do
    test "lists issues and shows the report action", %{conn: conn, org: org, scope: scope} do
      issue = issue_fixture(scope, %{title: "Indexed-#{uniq()}"})

      {:ok, _view, html} = live(conn, ~p"/o/#{org}/issues")

      assert html =~ "Issues"
      assert html =~ "Report issue"
      assert html =~ issue.title
      assert html =~ "##{issue.issue_number}"
    end

    test "renders the saved-views control", %{conn: conn, org: org} do
      {:ok, _view, html} = live(conn, ~p"/o/#{org}/issues")

      assert html =~ ~s(phx-hook="SavedViews")
      assert html =~ ~s(data-view-key="issues")
      assert html =~ "Save current view"
    end

    test "search narrows the list", %{conn: conn, org: org, scope: scope} do
      keep = issue_fixture(scope, %{title: "Keeper-#{uniq()}"})
      drop = issue_fixture(scope, %{title: "Hidden-#{uniq()}"})

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/issues")
      html = view |> form("form[phx-change='search']", %{q: "Keeper"}) |> render_change()

      assert html =~ keep.title
      refute html =~ drop.title
    end

    test "archives an issue, then restores it from the archived view", %{
      conn: conn,
      org: org,
      scope: scope
    } do
      issue = issue_fixture(scope, %{title: "Doomed-#{uniq()}"})

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/issues")
      render_click(view, "archive", %{"id" => issue.id})

      # archived → gone from the browse list, but still there (recoverable)
      refute Enum.any?(
               VehicleIssues.list_issues!(%{}, scope: scope).results,
               &(&1.id == issue.id)
             )

      assert {:ok, _} = VehicleIssues.get_issue(issue.id, scope: scope)

      # shows in the archived view, and restoring brings it back
      {:ok, archived, html} = live(conn, ~p"/o/#{org}/issues?archived=1")
      assert html =~ "Archived issues"
      assert html =~ "Restore"

      render_click(archived, "restore", %{"id" => issue.id})

      assert Enum.any?(
               VehicleIssues.list_issues!(%{}, scope: scope).results,
               &(&1.id == issue.id)
             )
    end

    test "bulk-archives the selected issues", %{conn: conn, org: org, scope: scope} do
      a = issue_fixture(scope, %{title: "Bulk-A-#{uniq()}"})
      b = issue_fixture(scope, %{title: "Bulk-B-#{uniq()}"})
      keep = issue_fixture(scope, %{title: "Bulk-keep-#{uniq()}"})

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/issues")

      # Select two of the three, then bulk-archive.
      render_click(view, "toggle_select", %{"id" => a.id})
      html = render_click(view, "toggle_select", %{"id" => b.id})
      assert html =~ "2 selected"

      render_click(view, "bulk_archive", %{})

      remaining = VehicleIssues.list_issues!(%{}, scope: scope).results |> Enum.map(& &1.id)
      refute a.id in remaining
      refute b.id in remaining
      assert keep.id in remaining
    end

    test "select-all then clear toggles the whole page", %{conn: conn, org: org, scope: scope} do
      issue_fixture(scope, %{title: "All-1-#{uniq()}"})
      issue_fixture(scope, %{title: "All-2-#{uniq()}"})

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/issues")

      html = render_click(view, "toggle_select_all", %{})
      assert html =~ "2 selected"

      html = render_click(view, "clear_selection", %{})
      refute html =~ "selected"
    end

    test "permanently deletes an archived issue", %{conn: conn, org: org, scope: scope} do
      issue = issue_fixture(scope, %{title: "Gone-#{uniq()}"})
      :ok = VehicleIssues.delete_issue(issue, scope: scope)

      {:ok, view, html} = live(conn, ~p"/o/#{org}/issues?archived=1")
      assert html =~ "Delete permanently"

      render_click(view, "purge", %{"id" => issue.id})

      # Really gone — not resolvable and not in the archived list.
      assert {:error, _} = VehicleIssues.get_issue(issue.id, scope: scope)

      refute Enum.any?(
               VehicleIssues.list_archived_issues!(%{}, scope: scope).results,
               &(&1.id == issue.id)
             )
    end
  end

  describe "new" do
    test "renders the form with rich-text and datepicker hooks", %{conn: conn, org: org} do
      {:ok, _view, html} = live(conn, ~p"/o/#{org}/issues/new")

      assert html =~ "Report issue"
      assert html =~ "Title"
      assert html =~ "Priority"
      assert html =~ ~s(phx-hook="RichText")
      assert html =~ ~s(phx-hook="DatePicker")
    end

    test "creates an issue", %{conn: conn, org: org, scope: scope} do
      vehicle = vehicle_fixture(scope)
      title = "Created-#{uniq()}"

      # Existing tags are the select's options; picking them exercises the form wiring.
      # (Creating brand-new tags by typing is a client-side TomSelect concern the test
      # form helper can't simulate, and is covered by the resource tests.)
      for name <- ~w(brakes urgent), do: Fleetms.Tagging.create_tag!(%{name: name}, scope: scope)

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/issues/new")

      view
      |> form("#issue-form", %{
        issue: %{
          title: title,
          vehicle_id: vehicle.id,
          priority: "High",
          tags: ["brakes", "urgent"]
        }
      })
      |> render_submit()

      assert [issue] =
               VehicleIssues.list_issues!(%{search_query: title}, scope: scope).results

      assert issue.title == title
      assert issue.priority == :High
      assert issue.status == :open

      issue = VehicleIssues.get_issue!(issue.id, scope: scope, load: [:tags])
      assert issue.tags |> Enum.map(&to_string(&1.name)) |> Enum.sort() == ["brakes", "urgent"]
    end
  end

  describe "edit" do
    test "updates an issue", %{conn: conn, org: org, scope: scope} do
      issue = issue_fixture(scope, %{title: "Before-#{uniq()}"})
      new_title = "After-#{uniq()}"

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/issues/#{issue.id}/edit")

      view
      |> form("#issue-form", %{issue: %{title: new_title}})
      |> render_submit()

      assert {:ok, updated} = VehicleIssues.get_issue(issue.id, scope: scope)
      assert updated.title == new_title
    end
  end

  describe "show" do
    test "renders the detail tabs and issue info", %{conn: conn, org: org, scope: scope} do
      issue = issue_fixture(scope, %{title: "Shown-#{uniq()}"})

      {:ok, _view, html} = live(conn, ~p"/o/#{org}/issues/#{issue.id}")

      assert html =~ issue.title
      assert html =~ "Details"
      assert html =~ "Photos"
      assert html =~ "Documents"
      assert html =~ "Resolve"
      assert html =~ "Close"
    end

    test "watch then unwatch toggles the button", %{conn: conn, org: org, scope: scope} do
      issue = issue_fixture(scope, %{title: "Watchable-#{uniq()}"})

      {:ok, view, html} = live(conn, ~p"/o/#{org}/issues/#{issue.id}")
      assert html =~ "Watch"

      html = render_click(view, "watch", %{})
      assert html =~ "Watching"

      html = render_click(view, "unwatch", %{})
      refute html =~ "Watching"
    end

    test "resolves an issue with a comment", %{conn: conn, org: org, scope: scope} do
      issue = issue_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/issues/#{issue.id}")
      render_click(view, "begin-transition", %{"action" => "resolve"})

      view
      |> form("form[phx-submit='confirm-transition']", %{comment: "Fixed it"})
      |> render_submit()

      {:ok, reloaded} = VehicleIssues.get_issue(issue.id, scope: scope)
      assert reloaded.status == :resolved
      assert reloaded.resolve_comments == "Fixed it"
      assert reloaded.resolved_at
    end

    test "closes then reopens an issue", %{conn: conn, org: org, scope: scope} do
      issue = issue_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/issues/#{issue.id}")
      render_click(view, "begin-transition", %{"action" => "close"})
      view |> form("form[phx-submit='confirm-transition']", %{comment: ""}) |> render_submit()

      assert {:ok, %{status: :closed}} = VehicleIssues.get_issue(issue.id, scope: scope)

      render_click(view, "reopen", %{})
      assert {:ok, %{status: :open}} = VehicleIssues.get_issue(issue.id, scope: scope)
    end

    test "uploads a photo", %{conn: conn, org: org, scope: scope} do
      issue = issue_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/issues/#{issue.id}")
      render_click(view, "select-tab", %{"tab" => "photos"})

      photo =
        file_input(view, "form[phx-submit='save-photos']", :photos, [
          %{name: "fault.png", content: png_bytes(), type: "image/png"}
        ])

      render_upload(photo, "fault.png")
      view |> element("form[phx-submit='save-photos']") |> render_submit()

      {:ok, reloaded} = VehicleIssues.get_issue(issue.id, scope: scope, load: [:photos])
      assert [_photo] = reloaded.photos
    end

    test "uploads a document", %{conn: conn, org: org, scope: scope} do
      issue = issue_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/issues/#{issue.id}")
      render_click(view, "select-tab", %{"tab" => "documents"})

      doc =
        file_input(view, "form[phx-submit='save-documents']", :documents, [
          %{name: "quote.txt", content: "parts quote", type: "text/plain"}
        ])

      render_upload(doc, "quote.txt")
      view |> element("form[phx-submit='save-documents']") |> render_submit()

      {:ok, reloaded} = VehicleIssues.get_issue(issue.id, scope: scope, load: [:documents])
      assert [%{filename: "quote.txt"}] = reloaded.documents
    end
  end

  describe "comments" do
    defp open_comments(conn, org, issue) do
      {:ok, view, _html} = live(conn, ~p"/o/#{org}/issues/#{issue.id}")
      render_click(view, "select-tab", %{"tab" => "comments"})
      view
    end

    test "posts a comment and shows it in the thread", %{conn: conn, org: org, scope: scope} do
      issue = issue_fixture(scope)
      view = open_comments(conn, org, issue)

      view
      |> form("#comments-#{issue.id}-compose", %{body: "Brakes need checking"})
      |> render_submit()

      assert render(view) =~ "Brakes need checking"

      assert [%{body: "Brakes need checking"}] =
               Comments.list_comments!(%{issue_id: issue.id}, scope: scope)
    end

    test "shows @mention suggestions while composing", %{conn: conn, org: org, scope: scope} do
      issue = issue_fixture(scope)
      view = open_comments(conn, org, issue)

      html =
        view
        |> form("#comments-#{issue.id}-compose", %{body: "@"})
        |> render_change()

      assert html =~ "pick-mention"
    end

    test "edits own comment", %{conn: conn, org: org, scope: scope} do
      issue = issue_fixture(scope)
      view = open_comments(conn, org, issue)
      view |> form("#comments-#{issue.id}-compose", %{body: "Frist draft"}) |> render_submit()
      [comment] = Comments.list_comments!(%{issue_id: issue.id}, scope: scope)

      view |> element("#comment-#{comment.id} [phx-click='edit-comment']") |> render_click()

      view
      |> form("form[phx-submit='save-edit']", %{body: "First draft"})
      |> render_submit()

      assert [%{body: "First draft"}] =
               Comments.list_comments!(%{issue_id: issue.id}, scope: scope)
    end

    test "deletes own comment", %{conn: conn, org: org, scope: scope} do
      issue = issue_fixture(scope)
      view = open_comments(conn, org, issue)
      view |> form("#comments-#{issue.id}-compose", %{body: "Delete me"}) |> render_submit()
      [comment] = Comments.list_comments!(%{issue_id: issue.id}, scope: scope)

      view |> element("#comment-#{comment.id} [phx-click='delete-comment']") |> render_click()

      assert Comments.list_comments!(%{issue_id: issue.id}, scope: scope) == []
    end
  end

  describe "history" do
    test "the History tab shows a readable audit timeline", %{conn: conn, org: org, scope: scope} do
      issue = issue_fixture(scope, %{priority: :Low})
      {:ok, _} = VehicleIssues.update_issue(issue, %{priority: :High}, scope: scope)
      {:ok, _} = VehicleIssues.resolve_issue(issue, %{resolve_comments: "fixed"}, scope: scope)

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/issues/#{issue.id}")
      html = render_click(view, "select-tab", %{"tab" => "history"})

      assert html =~ "created this issue"
      assert html =~ "changed Priority from Low to High"
      assert html =~ "resolved this issue"
    end
  end

  test "the vehicle detail page shows the vehicle's issues in an Issues tab", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    vehicle = vehicle_fixture(scope, %{name: "Issuetab Rig"})
    issue_fixture(scope, %{vehicle_id: vehicle.id, title: "Cracked mirror"})

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/vehicles/#{vehicle.id}")

    html = render_click(element(view, ~s|[phx-click][phx-value-tab="issues"]|))

    assert html =~ "Cracked mirror"
    assert html =~ "New issue"
  end

  defp png_bytes do
    {:ok, image} = Image.new(24, 24, color: [30, 60, 90])
    {:ok, bytes} = Image.write(image, :memory, suffix: ".png")
    bytes
  end

  defp uniq, do: System.unique_integer([:positive])
end
