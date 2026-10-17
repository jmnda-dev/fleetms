defmodule Fleetms.VehicleIssues.IssueMediaTest do
  use Fleetms.DataCase

  import Fleetms.IssueFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.Storage
  alias Fleetms.VehicleIssues

  setup :shared_org

  setup do
    dir =
      Path.join(System.tmp_dir!(), "fleetms_issue_media_#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir}
  end

  test "archiving keeps the stored files; purging removes them", %{scope: scope, dir: dir} do
    issue = issue_fixture(scope, %{vehicle_id: vehicle_fixture(scope).id})

    img = Path.join(dir, "img.png")
    Image.new!(200, 200, color: [10, 20, 30]) |> Image.write!(img)

    photo =
      VehicleIssues.upload_issue_photo!(%{issue_id: issue.id, source_path: img}, scope: scope)

    doc_src = Path.join(dir, "d.txt")
    File.write!(doc_src, "x")

    doc =
      VehicleIssues.upload_issue_document!(
        %{issue_id: issue.id, source_path: doc_src, filename: "d.txt", byte_size: 1},
        scope: scope
      )

    assert Storage.exists?(photo.image_key)
    assert Storage.exists?(doc.storage_key)

    # Deleting archives the issue — the files are kept so it can be recovered.
    issue = VehicleIssues.get_issue!(issue.id, scope: scope)
    VehicleIssues.delete_issue!(issue, scope: scope)

    assert Storage.exists?(photo.image_key)
    assert Storage.exists?(doc.storage_key)

    # Purging is the real delete — it removes the stored files for good.
    issue = VehicleIssues.get_issue!(issue.id, scope: scope)
    VehicleIssues.purge_issue!(issue, scope: scope)

    refute Storage.exists?(photo.image_key)
    refute Storage.exists?(photo.thumbnail_key)
    refute Storage.exists?(doc.storage_key)
  end
end
