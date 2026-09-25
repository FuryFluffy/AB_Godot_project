# Milestone 10 — Authored Equipment, Materials, Salvage, and Recipes

## Goal

Author the initial executable Layer 1–2 demo equipment/material content and connect it to the foundations from Milestones 4, 5, and 9:

- authored Equipment Definitions and starting/demo equipment;
- authored Material Definitions;
- explicit destructibility and salvage mappings;
- deterministic, Refuge-only salvage;
- data-driven Refuge repair/craft/service recipes and a non-UI execution API.

This closes the intentional Milestone 4 authoring gap. It must not become an inventory-screen or Refuge-services UI milestone; that remains Milestone 11.

## Read before editing

Read completely:

- `README.md`
- `docs/EQUIPMENT_INSTANCES_AND_PERSONAL_LOADOUTS_2026-08-26.md`
- `docs/RUN_INVENTORY_STATE_DOMAINS_2026-08-26.md`
- `docs/REFUGE_OWNERSHIP_AND_RUN_RESOLUTION_2026-08-26.md`
- `docs/LOOT_SOURCES_AND_REWARD_ROUTING_2026-08-28.md`
- current Equipment Definition/Instance, personal-loadout, Run Equipment, Refuge Ownership, Item Catalog, reward source, save, and validation code
- all current weapon, armor, shield, and equipment-loadout resources
- current Item definitions for Repair Thread and Wax, Kitchen Knife, Polished Serving Tray, and the implemented L1/L2 catalogue
- existing equipment, item, Refuge, save-slot, campaign-lifecycle, and reward-source tests
- `project_sources/03-01-01_ABYSSAL_BLOOM_COMBAT_MECHANICS_MASTER_REFERENCE_UPDATED_2026-07-23-1-1-.md`
- `project_sources/04-03-02-00_ABYSSAL_BLOOM_MASTER_REFERENCE_UPDATED_2026-07-23-1-1-1-1-.md`

Inspect the project and write a concise implementation plan before editing. Extend the existing state/definition architecture; do not introduce a parallel inventory, equipment, Material, crafting, or persistence model.

## Locked rules

1. Equipment is authored for the demo. Do **not** generate random affixes, enchantments, upgrades, quality rolls, or procedural loot.
2. Personal equipment remains Main Hand, Off Hand, Armor, plus one Memento per active heroine. There is no generic single Weapon slot.
3. Equipment instances remain independently conditioned and serializable. A broken item loses every positive base/enchantment effect but retains negative effects. A broken Main Hand with no valid replacement keeps the existing unarmed fallback.
4. Every destructible Equipment Definition must declare one valid `salvage_material_id`; non-destructible definitions must not declare a fake mapping.
5. Salvage yields exactly one unit for Common, two for Uncommon, and three for Rare equipment. Yield never depends on current condition, location, or a random roll.
6. Materials collected during a run live in the shared Material Pouch. Surviving materials bank on voluntary return **and** defeat. Once banked, they cannot be withdrawn into later runs and may be spent only by Refuge recipes/services.
7. Salvage is a Refuge-owned operation. It operates only on owned Refuge equipment, never by silently deleting active-run equipment or bypassing the loadout/ownership transfer rules.
8. Preserve Save Envelope v3 and the established active-run/safe-point system unless a narrow backwards-safe extension is genuinely required.

## Authoring scope

### Equipment

- Complete the authored initial demo Equipment Definition set using current, executable weapons, armor, shields, and loadouts. Preserve their existing techniques, condition maxima, combat effects, and balance unless a focused compatibility correction is required.
- Use canonical Stable IDs and the existing Resource/catalogue conventions.
- Do not activate art-only workbook rows, no-effect placeholder definitions, or equipment with no complete runtime behavior.
- Apply destructibility only where a real Material mapping is authored in this milestone. Existing current equipment may become destructible only if its mapping and salvage behavior are fully valid and tested.

### Materials

- Add a canonical Material Definition/catalogue with Stable ID, display data, and a declared purpose/reference for every executable material used by salvage or a recipe.
- Use material IDs and names already supported by the project sources where available. If a required authoring value is genuinely absent, choose the smallest neutral, reusable identifier, document the assumption, and do not invent narrative or combat effects.
- Material Definitions must be validated: no duplicate IDs, no invalid tier/category, no unresolvable icon/resource, and no orphan mapping/recipe reference.
- Do not make Materials generic Item Bar items or allow direct withdrawal from banked storage.

### Salvage

- Add one transactional salvage API at the Refuge ownership boundary. It validates ownership, instance identity, definition validity, destructibility, salvage-material existence, and the correct fixed rarity yield before changing state.
- On success, remove exactly that owned equipment instance from its legal Refuge location/loadout/stash, grant the declared material to banked Materials, and persist through the existing `refuge_snapshot` path.
- Equipped/loadout salvage must explicitly handle slot removal; it must never leave an invalid dangling instance reference.
- Reject attempts to salvage nonexistent, foreign, non-destructible, malformed, active-run-only, or already-salvaged equipment without changing state.
- No randomization and no alternate materials. Broken condition does not reduce the yield.

