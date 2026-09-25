# Milestone 9 — Loot Sources and Reward Routing

## Goal

Replace the remaining ad-hoc node/reward grants with one deterministic, data-driven reward-selection and routing path for the currently executable Layer 1 and Layer 2 demo content.

This milestone owns **where a reward comes from**, **which already executable canonical item it selects**, **the current-layer weighting rule**, **how it reaches the correct Run Inventory domain**, and **how it remains bound to one resolved node/encounter so it cannot duplicate**.

It does not author the unreleased item backlog, ordinary battle rooms, new event content, crafting, or inventory UI.

## Read before editing

Read completely:

- `README.md`
- `docs/RUN_INVENTORY_STATE_DOMAINS_2026-08-26.md`
- `docs/REFUGE_OWNERSHIP_AND_RUN_RESOLUTION_2026-08-26.md`
- `docs/ACTIVE_RUN_SAFE_POINTS_AND_CONTINUE_2026-08-26.md`
- `docs/LAYER_1_2_GENERATOR_ACTIVATION_2026-08-27.md`
- `docs/L1_JAILER_REVERSE_L2_DEMO_FLOW_2026-08-27.md`
- item definitions/catalogue, event-room reward code, generated-room item placement code, map-node completion, encounter outcome, Run Inventory, Run State, save, and active-run snapshot code
- the existing item, canonical-ID, room/event, safe-point, map, lifecycle, and demo-flow tests
- `project_sources/04-03-02-00_ABYSSAL_BLOOM_MASTER_REFERENCE_UPDATED_2026-07-23-1-1-1-1-.md`
- `project_sources/02-04-ABYSSAL_BLOOM_LAYER_1_2_ROOM_AND_BATTLEMAP_VISUAL_SPEC_2026-07-24-1-1-.md`

Inspect the current implementation and write a concise plan before editing. Extend the existing Item Catalog, Run Inventory, event-room, encounter, map, and active-run architecture; do not create a second reward/inventory system.

## Canonical rules

### 1. Reward sources

Create or formalize authored reward-source definitions/metadata for the production channels already represented by the game:

- map Item nodes/caches;
- ordinary battle/elite/boss encounter completion where an executable source is authored;
- executable event-room/room hotspots;
- fixed story/recruitment/boss rewards that already exist.

Each source must explicitly declare its source identifier, source channel, eligible item entries, quantity/stack rules, layer eligibility, and whether it is once-only. Do not infer rewards from filenames, display names, node columns, or UI labels.

Keep fixed authored rewards fixed. They must not be replaced by a random pool merely to use the new framework.

### 2. Eligible production items only

- Select only items that are present in the canonical `ItemCatalogDefinition`, have a canonical Stable ID, and have complete executable runtime behavior for their category.
- The 98 art-only/workbook-only items remain unavailable. Do not add placeholder effects or grant an item merely because artwork or a manifest row exists.
- Preserve the existing narrow legacy-load compatibility for `quiet_cell_blanket`; it is not eligible for new rewards.
- Story, Lore, Knowledge, unknown, legacy-alias, inappropriate-category, unimplemented Material, unowned Memento, and unimplemented Equipment rewards must reject clearly and leave state unchanged.
- If a source has no valid eligible entry after validation, fail or disable that source with a diagnostic. Never silently substitute an unrelated item, invent an effect, or produce a partial reward.

### 3. Deterministic selection and current-layer weighting

- Selection must use explicit deterministic seed derivation from the campaign/run seed plus stable source/node/encounter identity. Never use wall-clock time, ambient RNG, or unordered dictionary iteration.
- A source's result must be stable across restart, safe-point save/load, Continue, retreat/backtracking, and replay of the same valid campaign seed.
- Apply the locked **current-layer ×3** weighting: for a source that can select eligible items from multiple layers, every eligible item belonging to the current map layer has weight `3`; every other eligible item has its authored base weight. Do not duplicate entries to simulate weighting.
- Filter eligibility first, then apply weights, then make one deterministic roll. Use a stable, documented tie/order rule.
- Store the resolved reward/result against the stable node or encounter source identity before or atomically with granting it, so a resolved source cannot reroll after save/load.

### 4. Route through Run Inventory

Use the Milestone 3 ownership rules; do not bypass them:

| Item category | Destination |
|---|---|
| Combat-usable Active | shared six-slot Item Bar |
| Exploration-only Active | authored heroine’s 15-slot backpack |
| Key | shared Key Chain |
| Material | shared run Material Pouch, only when a complete executable Material definition exists |
| Memento | one Memento slot for its authored heroine, only when ownership is explicit |

Routing must preserve canonical validation, stack limits, deterministic stack/slot order, capacity behavior, and transactional failure. A full destination must not consume/mark a reward as claimed unless the existing source policy explicitly supports a safe deferred claim; define and test that policy rather than silently losing an item.

