defmodule Fleetms.Inspections.WorkflowsTest do
  use Fleetms.DataCase

  import Fleetms.VehicleFixtures
  import Swoosh.TestAssertions

  alias Fleetms.Inspections
  alias Fleetms.VehicleIssues

  setup :shared_org

  # A single-workflow list with one notify action, merging `action` over sensible
  # defaults, triggered when an inspection is submitted.
  defp notify_workflow(action) do
    [
      %{
        "id" => "wf1",
        "enabled" => true,
        "trigger" => %{"type" => "inspection_submitted"},
        "actions" => [
          Map.merge(%{"type" => "notify", "title_template" => "Ping {vehicle}"}, action)
        ]
      }
    ]
  end

  # A one-section form (brakes pass/fail + a text detail) published with the given
  # list of workflow maps. Returns the published version.
  defp published_version(scope, workflows) do
    schema = %{
      "sections" => [
        %{
          "id" => "s1",
          "title" => "Checks",
          "items" => [
            %{"id" => "brakes", "label" => "Brakes", "config" => %{"type" => "pass_fail"}},
            %{"id" => "detail", "label" => "Detail", "config" => %{"type" => "text"}}
          ]
        }
      ],
      "workflows" => workflows
    }

    form =
      %{title: "DVIR #{System.unique_integer([:positive])}"}
      |> Inspections.create_inspection_form!(scope: scope)
      |> Inspections.update_inspection_form!(%{draft_schema: schema}, scope: scope)
      |> Inspections.publish_inspection_form!(scope: scope)

    [version] = Inspections.get_inspection_form!(form.id, scope: scope).versions
    version
  end

  defp submit(scope, version, brakes) do
    vehicle = vehicle_fixture(scope, %{name: "Rig", mileage: Decimal.new("100")})

    Inspections.submit_inspection!(
      %{
        vehicle_id: vehicle.id,
        inspection_form_version_id: version.id,
        answers: [%{"item_id" => "brakes", "value" => brakes}]
      },
      scope: scope
    )
  end

  # The engine runs from the Oban job in real life; in tests we invoke the same
  # action the job would (jobs are :manual). Reloads the inspection first, as the
  # job would.
  defp run_workflows(scope, inspection) do
    inspection
    |> then(&Inspections.get_inspection!(&1.id, scope: scope))
    |> Inspections.run_inspection_workflows!(scope: scope)
  end

  describe "no workflows" do
    test "submit stamps workflows_ran_at and schedules nothing", %{scope: scope} do
      version = published_version(scope, [])
      inspection = submit(scope, version, "fail")

      # With no workflows the inspection is finalized as already-run.
      assert inspection.workflows_ran_at
      assert VehicleIssues.list_issues!(%{}, scope: scope).results == []
    end
  end

  describe "open_issue action" do
    setup %{scope: scope} do
      version =
        published_version(scope, [
          %{
            "id" => "wf1",
            "name" => "Open issue on failure",
            "enabled" => true,
            "trigger" => %{"type" => "inspection_failed"},
            "actions" => [
              %{
                "type" => "open_issue",
                "title_template" => "Inspection failure on {vehicle}",
                "priority" => "High",
                "assign_to" => "submitter"
              }
            ]
          }
        ])

      %{version: version}
    end

    test "opens an assigned issue when the inspection fails and links the failure", %{
      scope: scope,
      owner: owner,
      version: version
    } do
      inspection = submit(scope, version, "fail")

      # Submit only enqueues; the flag is still nil until the job/action runs.
      refute inspection.workflows_ran_at

      ran = run_workflows(scope, inspection)
      assert ran.workflows_ran_at

      assert [issue] = VehicleIssues.list_issues!(%{}, scope: scope).results
      assert issue.title == "Inspection failure on Rig"
      assert issue.priority == :High
      assert issue.assigned_to_id == owner.id
      assert issue.reported_by_id == owner.id

      # the failure row is linked back to the opened issue
      loaded = Inspections.get_inspection!(inspection.id, scope: scope)
      assert [failure] = loaded.failures
      assert failure.issue_id == issue.id
    end

    test "does not open an issue when the inspection passes", %{scope: scope, version: version} do
      inspection = submit(scope, version, "pass")
      run_workflows(scope, inspection)

      assert VehicleIssues.list_issues!(%{}, scope: scope).results == []
    end

    # Exercises the *real* Oban path (scheduler + worker), which reads and updates
    # the inspection with no actor — so it guards the AshObanInteraction policy
    # bypass. Without it the worker cancels with :trigger_no_longer_applies and
    # never opens the issue.
    test "the Oban trigger runs the workflow end to end, actor-less", %{
      scope: scope,
      version: version
    } do
      inspection = submit(scope, version, "fail")
      refute inspection.workflows_ran_at

      assert %{success: success} =
               AshOban.Test.schedule_and_run_triggers(Fleetms.Inspections.Inspection)

      assert success >= 1

      assert Inspections.get_inspection!(inspection.id, scope: scope).workflows_ran_at
      assert [_issue] = VehicleIssues.list_issues!(%{}, scope: scope).results
    end
  end

  describe "notify action" do
    test "sends an in-app notification to the submitter on submission", %{
      scope: scope,
      owner: owner
    } do
      version =
        published_version(scope, [
          %{
            "id" => "wf1",
            "enabled" => true,
            "trigger" => %{"type" => "inspection_submitted"},
            "actions" => [
              %{
                "type" => "notify",
                "to" => "submitter",
                "title_template" => "Your inspection on {vehicle} was recorded"
              }
            ]
          }
        ])

      inspection = submit(scope, version, "pass")
      run_workflows(scope, inspection)

      assert [notification] = Fleetms.Notifications.list_notifications!(scope: scope)
      assert notification.recipient_id == owner.id
      assert notification.title == "Your inspection on Rig was recorded"
      assert notification.type == "inspection_workflow"
    end

    test "emails the submitter when the channel is email (no in-app bell)", %{
      scope: scope,
      owner: owner
    } do
      version =
        published_version(scope, notify_workflow(%{"to" => "submitter", "channel" => "email"}))

      inspection = submit(scope, version, "pass")
      run_workflows(scope, inspection)

      assert_email_sent(fn email ->
        assert {_, to} = hd(email.to)
        assert to == to_string(owner.email)
        assert email.subject == "Ping Rig"
      end)

      # Email-only channel sends no in-app notification.
      assert Fleetms.Notifications.list_notifications!(scope: scope) == []
    end

    test "notifies everyone holding a role, in-app and by email", %{
      scope: scope,
      owner: owner,
      org: org
    } do
      {:ok, role} = Fleetms.Permissions.create_role(%{"name" => "Supervisor"}, org, owner)
      Fleetms.Permissions.assign_role(owner.id, role.id, org, owner)

      version =
        published_version(
          scope,
          notify_workflow(%{"to" => "role", "role_id" => role.id, "channel" => "both"})
        )

      inspection = submit(scope, version, "fail")
      run_workflows(scope, inspection)

      assert [notification] = Fleetms.Notifications.list_notifications!(scope: scope)
      assert notification.recipient_id == owner.id

      assert_email_sent(fn email ->
        assert {_, to} = hd(email.to)
        to == to_string(owner.email)
      end)
    end

    test "notifies organization owners", %{scope: scope, owner: owner} do
      version =
        published_version(scope, notify_workflow(%{"to" => "owners", "channel" => "in_app"}))

      inspection = submit(scope, version, "fail")
      run_workflows(scope, inspection)

      assert [notification] = Fleetms.Notifications.list_notifications!(scope: scope)
      assert notification.recipient_id == owner.id
      assert_no_email_sent()
    end
  end

  describe "trigger scoping and enabling" do
    test "item_failed fires only for that item and links only its failure", %{scope: scope} do
      version =
        published_version(scope, [
          %{
            "id" => "wf1",
            "enabled" => true,
            "trigger" => %{"type" => "item_failed", "item_id" => "brakes"},
            "actions" => [%{"type" => "open_issue", "title_template" => "Brakes failed"}]
          }
        ])

      inspection = submit(scope, version, "fail")
      run_workflows(scope, inspection)

      assert [issue] = VehicleIssues.list_issues!(%{}, scope: scope).results
      assert issue.title == "Brakes failed"
    end

    test "a disabled workflow is skipped", %{scope: scope} do
      version =
        published_version(scope, [
          %{
            "id" => "wf1",
            "enabled" => false,
            "trigger" => %{"type" => "inspection_failed"},
            "actions" => [%{"type" => "open_issue", "title_template" => "Should not run"}]
          }
        ])

      inspection = submit(scope, version, "fail")
      run_workflows(scope, inspection)

      assert VehicleIssues.list_issues!(%{}, scope: scope).results == []
    end
  end
end
