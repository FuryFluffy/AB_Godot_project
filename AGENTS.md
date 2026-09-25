# Abyssal Bloom — Codex Repository Instructions

## Project and target

- This is the production Godot 4.7 desktop project for Abyssal Bloom.
- Preserve the working modular combat, Grapple, exploration, DialogueGraph, node-map, Refuge, and production save systems.
- Extend existing Resources, state models, scenes, and controllers. Do not replace a working subsystem merely for architectural cleanliness.
- Treat repository behavior and passing tests as implementation reality. Newer locked decisions and milestone prompts override older design documents only where they explicitly conflict.

## Before editing

- Inspect the relevant implementation, Resources, scenes, tests, and recent checkpoint documents before proposing changes.
- Search the whole repository for every ID, resource path, serialized field, and test affected by a migration.
- Check `git status --short`. Preserve unrelated user changes and stop if the task overlaps unexplained changes.
- For a cross-system or ambiguous task, state the inspected paths and a concise implementation plan before editing.

## Scope discipline

- Implement only the requested milestone. Do not fold later roadmap work into the current change.
- Keep gameplay state separate from visual presentation.
- Prefer data-driven registration and reusable handlers over hardcoded branches or one-item event types.
- Registration does not imply activation. Layers 3–10 and incomplete Layer 1–2 rooms/items must remain inactive until explicitly enabled.
- Do not invent narrative canon, economy values, equipment definitions, recipes, salvage mappings, or unclear mechanics.
- Preserve deterministic generation and stable IDs.
- Old development saves may be abandoned only in the milestone that intentionally bumps the save version.

## Locked domain rules

- Equipment slots are Main Hand, Off Hand, Armor, Shield, and one Memento per active heroine.
- The shared combat Item Bar has six slots. Personal carried inventory is 3×5 per heroine and is exploration-only.
- Keys live only on the shared Key Chain. Ordinary run keys are lost on defeat; authored persistent keys follow their declared scope.
- Materials collected during a run may be consumed during that run. Surviving materials are banked on voluntary return or defeat. Banked materials cannot be withdrawn into later runs and are spent only through Refuge services.
- Equipped weapon, armor, shield, and Mementos survive defeat. Item Bar contents and heroine backpack contents are lost. Stash contents remain safe.
- Broken equipment loses all positive effects and retains all negative effects.
- Every destructible item/equipment definition must declare `salvage_material_id`; salvage yield is Common=1, Uncommon=2, Rare=3.
- Each recruited heroine has a persistent Refuge loadout and personal preparation inventory. Only active heroines' carried inventories enter run state.
- Authored equipment is used for the demo; do not introduce procedural affixes.
- Production saves use Main Menu Continue/Load. Refuge Save/Load controls are not part of the target UI.
- Active-run persistence uses pre-node and post-resolution safe points. Interrupted nodes resume from the pre-node state with the same encounter/content seed; ordinary mid-combat and mid-dialogue saves are not supported.
- Battlers use static PNG pose states. Grapple presentation is modular and must not alter Grapple mechanics.

## Existing boundaries to preserve

- `CombatEngine` owns combat rules/state; `CombatPresenter` bridges state to views.
- `ReusableCombatHUD` emits intentions and renders supplied state.
- `AuthoredBattlefield` scenes are the authored spatial source of truth.
- `EncounterCoordinator` owns encounter sequencing and map integration.
- `DialogueGraph` Resources and the existing dialogue runner are the production foundation.
- `CampaignSaveSlotStore` atomic writes, validation, backups, and recovery must be retained.
- `LayerRoomCatalogDefinition` is general registration data and must not automatically activate rooms in `LayerMapGenerator`.
- Canonical item artwork is under `res://assets/items/by_stable_id/`; `res://data/items/item_sprite_manifest.json` is the current 126-entry Stable-ID art manifest.
- The forty Layer 1–2 rooms are inertly registered in `res://data/rooms/layer_1_2_room_catalog.tres`.

## Validation

- After any change, run `python3 tools/validate_project.py --allow-generated-cache` in a development worktree. Omit the option only when validating a downloadable package that must not contain `.godot/` cache files.
- With Godot 4.7 available as `godot4`, `godot`, or through `GODOT_BIN`, run `python3 tools/run_regression_suite.py`.
- Add or update focused tests for changed behavior. Do not weaken or delete a failing test solely to make the suite green; update superseded expectations only when the milestone explicitly changes that contract.
- Perform the milestone's manual Godot QA after automated checks.
- Before handoff, review `git diff --check`, `git diff --stat`, and the full diff for unrelated changes.

## Completion report

Report:

1. outcome;
2. files changed;
3. migrations and compatibility behavior;
4. tests run and exact results;
5. manual Godot QA performed or still required;
6. unresolved design blockers;
7. suggested commit message.