Do not alter Milestone 5 defeat/return/banking rules. Do not persist banked Materials through a new shortcut.

### 5. One-time resolution, map, and persistence

- A reward is bound to the generated node ID or encounter source ID, not only to an underlying room ID. Two distinct generated nodes may use the same source definition but must have independent correctly seeded state when the topology permits it.
- Revisiting a resolved room/node, loading an active-run safe point, retrying combat, or resuming Continue must never duplicate its reward.
- Battle seed allocation/retry behavior must remain unchanged. Reward selection must use a separate, documented deterministic stream.
- Keep Save Envelope at `save_version = 3` unless a narrow backwards-safe extension is required. Existing valid v3, Milestone 7 generated graphs, and Milestone 8 active-run snapshots must load safely.
- Malformed reward catalog/source/snapshot data must fail transactionally without granting an item, corrupting the map, or changing an unrelated save slot.

## Required implementation work

1. Audit every current direct reward grant (including the temporary Item-node Bandage Roll path, event-room grants, fixed encounter rewards, and generated room-item placement) and route applicable production grants through the shared source/resolution path.
2. Preserve the existing Wine Cellar, Butler's Office, Rusty Key/Key Chain, Chain Oil, opening, recruitment, Blood Nun, Jailer, and Farthest-Cell/Refuge behavior unless a direct reward bug requires a narrow correction.
3. Make the source result inspectable in normal logs/debug output sufficiently for QA, without adding an inventory or debug UI redesign.
4. Add structural validation for duplicate source IDs, invalid Stable IDs, invalid layer values/weights, illegal item/category destinations, impossible ownership, malformed quantities, and references to unavailable content.

## Explicitly out of scope

- Activation of the 98 art-only items or any incomplete registered content.
- New item effects, new consumables, balance changes, Equipment/Material authoring, equipment drops, salvage, recipes, crafting, or Refuge services/UI.
- Ordinary battle-room/encounter/battlefield authoring, enemy/AI work, combat/Grapple changes, sprite or presentation work.
- New room dialogue, story, cutscenes, bespoke event scripting, or map topology/route changes.
- Active-run save-system redesign, Save Envelope v4, or broad testing cleanup.

## Tests and validation

Add focused tests covering at least:

1. Each source channel selects only valid executable canonical items and routes them to the correct Run Inventory domain.
2. Current-layer entries receive exactly three times their base relative weight; selection is deterministic for fixed seeds.
3. Fixed authored rewards remain fixed, including Rusty Key and the existing executable event/battle rewards.
4. A resolved node/encounter reward does not reroll or duplicate after revisit, safe-point restore, Continue, combat retry, voluntary return, or defeat as applicable.
5. Full/invalid destination behavior is transactional and follows the explicit deferred-claim policy, with no lost/phantom claim.
6. Incomplete/art-only, legacy-only, unknown, wrong-category, malformed, and nonexistent ownership entries reject safely.
7. Existing valid v3/Milestone 7/Milestone 8 snapshots remain compatible; malformed reward snapshots reject transactionally.

Run:

- structural validation;
- regression-runner self-tests;
- focused item, canonical-ID, Run Inventory, event-room, generated-room, map, lifecycle, safe-point, save-slot, and demo-flow tests;
- the full Godot 4.7.2 suite;
- `git diff --check`.

Compare the full suite script-by-script to the accepted Milestone 8 baseline. No existing script may newly fail or materially worsen. Do not commit.

## Manual Godot QA

1. Start a fresh campaign; complete the opening and confirm existing Item Bar rewards remain visible and usable.
2. Complete Wine Cellar and Butler's Office; confirm their fixed rewards still work, and Rusty Key enters/consumes from Key Chain correctly.
3. Resolve several deterministic Item/room/battle reward sources; relaunch through pre-node and post-node Continue and confirm exact results with no duplicates.
4. Revisit resolved nodes and repeat/retry a battle where legal; confirm reward state is not duplicated or rerolled.
5. Reach the L2/Jailer and reverse-L2 route; confirm existing Chain Oil/current fixed rewards remain correct and no unavailable item appears.
6. Smoke-test defeat and voluntary return to confirm reward ownership/loss/banking behavior remains Milestone 5-compliant.
7. Smoke-test Main Menu, save slots, combat, Grapple, Item Bar, Key Chain, Event Rooms, Refuge, and generated maps.

## Completion report

Report changed files; each executable reward source and its routing; current-layer weighting behavior; snapshot compatibility; focused/full test results compared with baseline; manual QA remaining; and every deliberate unavailable-content deferral. Do not commit.

Suggested commit message after manual acceptance:

`Implement Milestone 9 deterministic loot sources and reward routing`
