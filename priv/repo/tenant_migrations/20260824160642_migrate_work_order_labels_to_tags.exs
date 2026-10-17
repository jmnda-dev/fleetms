defmodule Fleetms.Repo.TenantMigrations.MigrateWorkOrderLabelsToTags do
  @moduledoc """
  Turns each work order's free-text `labels` into the shared tag vocabulary (tags +
  taggings) and then drops the `labels` column — the same backfill used for issues.

  Distinct labels become tags (deduped case-insensitively by the citext name index,
  colour derived from the name so it's stable and matches existing tags created from
  the same word), and each work order is linked to its tags. Rolling back re-adds an
  empty `labels` column; the original per-work-order label lists are not restored.
  """

  use Ecto.Migration

  @palette "ARRAY['slate','red','orange','amber','green','teal','blue','indigo','purple','pink']"

  def up do
    schema = prefix()

    execute("""
    INSERT INTO "#{schema}".tags (id, name, color, inserted_at, updated_at)
    SELECT gen_random_uuid(),
           lbl,
           (#{@palette})[((hashtext(lower(lbl)) % 10) + 10) % 10 + 1],
           now(), now()
    FROM (
      SELECT DISTINCT btrim(unnest(labels)) AS lbl
      FROM "#{schema}".work_orders
      WHERE labels IS NOT NULL
    ) s
    WHERE lbl <> ''
    ON CONFLICT (name) DO NOTHING
    """)

    execute("""
    INSERT INTO "#{schema}".taggings (id, tag_id, work_order_id, inserted_at, updated_at)
    SELECT gen_random_uuid(), t.id, w.id, now(), now()
    FROM "#{schema}".work_orders w
    CROSS JOIN LATERAL unnest(w.labels) AS lbl
    JOIN "#{schema}".tags t ON t.name = btrim(lbl)
    WHERE w.labels IS NOT NULL AND btrim(lbl) <> ''
    ON CONFLICT DO NOTHING
    """)

    alter table(:work_orders, prefix: prefix()) do
      remove :labels
    end
  end

  def down do
    alter table(:work_orders, prefix: prefix()) do
      add :labels, {:array, :text}, default: []
    end
  end
end
