# Item Sprite Library Integration — 2026-08-21

This checkpoint adds a complete runtime sprite candidate for every Stable ID in
`ABYSSAL_BLOOM_ITEM_MASTER_IMPLEMENTATION_READY_2026-08-18.xlsx` without
changing the tested item mechanics or activating later-Layer content.

## Integrated content

- 126 canonical 512×512 RGBA PNG textures live in
  `res://assets/items/by_stable_id/`.
- `res://data/items/item_sprite_manifest.json` maps each workbook Stable ID to
  its canonical Godot texture path and records its approved SHA-256 hash,
  visible bounds, category, rarity, source provenance, and Layer.
- Layer contact sheets and the reproducible generation plan live in
  `res://docs/item_sprite_library/` for future art review and regeneration.
- `res://tests/test_item_sprite_library.gd` verifies that Godot can load all
  manifest textures at the required runtime size.
- `res://tools/validate_project.py` verifies manifest coverage, canonical paths,
  exact hashes, PNG encoding, and the absence of unregistered files.

## Deliberately unchanged

At this checkpoint, the working `res://data/items/layer_1_2_item_catalog.tres`,
its 29 existing entries, and the legacy `res://assets/items/layer_1/`,
`layer_2/`, and `keys/` paths remained intact. Milestone 1 subsequently
migrated the 28 workbook-backed definitions to canonical identities and icons;
see `docs/CANONICAL_ITEM_ID_MIGRATION_2026-08-25.md`.

The new texture library is content availability, not gameplay registration.
No new `ItemDefinition` resources were invented for workbook rows whose
mechanics are not yet implemented, and Layers 3–10 remain inactive. A later
Stable-ID item-model milestone can migrate the working definitions and register
new definitions against the manifest without renaming or regenerating art.

The legacy Layer 2 Quiet Cell Blanket remains in the tested catalog even though
it is not one of the 126 current workbook Stable IDs. Milestone 1 preserves its
original identity and artwork while explicitly marking it as legacy/development
content; it is not counted among the 28 canonical workbook definitions.

## Runtime asset contract

- Filename: `<workbook_stable_id>.png`
- Godot path: `res://assets/items/by_stable_id/<workbook_stable_id>.png`
- Format: PNG, RGBA, 512×512
- Visible art: proportionally fitted and centered; source canvas is not to be
  resized again during import
- Gameplay behavior: always comes from item resources/state, never from the
  filename, art, palette, or folder
- Content activation: registration and Layer activation are separate concerns

## Validation

Run development-worktree validation and the isolated Godot 4.7.2 suite with:

```bash
python3 tools/validate_project.py --allow-generated-cache
GODOT_BIN="$HOME/.local/bin/godot4" python3 tools/run_regression_suite.py
```

The high-resolution transparent masters and original generator outputs are
kept in the separate `AB_ITEM_SPRITES_COMPLETE_MASTERS_2026-08-21.zip` art
archive. They are intentionally excluded from `res://` to avoid importing
non-runtime production sources into every Godot checkout.
