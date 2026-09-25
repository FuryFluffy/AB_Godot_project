# Authored Equipment, Materials, Salvage, and Recipes — 2026-08-28

> **Milestone 11 update (2026-08-29):** the authored repair and salvage APIs
> documented here are now available through the production Refuge management
> UI. Enemy/fixture definitions remain hidden unless their separate
> `player_refuge_available` rule is explicitly authored. See
> `REFUGE_SERVICES_AND_INVENTORY_UI_2026-08-29.md`.

## Scope

Milestone 10 registers the current executable Layer 1–2 equipment set, four
manifest-backed Materials, deterministic Refuge salvage, and one non-UI repair
service. A later room-authoring pass activates four fixed, once-only Material
grants through the existing Material Pouch; it does not add crafting output or
change combat balance. Save Envelope v3 and the existing active-run safe points
remain unchanged.

The active run sources are deliberately one unit each:

- Wax Preparation Room → `mat_l01_red_wax`;
- Linen Sorting Room → `mat_l01_servant_cloth`;
- Polished Shackle Gallery → `mat_l02_chain_links`;
- Punishment Mechanism Room → `mat_l02_prison_iron`.

They use normal deterministic first-clear reward records. Surviving quantities
remain in the shared Material Pouch until voluntary return or defeat banks them
through the existing Refuge boundary.

## Authored catalogs

The Equipment catalog contains these 26 production Resources (the two example
swords remain test examples and are not registered):

- Weapons: `blood_nun_lash`, `chain_thrall_chain`,
  `corrupted_butler_tray`, `default_unarmed_grapple`,
  `hollow_servant_unarmed`, `iron_guard_gaoler_pole`, `jailer_crush`,
  `knife_footman_dagger`, `lysandra_sword`, `mira_dagger`,
  `prayer_rag_staff`, `red_wax_drip`, and `seraphine_staff`.
- Armor: `blood_nun_chain`, `chain_thrall_wrappings`,
  `corrupted_butler_cloth`, `hollow_wrappings`, `iron_guard_plate`,
  `jailer_architecture`, `knife_footman_leather`, `lysandra_chain`,
  `mira_leather`, `prayer_rag_cloth`, `red_wax_cloth`, and
  `seraphine_cloth`.
- Shield: `knife_footman_shield` in the existing Off Hand slot.

The Material catalog registers only the four Layer 1–2 material rows already
present in the 126-row Stable-ID manifest:

| Stable ID | Display name | Tier | Declared executable purpose |
| --- | --- | --- | --- |
| `mat_l01_red_wax` | Red Wax | Common | Equipment salvage |
| `mat_l01_servant_cloth` | Servant Cloth | Common | Equipment salvage and Refuge repair |
| `mat_l02_chain_links` | Chain Links | Common | Equipment salvage |
| `mat_l02_prison_iron` | Prison Iron | Common | Equipment salvage |

These four Resources use their matching
`res://assets/items/by_stable_id/<stable_id>.png` textures and are shared by
the Material catalog and the existing Item catalog. The Item catalog therefore
now contains 32 executable workbook-backed entries plus the isolated legacy
`quiet_cell_blanket`, for 33 total. The remaining 94 manifest rows remain inert.
Materials are passive domain data: they cannot enter or be used from the Item
Bar, backpacks, preparation inventories, Keys, Mementos, or Stash.

## Destructibility and salvage

Only four current definitions have direct, semantically supported mappings and
become salvageable:

| Equipment Stable ID | Rarity | Material Stable ID | Fixed yield |
| --- | --- | --- | ---: |
| `red_wax_drip` | Common | `mat_l01_red_wax` | 1 |
| `corrupted_butler_cloth` | Common | `mat_l01_servant_cloth` | 1 |
| `chain_thrall_chain` | Uncommon | `mat_l02_chain_links` | 2 |
| `iron_guard_gaoler_pole` | Rare | `mat_l02_prison_iron` | 3 |

The available references do not assign rarity or salvage mappings to the
current combat equipment. This milestone therefore makes the smallest
explicit authoring assumption needed to exercise the locked three-tier yield
contract: direct name/material matches supply the four mappings, with the
plain Wax Drip and Butler cloth as Common, the restraint chain as Uncommon,
and the gaoler pole as Rare. These values are isolated in the Equipment
Resources and can be reviewed without changing combat statistics or effects.

All other registered equipment remains non-destructible and has no invented
rarity or salvage mapping. Salvage stages and validates the complete current
Refuge snapshot, resolves exactly one Stash/loadout instance, clears its slot
when equipped, removes only that instance, and grants the fixed quantity to
`banked_materials`. Condition does not affect yield. Active-run-only, foreign,
duplicate, malformed, non-destructible, or unknown requests leave the original
state unchanged.

## Refuge repair service

The deliberately minimal authored service is
`refuge_repair_cloth_armor`. It consumes exactly one banked
`mat_l01_servant_cloth`, requires an owned Armor instance below maximum
condition, and restores exactly one condition. It reuses
`EquipmentInstance.repair_condition()` so repaired positive effects and broken
penalties retain the existing rules. The operation validates inputs and target
before committing either the Material debit or condition change.

The project references leave the wider equipment repair economy and craftable
outputs open. The one-for-one, one-condition service is a neutral executable
API proof, not a balance or narrative decision. No equipment-creation recipe,
shop price, Bloom cost, alternate ingredient, random yield, or UI was authored.

## Persistence and compatibility

No snapshot field was added. Salvage output and recipe spending use the
existing `refuge_snapshot.banked_materials`, while equipment removal/repair use
the existing loadout/Stash instance snapshots. Existing v3 documents with
empty banked Materials or pre-Milestone-10 equipment condition records remain
valid. Pre-v3 incompatibility, atomic primary writes, `.bak` recovery,
canonical item-ID migration, and active-run safe points are unchanged. Banked
Materials still have no withdrawal API and remain available only to Refuge
operations.
