# Seed assets

These are the placeholder photos and documents the database seed
(`priv/repo/seeds.exs`) attaches to the sample vehicles. They are generic,
copyright-safe stand-ins so a freshly seeded app looks real without shipping
anyone's actual fleet photos or paperwork.

## How the seed uses them

The seed never hard-codes a path. It looks files up **by filename** in this
directory (see `Seeds.store/1` and `Seeds.asset_for/1` in `seeds.exs`):

- A vehicle's photo is chosen from its body type — tractor units get
  `tractor.png`, trucks/dumpers get `truck.png`, pickups get `pickup.png`,
  vans get `van.png`, and anything else falls back to `sedan.png`.
- Every `*.png` has a matching `*_thumb.png` used for list/grid thumbnails.
- Every sample vehicle is given the two documents `insurance_certificate.pdf`
  and `registration_book.pdf`.

## Replacing the dummies with real photos / documents

You do **not** need to touch any code. Just **overwrite the files in this
directory, keeping the same filenames**, then re-run the seed.

1. Drop your real photo in as, e.g., `truck.png` (overwriting the placeholder).
2. Make a smaller version for the list thumbnail and save it as `truck_thumb.png`.
   (Any size works; roughly 300px wide is plenty. If you don't make one, copy
   the full image over the `_thumb` name — it will just load a larger file.)
3. Replace `insurance_certificate.pdf` / `registration_book.pdf` with your own
   PDFs under the same names.
4. Reseed a fresh database:

   ```sh
   mix ash.reset   # drops, recreates, migrates and re-seeds (DESTROYS dev data)
   ```

### Filenames the seed expects

| File                          | Used for                                  |
| ----------------------------- | ----------------------------------------- |
| `tractor.png` / `_thumb`      | Tractor / prime-mover vehicles            |
| `truck.png` / `_thumb`        | Trucks and dump trucks                    |
| `pickup.png` / `_thumb`       | Pickups                                   |
| `van.png` / `_thumb`          | Vans                                      |
| `sedan.png` / `_thumb`        | Fallback for every other body type        |
| `insurance_certificate.pdf`   | Each vehicle's "Insurance certificate" doc |
| `registration_book.pdf`       | Each vehicle's "Registration (white book)" doc |

### Adding a new body-type image

If you want a distinct photo for a body type that currently falls back to
`sedan.png`, add the image here and add a matching `asset_for/1` clause in
`priv/repo/seeds.exs` pointing at the new base name.

> Keep anything you put here license-clean — this directory is committed to the
> repo and ships with the open-source project.
