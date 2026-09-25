# Refuge Services and Inventory UI — 2026-08-29

## Implemented surface

The existing Bloom Refuge scene now exposes the authoritative
`RefugeOwnershipState` through five desktop tabs:

- **Party & Loadouts** shows the selected three-heroine order, current
  HP/MP/Resolve/Corruption, Memento assignment, equipment instances,
  condition, broken state, equipped slot, and salvage status. Party reorder,
  legal equip/unequip, and heroine/Stash equipment movement use the existing
  ownership APIs.
- **Inventory & Stash** shows each heroine's ordered 3×5 preparation slots,
  the shared ordered six-slot pre-run Item Bar, safe Stash item stacks, and
  Stash equipment instances. One-item transfers are transactional.
- **Materials & Services** shows the four authored Material balances, the one
  authored cloth-Armor repair recipe, its exact inputs and eligible damaged
  targets, plus a confirmed destructive salvage flow for explicitly available
  player equipment. Service refreshes retain the exact selected equipment
  instance while it remains eligible, and successful repairs report the
  before/after condition explicitly.
- **Key Chain** shows key quantities and authored persistence scope. It has no
  assignment or transfer action.
- **Launch & Return** retains the existing seed and launch actions and explains
  exactly which domains move, remain safe, or are lost on defeat.

Resolve restoration, Corruption cleansing, training, upgrades, shops, prices,
and additional crafting remain visibly unavailable because they have no
authored executable backend.

Canonical item and Material icons are displayed from their Stable-ID
resources. Refuge lists constrain them to 48×48 and slot buttons to a 40-pixel
maximum width so source-art dimensions cannot expand the management layout.
Current `EquipmentDefinition` resources do not author an icon field, so
equipment instance rows use name, slot, condition, broken, and salvage text
rather than inventing presentation metadata.

## Controller and persistence boundary

`RefugeManagementController` is a narrow view-model/command adapter. UI code
does not edit snapshot dictionaries. Every command:

1. restores a deep-duplicated staged `RefugeOwnershipState`;
2. invokes its existing validated operation;
3. swaps the staged state into `RunState` only after success;
4. saves through the existing production Refuge save callback;
5. restores the original in-memory state if persistence fails.

The Save Envelope remains version 3. `refuge_snapshot` now contains
`prepared_item_bar_slots`, exactly six ordered plain dictionaries. New
campaigns initialize that field from the existing starting Item Bar. Valid v3
saves written before this field existed import their migrated campaign Item
Bar once at load; a direct/default legacy Refuge restore receives six empty
slots. Malformed explicit fields reject before existing ownership changes.

Run launch moves the configured Item Bar to `RunInventoryState` and clears the
Refuge copy. Voluntary return restores the surviving runtime Item Bar to the
Refuge; defeat restores six empty slots. Existing preparation, equipment,
Memento, Stash, Key Chain, and Material ownership rules are unchanged.

## Player equipment availability

The production equipment registry also contains enemy and fixture definitions.
`EquipmentDefinition.player_refuge_available` is therefore an explicit
presentation/ownership-choice rule, false by default. Only the six authored
starting heroine definitions are currently enabled. This does not create loot,
salvage outputs, or availability for enemy equipment, and it does not alter
combat behavior.

## Validation

Focused coverage is in `tests/test_refuge_management_ui.gd`. It covers scene
construction, safe legacy defaults, malformed rollback, order persistence,
save-failure rollback, inventory-domain transactions, authored equipment
filtering, exact repair-target retention/execution, compact icon presentation,
broken-condition/service data, and launch ownership transfer.

Manual Godot QA should still exercise all five tabs at the normal desktop
resolution, save/load after reordering and transfers, repair and salvage when
valid authored fixtures exist, voluntary return, defeat return, Continue, and
the unchanged combat/map/Event Room paths.