### Refuge recipes/services (data and API only)

- Create authored Recipe/Service Definitions for the initial demo only. A recipe declares Stable ID, inputs, output/service action, target requirements, and any exact condition/quantity result.
- Recipe execution occurs only against **banked** Materials at the Refuge. It is transactional: validate all inputs/targets first, then consume ingredients and apply exactly one result.
- At minimum, expose data/API coverage for equipment repair using the existing condition model. Reuse the current repair behavior; do not redesign weapon durability or combat repair rules.
- A recipe that creates equipment must create a valid independent `EquipmentInstance` in a legal Refuge-owned destination, never a shared resource reference. Do not add arbitrary item duplication.
- If an authoritative craftable equipment output or service is not available, do not invent one merely to increase the recipe count. Document the deliberate absence.
- No player-facing buttons, menus, drag/drop, price/economy balancing, shop flow, or crafting screen in this milestone. Tests may exercise the API directly.

## Persistence and compatibility

- Extend only existing `refuge_snapshot` ownership/banked-Materials data where necessary. Do not add a second Material store.
- Existing valid v3 saves with empty/default banked Materials, pre-Milestone-10 equipment definitions, or Refuge snapshots must load into safe authored defaults.
- Pre-v3 incompatibility, atomic writes, valid `.bak` recovery, canonical item-ID migration, and active-run safe points must remain intact.
- Malformed material/equipment/recipe/salvage snapshots must reject transactionally without losing an equipment instance, consuming Materials, or changing a valid loaded campaign.

## Explicitly out of scope

- Refuge inventory/services UI, Stash UI, equipment screen, crafting screen, drag/drop, shop/economy interface, or bulk-management UX (Milestone 11).
- Random affixes, procedural equipment, item-rarity rolls, upgrades, enchantments, new combat effects, combat balance changes, or a new durability system.
- New active-run material drops/loot-table expansion beyond what is required to exercise existing executable reward routing. Do not activate art-only/incomplete rewards.
- New room/event/dialogue content, ordinary battle-room activation, enemies, AI, battlefields, sprites, or combat presentation.
- Save Envelope v4, a persistence rewrite, or broad regression-test cleanup.

## Required validation and tests

Add or extend focused tests for at least:

1. Authored Equipment and Material catalogues: canonical IDs, duplicate detection, valid slots, valid condition maxima, material mappings, and no orphan references.
2. Destructible equipment requires a valid mapping; non-destructible equipment rejects one; existing combat behavior and broken/unarmed fallback remain correct.
3. Salvage from valid Refuge-owned Stash/loadout locations gives exactly Common=1, Uncommon=2, Rare=3 and deletes only the selected instance/slot reference.
4. Salvage is deterministic and condition-independent; foreign, invalid, active-run, non-destructible, duplicate, and malformed requests fail transactionally.
5. Banked Materials persist through save/load and cannot be moved into a later run; voluntary return and defeat bank run Materials according to Milestone 5.
6. Recipe/service validation and execution: exact inputs, targets, condition restoration/output, successful persistence, and rollback on insufficient/malformed ingredients or targets.
7. Existing v3/Milestones 5–9 snapshots load safely; malformed snapshots, `.bak` recovery, and pre-v3 incompatibility remain correct.

Run:

- structural validation;
- regression-runner self-tests;
- focused equipment, item, Refuge, save-slot, lifecycle, active-run, reward-source, and new Material/salvage/recipe tests;
- the complete Godot 4.7.2 suite;
- `git diff --check`.

Compare suite results script-by-script to the accepted Milestone 9 baseline. No existing script may newly fail or materially worsen. Do not commit.

## Manual Godot QA

1. Start a New Campaign; verify all existing weapons, armor, shields, techniques, condition loss, breakage, repair, and unarmed fallback still work.
2. Reach the Refuge and load/save a campaign; confirm existing owned equipment persists with exact condition.
3. Using the temporary test path/API only, salvage one Common, one Uncommon, and one Rare authored destructible equipment instance; verify fixed yields and removal from the exact selected Refuge slot/stash location.
4. Confirm a non-destructible/foreign/active-run instance cannot be salvaged and changes nothing.
5. Exercise an authored repair recipe; verify exact banked Material consumption, condition result, save/load persistence, and no later-run Material withdrawal.
6. Smoke-test defeat and voluntary return to ensure Material banking and equipment survival remain correct.
7. Smoke-test Main Menu, slots, Continue, Item Bar, Key Chain, Event Rooms, combat, Grapple, generated maps, and Refuge presentation.

## Completion report

Report every authored Equipment Definition, Material Definition, salvage mapping/yield, and Recipe/Service Definition; changed files; compatibility behavior; test results vs baseline; manual QA remaining; and any assumptions or deliberately unavailable content. Do not commit.

Suggested commit message after manual acceptance:

`Implement Milestone 10 authored equipment materials salvage recipes`
