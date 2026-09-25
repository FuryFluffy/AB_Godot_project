# Run Inventory State Domains

**Date:** 2026-08-26  
**Godot target:** 4.7  
**Milestone:** 3 — runtime carried-item state only

> **Milestone 11 update (2026-08-29):** the Refuge now persists and displays a
> separate six-slot pre-run Item Bar configuration and transfers it into this
> runtime model at launch. See
> `REFUGE_SERVICES_AND_INVENTORY_UI_2026-08-29.md`. Statements below that no
> inventory UI exists describe the earlier runtime-domain checkpoint.

## Ownership

`RunState` owns one `RunInventoryState`. Its snapshots contain only plain
serializable values: canonical item Stable IDs, positive quantities, ordered
slot indices, heroine IDs, Dictionaries, Arrays, and null Memento entries.
Item definitions remain catalog data and UI nodes remain presentation only.

The runtime domains are:

- one shared six-slot ordered combat Item Bar;
- one personal fifteen-slot ordered backpack for each of Lysandra, Mira, and
  Seraphine in the current fixed demo party setup;
- one shared Key Chain represented as Stable ID to positive quantity;
- one shared run-only Material Pouch represented the same way;
- one nullable Memento Stable ID per demo heroine.

Empty Item Bar and backpack slots are explicit dictionaries with their stable
slot index, an empty item ID, and zero quantity. Additions fill compatible
stacks before empty slots in ascending slot order. Removal also proceeds in
ascending slot order. Capacity and movement operations stage copies and commit
only after the complete operation validates.

## Domain eligibility

New carried-item operations accept catalog-backed canonical workbook Stable
IDs only. Active combat-usable items may enter the Item Bar. Active ordinary
items may enter a heroine backpack, but backpacks are not supplied to combat.
Keys, Materials, and Mementos can enter only their corresponding domains.
Story, Knowledge, unknown, legacy-alias, and inappropriate-category entries are
rejected.

The isolated development-only `quiet_cell_blanket` is not accepted by new run
inventory operations. Save Envelope v3 retains Milestone 1's narrow load
compatibility for an already-existing campaign snapshot containing that item;
this exception remains confined to the campaign-load boundary.

## Current integration

The established authored starting Item Bar loadout is initialized by
`RunInventoryState` and remains the only inventory supplied to combat. Existing
combat item presentation and use continue through `SixSlotInventoryState` as a
catalog-aware scene adapter.

Map and encounter Active-item rewards route through the shared Item Bar using
the authored `ItemDefinition.stack_limit`. Event-room pickups and dialogue
item rewards use the same domain router. Milestone 9 resolves executable
production rewards from explicit deterministic source Resources before this
routing step. The generated `shared_rusty_key` enters the Key Chain, and the
Wine Cellar lock checks and consumes that Key Chain entry rather than requiring
an Item Bar selection.

There are currently no implemented Material rewards, even though Milestone 10
registers four executable Materials for Refuge salvage/recipes. The Material
Pouch may therefore remain empty. Authored Mementos exist, but no current reward supplies
an authoritative heroine assignment, so no Memento is automatically equipped.
No owner is invented for exploration-only backpack or Memento rewards.

## Persistence boundary

Save Envelope v3 is unchanged. Later milestones populated its reserved Refuge
and active-run boundaries: current active-run snapshots carry the complete
`RunInventoryState`, while Refuge saves carry their separate persistent
ownership model. Milestone 9 additionally stores plain-data reward resolutions
inside the active-run snapshot; it does not create another inventory store.

No inventory UI, new Refuge ownership, salvage, crafting, or mid-node save
behavior is introduced by reward routing. Milestone 10's salvage/repair APIs
operate only on the separate Refuge ownership boundary.
