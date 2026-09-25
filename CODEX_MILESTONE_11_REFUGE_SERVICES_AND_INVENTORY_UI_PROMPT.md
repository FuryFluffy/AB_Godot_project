# Milestone 11 — Refuge Services and Inventory UI

## Goal

Make the Bloom Refuge a usable desktop-first preparation headquarters for Lysandra, Mira Voss, and Seraphine.

The player must be able to inspect and manage the **already authoritative** Refuge-owned state: selected-party order, personal preparation inventory, Main Hand/Off Hand/Armor/Memento loadouts, Stash, Key Chain, banked Materials, equipment condition, and the Milestone 10 salvage/repair recipe API. The interface must make ownership boundaries and defeat/return consequences understandable before launching a run.

This milestone exposes existing systems cleanly. It does not invent service economics, training, upgrades, items, recipes, combat effects, or new progression rules just to populate a menu.

## Read before editing

Read completely:

- `README.md`
- `docs/REFUGE_OWNERSHIP_AND_RUN_RESOLUTION_2026-08-26.md`
- `docs/RUN_INVENTORY_STATE_DOMAINS_2026-08-26.md`
- `docs/EQUIPMENT_INSTANCES_AND_PERSONAL_LOADOUTS_2026-08-26.md`
- `docs/AUTHORED_EQUIPMENT_MATERIALS_SALVAGE_RECIPES_2026-08-28.md`
- `docs/ACTIVE_RUN_SAFE_POINTS_AND_CONTINUE_2026-08-26.md`
- existing Bloom Refuge scene/controller, Main Menu, campaign save/loading, Refuge Ownership, equipment/loadout, Run Inventory, Item Catalog, Material/Recipe catalogues, and service APIs
- existing tests for Refuge, production save slots, campaign lifecycle, items, equipment, active-run safe points, and salvage/recipes
- `project_sources/01-03-ABYSSAL_BLOOM_COMBAT_UI_ELEMENT_MANIFEST_2026-07-24-1-1-.md`
- `project_sources/04-03-02-00_ABYSSAL_BLOOM_MASTER_REFERENCE_UPDATED_2026-07-23-1-1-1-1-.md`

Inspect the current scene/UI architecture and write a concise implementation plan before editing. Extend current Godot scenes and controllers; do not replace working gameplay, save, or state systems with a separate UI model.

## Locked state and ownership rules

- The Refuge persists selected party order, each heroine’s 15-slot preparation inventory, personal Main Hand/Off Hand/Armor loadout, Memento, shared Stash, persistent Key Chain, and banked Materials.
- Default/recruitment order remains Lysandra → Mira → Seraphine. Only recruited heroines may be selected or reordered.
- Keys are always on the shared Key Chain, never in a backpack or Item Bar. Ordinary run keys are lost on defeat; persistent-key behavior is authored per key.
- Banked Materials are Refuge-only: they cannot be withdrawn into a run and can only be consumed by valid Refuge recipes/services.
- The Stash is safe and never automatically enters a run.
- Voluntary return preserves surviving carried items and banks Materials; defeat loses Item Bar/backpack/ordinary run keys but preserves equipped equipment (including condition), Mementos, Stash, banked Materials, and Story/Lore/Knowledge.
- A broken item loses positive effects but retains negative effects; an empty/broken Main Hand keeps the current unarmed fallback. Condition and destructible/salvage information must be displayed accurately.
- All equipment is authored. The runtime equipment registry includes enemy/fixture resources, but these must not appear as player-selectable loot, crafting outputs, or ordinary Refuge choices unless a separate authored player-availability rule permits them.

## Required UI

### 1. Refuge hub and navigation

- Preserve the existing Refuge art/presentation and existing New Run/return/save boundaries.
- Add a clearly navigable desktop-first Refuge management surface. It may use tabs or a master-detail layout, but must be keyboard/mouse usable at the project’s normal desktop resolutions without overlapping, clipped, or unreadable panels.
- Include clear entry points for: **Party & Loadouts**, **Inventory & Stash**, **Materials & Services**, **Key Chain**, and **Launch/Return**.
- No full-screen modal maze: keep the active party, current selection, Back/Close, and available run-launch action understandable at all times.

### 2. Party and personal loadouts

- Show the three heroine cards in their selected-party order, recruitment/active state, HP/MP/Resolve/Corruption where authoritative, and current personal equipment.
- Permit legal selected-party reordering and persistence. Reject duplicates, unrecruited heroines, and malformed orders transactionally with player-readable feedback.
- For a selected heroine, show Main Hand, Off Hand, Armor, and Memento with definition name/icon, compatibility, current/max condition, broken state, and salvage availability where applicable.
- Support only legal equipment movement/equip/unequip between that heroine’s loadout and the legal Refuge-owned source (personal preparation or Stash) through existing ownership APIs. Never expose runtime-only enemy/fixture definitions as candidates.
- Mementos remain one per heroine and may not be placed in the Item Bar or generic stack inventory.

### 3. Preparation inventory, Item Bar, Stash, and Key Chain

- Display each heroine’s ordered 3×5 preparation inventory, with stack quantity and clear empty slots.
- Display the six-slot ordered Item Bar preparation/launch state using the existing authoritative state model. If the current model lacks a persistent pre-run Item Bar configuration, add the smallest explicit validated field at the existing Refuge/run-launch boundary; do not create a parallel inventory or silently overload unrelated fields.
- Support legal, transactional transfers between preparation inventory, Item Bar preparation, and Stash. Validate canonical IDs, category, stack limits, capacity, heroine ownership, and deterministic ordering. Failed moves must alter nothing.
- Clearly distinguish combat-usable Active items (Item Bar), exploration Active items (personal preparation), Keys (Key Chain only), Mementos (heroine slot only), and Materials (banked-only).
- Display Key Chain contents and persistence scope. Do not provide a fake “assign key” action or permit backpack/Item Bar transfers.
- Display Stash stacks and equipment instances separately; Stash equipment must retain instance ID/condition and never collapse into a generic item count.

