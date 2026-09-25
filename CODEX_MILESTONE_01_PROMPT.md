# Codex implementation prompt — Milestone 1

Implement Milestone 1 only: canonical workbook Stable IDs and the minimum item metadata foundation.

## Goal

Make the August 18 workbook Stable IDs canonical for the currently implemented Layer 1–2 item definitions and all code/data references to them, while preserving current gameplay behavior. Establish only the metadata needed by later inventory/equipment/save milestones. Do not implement the new inventory domains, save schema, Refuge persistence, salvage execution, crafting, equipment instances, or Layers 3–10 gameplay.

## Inspect before editing

First inspect and report findings from at least:

- `AGENTS.md`
- `README.md`
- `scripts/data/items/item_definition.gd`
- `scripts/data/items/item_catalog_definition.gd`
- `data/items/layer_1_2_item_catalog.tres`
- all Resources under `data/items/`
- `data/items/item_sprite_manifest.json`
- item-ID consumers under `scripts/battle/`, `scripts/exploration/`, `scripts/dialogue/`, and `scripts/map/`
- `tools/validate_project.py`
- `tools/run_regression_suite.py`
- item, dialogue, node-map, Layer 2, save, and campaign tests
- `docs/ITEM_SPRITE_LIBRARY_INTEGRATION_2026-08-21.md`

Use `rg` to build an exhaustive legacy-ID reference inventory before changing anything. Confirm the worktree state with `git status --short`. Then give a concise plan before editing.

## Canonical migration requirements

- Derive the current implemented-item mapping from `data/items/item_sprite_manifest.json`: its `stable_id` is canonical and its `source_path` identifies the matching legacy project item artwork.
- Migrate each matching implemented ItemDefinition and every code, Resource, fixture, dialogue gate, generated-placement rule, initial loadout, and test reference to the canonical Stable ID.
- Point migrated definitions at their canonical `res://assets/items/by_stable_id/<stable_id>.png` textures.
- Preserve display names, descriptions, effects, stack limits, target rules, action costs, and all tested behavior.
- Do not create executable definitions for all 126 workbook rows. Artwork availability is not gameplay activation.
- Do not use a runtime alias layer as the permanent identity model. A small explicit migration table is acceptable only if needed to load a deliberately retained old format; old development saves may instead be abandoned in the later intentional save-version milestone.
- `quiet_cell_blanket` is a legacy implemented item absent from the canonical 126-row workbook. Do not silently rename it to an unrelated Stable ID or pretend it is canonical. Preserve it as clearly isolated legacy/development content unless repository inspection proves it is required by current production flow; document the result and add validation preventing it from being mistaken for a workbook item.

## Minimum metadata foundation

Extend the current item data model rather than introducing a parallel item-definition system. Add only fields whose values are authoritative from the existing manifest/workbook handoff, such as:

- content/storage category: Active, Memento, Key, Material, Story, Knowledge;
- rarity;
- origin Layer;
- canonical icon path through the definition's `icon` Resource reference;
- implementation/activation readiness if this is required to prevent registered art from becoming executable content.

Do not invent missing salvage-material assignments, recipes, economy values, effect semantics, or equipment data. If the complete workbook metadata is not present in the repository, add only fields and values supported by `item_sprite_manifest.json`, leave later metadata out, and report the missing authoritative source rather than guessing.

Keep `item_type` compatibility only as narrowly as necessary for the working item-use code; do not redesign storage behavior in this milestone.

## Validation and tests

Add or update focused tests proving:

- every migrated implemented definition uses its canonical Stable ID;
- canonical IDs are unique;
- every migrated icon resolves to the matching Stable-ID texture;
- every implemented workbook item resolves through the existing catalog;
- no old implemented ID remains in active code/data/tests, except any explicitly documented legacy-only Quiet Cell Blanket identity;
- the 126-entry sprite manifest remains complete but does not activate unimplemented items;
- current item use, dialogue item gates, generated pickups, Layer 2 reward, node-map behavior, and save-slot tests still pass.

Run:

```bash
python3 tools/validate_project.py
python3 tools/run_regression_suite.py
git diff --check
```

Also open the project in Godot 4.7 and manually verify:

1. New Campaign reaches the existing opening flow.
2. Starting Item Bar entries display and work as before.
3. A generated/event-room pickup can be collected.
4. Warm Wine dialogue gating still works.
5. The first Layer 2 Chain Oil reward still resolves.
6. Main Menu save-slot screens open without parse/resource errors.

## Done when

- Current implemented item behavior is unchanged.
- Workbook Stable IDs are canonical throughout active Layer 1–2 code/data.
- The minimum metadata extension is documented and validated.
- Later-layer art remains inert.
- All structural and Godot regression tests pass.
- No inventory/save/Refuge/equipment/salvage implementation has leaked into this milestone.

Finish with a concise summary of inspected architecture, exact files changed, ID mapping, tests and manual QA results, unresolved inputs, and a proposed commit message. Do not commit unless I explicitly ask you to.
