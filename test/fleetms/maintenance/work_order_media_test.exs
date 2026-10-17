defmodule Fleetms.Maintenance.WorkOrderMediaTest do
  use Fleetms.DataCase

  import Fleetms.MaintenanceFixtures

  alias Fleetms.Maintenance
  alias Fleetms.Storage

  setup :shared_org

  setup do
    dir = Path.join(System.tmp_dir!(), "fleetms_wo_media_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir}
  end

  test "uploading a photo stores an image + thumbnail and destroying removes them", %{
    scope: scope,
    dir: dir
  } do
    wo = work_order_fixture(scope)
    source = Path.join(dir, "photo.png")
    Image.new!(400, 300, color: [10, 100, 200]) |> Image.write!(source)

    photo =
      Maintenance.upload_work_order_photo!(
        %{work_order_id: wo.id, source_path: source},
        scope: scope
      )

    assert Storage.exists?(photo.image_key)
    assert Storage.exists?(photo.thumbnail_key)

    Maintenance.delete_work_order_photo!(photo, scope: scope)

    refute Storage.exists?(photo.image_key)
    refute Storage.exists?(photo.thumbnail_key)
  end

  test "uploading a document stores the file and destroying removes it", %{scope: scope, dir: dir} do
    wo = work_order_fixture(scope)
    source = Path.join(dir, "quote.txt")
    File.write!(source, "vendor quote")

    doc =
      Maintenance.upload_work_order_document!(
        %{
          work_order_id: wo.id,
          source_path: source,
          filename: "quote.txt",
          content_type: "text/plain",
          byte_size: 12
        },
        scope: scope
      )

    assert doc.filename == "quote.txt"
    assert Storage.exists?(doc.storage_key)

    Maintenance.delete_work_order_document!(doc, scope: scope)
    refute Storage.exists?(doc.storage_key)
  end

  test "archiving a work order keeps its media; purging removes it", %{scope: scope, dir: dir} do
    wo = work_order_fixture(scope)
    source = Path.join(dir, "img.png")
    Image.new!(200, 200, color: [0, 0, 0]) |> Image.write!(source)

    photo =
      Maintenance.upload_work_order_photo!(
        %{work_order_id: wo.id, source_path: source},
        scope: scope
      )

    doc_source = Path.join(dir, "d.txt")
    File.write!(doc_source, "x")

    doc =
      Maintenance.upload_work_order_document!(
        %{work_order_id: wo.id, source_path: doc_source, filename: "d.txt", byte_size: 1},
        scope: scope
      )

    # Deleting archives the work order — the files are kept so it can be recovered.
    wo = Maintenance.get_work_order!(wo.id, scope: scope)
    Maintenance.delete_work_order!(wo, scope: scope)

    assert Storage.exists?(photo.image_key)
    assert Storage.exists?(doc.storage_key)

    # Purging is the real delete — it removes the stored files for good.
    wo = Maintenance.get_work_order!(wo.id, scope: scope)
    Maintenance.purge_work_order!(wo, scope: scope)

    refute Storage.exists?(photo.image_key)
    refute Storage.exists?(photo.thumbnail_key)
    refute Storage.exists?(doc.storage_key)
  end
end