### 4. Materials and executable Refuge services

- Display banked Material identities, icons, and quantities. They are informational except where a valid recipe/service consumes them.
- List only authored, valid Milestone 10 Recipe/Service Definitions. For each, show inputs, target requirements, output/effect, and clear disabled reasons (insufficient Materials, invalid/damaged target requirement, etc.).
- Implement UI for the existing salvage flow and authored repair service through their transactional APIs. Require a deliberate confirmation for salvage because it destroys the selected equipment instance.
- Refresh all affected panels after successful salvage/repair and save through the existing Refuge persistence path; failures must present the returned error without partial UI/state updates.
- Do not add costs, Restore Resolve, Cleanse Corruption, training, upgrades, crafting outputs, or services that have no authoritative backend definition. They may be shown as clearly unavailable/deferred service cards only—no buttons that pretend to work.

### 5. Launch and run boundary

- Before launch, show the selected party and the actual carried preparation/Item Bar/Key Chain rules in concise plain language.
- Start a run only through the existing launch/ownership-transfer path. The UI must not duplicate equipment, create keys, withdraw banked Materials, or leave stale items in both Refuge and run state.
- Preserve active-run Continue and Main Menu behavior. The Refuge UI must not reintroduce arbitrary Save/Load controls, mid-combat saving, or mid-dialogue saving.

## Presentation requirements

- Use reusable scene-based Godot UI components, not a large script-only runtime layout.
- Keep gameplay state separate from presentation. The UI reads state and invokes small validated controller/service methods; it must not manipulate snapshot dictionaries directly.
- Use existing canonical item/equipment/material art when available. Do not generate or import new visual assets solely for this milestone.
- Include empty, full, broken, unavailable, and error states; no invisible actions or silent failures.
- Preserve existing combat, map, dialogue, Main Menu, and Refuge presentation behavior outside the new management surface.

## Persistence and compatibility

- Continue using Save Envelope v3 and the existing `refuge_snapshot`/active-run boundaries. Any new Refuge preparation field must be narrow, serializable, validated, and default safely for existing valid v3 saves.
- Preserve atomic writes, `.bak` recovery, pre-v3 incompatibility, canonical item-ID migration, and active-run safe-point behavior.
- Restore malformed UI-preparation/Refuge snapshots transactionally without corrupting party order, inventory, equipment, Stash, Key Chain, or banked Materials.

## Explicitly out of scope

- New gameplay services or economics: Restore Resolve, Cleanse Corruption, training, upgrades, shops, prices, currencies, and non-authored crafting outputs.
- New items, equipment, Materials, salvage mappings, recipes, procedural affixes, loot tables, or combat/balance changes.
- Ordinary battle-room activation, enemies/AI, Grapple changes, map-flow work, dialogue/cutscene production, visual-profile/sprite work, or new art generation.
- Save Envelope v4, broad save-system redesign, arbitrary Save/Load controls, or fixing the accepted unrelated regression backlog.

## Tests and validation

Add focused tests for at least:

1. Scene/controller construction and safe rendering of empty/default/legacy v3 Refuge state.
2. Selected-party reordering: persistence, duplicate/unrecruited rejection, default order, and no launch-state duplication.
3. Legal/illegal equipment moves, slot compatibility, Memento uniqueness, condition/broken display data, and no runtime-only enemy equipment candidates.
4. Transactional preparation/Item Bar/Stash transfers, category boundaries, stack/capacity behavior, and six-slot ordering.
5. Key Chain and banked-Material non-transferability.
6. Salvage confirmation/action, exact removal/yield, repair inputs/results, UI refresh, save/load persistence, and transactional error feedback.
7. Launch transfers only selected-party preparation/loadouts and preserves existing defeat/return/Continue rules.
8. Existing valid v3 snapshots load with safe UI defaults; malformed snapshots reject transactionally.

Run:

- structural validation;
- regression-runner self-tests;
- focused Refuge/UI, item, equipment, material, recipe, save-slot, lifecycle, active-run, and launch-transfer tests;
- complete Godot 4.7.2 regression suite;
- `git diff --check`.

Compare the suite script-by-script with the accepted Milestone 10 baseline. Do not fix unrelated established failures in this milestone. Do not commit.

## Manual Godot QA

1. Enter the Refuge from a new/loaded campaign; navigate every panel with mouse and keyboard at normal desktop resolution.
2. Reorder the three heroines; save/load; then launch a run and verify the exact order.
3. Move valid Active items between preparation, Item Bar preparation, and Stash; verify invalid category/capacity moves are rejected without loss.
4. Equip/unequip legal personal gear; verify compatibility, Memento limits, condition/broken state, and that enemy/fixture equipment cannot be selected.
5. Inspect Key Chain and banked Materials; confirm neither can be incorrectly transferred into a backpack or Item Bar.
6. Salvage and repair through the UI; confirm confirmation, exact Materials, condition, persistence, cancellation, and failure feedback.
7. Launch, voluntarily return, and suffer defeat in separate runs; confirm Milestone 5 ownership/loss/banking rules and no duplicates.
8. Verify Continue, Main Menu, normal save/load, combat, Grapple, Event Rooms, generated maps, and Refuge art/presentation remain intact.

## Completion report

Report changed files; the exact Refuge panels/actions implemented; intentionally unavailable services; new snapshot/default behavior; test results against baseline; manual QA remaining; and any clear follow-up needed for later authored services. Do not commit.

Suggested commit message after manual acceptance:

`Implement Milestone 11 Refuge services and inventory UI`
