defmodule Fleetms.Repo.TenantMigrations.MigrateIssueLabelsToTags do
  @moduledoc """
  Turns each issue's free-text `labels` into the shared tag vocabulary (tags +
  taggings) and then drops the `labels` column.

  The backfill runs in SQL, per tenant, before the column is removed:
  distinct labels become tags (deduped case-insensitively by the citext name index,
  colour derived from the name so it's stable), and each issue is linked to its tags.
  Rolling back re-adds an empty `labels` column — the tags created here are kept, but
  the original per-issue label lists are not reconstructed.
  """

  use Ecto.Migration

  @palette "ARRAY['slate','red','orange','amber','green','teal','blue','indigo','purple','pink']"

  def up do
    schema = prefix()

    # 1. Each distinct, non-blank label becomes a tag (case-insensitive dedup via the
    #    unique name index). The colour is picked from the palette by the name's hash so
    #    the same word always lands on the same colour.
    execute("""
    INSERT INTO "#{schema}".tags (id, name, color, inserted_at, updated_at)
    SELECT gen_random_uuid(),
           lbl,
           (#{@palette})[((hashtext(lower(lbl)) % 10) + 10) % 10 + 1],
           now(), now()
    FROM (
      SELECT DISTINCT btrim(unnest(labels)) AS lbl
      FROM "#{schema}".issues
      WHERE labels IS NOT NULL
    ) s
    WHERE lbl <> ''
    ON CONFLICT (name) DO NOTHING
    """)

    # 2. Link each issue to the tags for its labels (citext join collapses case variants).
    execute("""
    INSERT INTO "#{schema}".taggings (id, tag_id, issue_id, inserted_at, updated_at)
    SELECT gen_random_uuid(), t.id, i.id, now(), now()
    FROM "#{schema}".issues i
    CROSS JOIN LATERAL unnest(i.labels) AS lbl
    JOIN "#{schema}".tags t ON t.name = btrim(lbl)
    WHERE i.labels IS NOT NULL AND btrim(lbl) <> ''
    ON CONFLICT DO NOTHING
    """)

    alter table(:issues, prefix: prefix()) do
      remove :labels
    end
  end

  def down do
    alter table(:issues, prefix: prefix()) do
      add :labels, {:array, :text}, default: []
    end
  end
end
