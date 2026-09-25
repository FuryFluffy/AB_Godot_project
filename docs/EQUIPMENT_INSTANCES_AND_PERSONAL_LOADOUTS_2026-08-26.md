# Equipment Instances and Personal Loadouts — 2026-08-26

## Scope

Milestone 4 establishes the runtime equipment foundation without adding an
equipment screen, Refuge preparation, active-run persistence, procedural
equipment, crafting, or salvage behavior. Existing authored combat equipment
and condition rules remain the production behavior.

The three demo heroines each receive an independent personal loadout with
explicit `Main Hand`, `Off Hand`, and `Armor` assignments. The Memento slot
continues to be owned by `RunInventoryState`; `RunEquipmentState` exposes it as
part of the heroine's combined runtime loadout without creating a second
Memento store. Shields are Off Hand equipment rather than a separate slot.

## Authored definitions

`EquipmentDefinition` is the common Resource contract. Every authored
definition declares:

- a stable `equipment_id`;
- one or more explicit compatible slots;
- a positive maximum condition;
- whether it is eligible for future destruction/salvage;
- a `salvage_material_id` when, and only when, it is destructible;
- stable IDs for any newly authored positive or negative effects.

`WeaponDefinition`, `ArmorDefinition`, and `ShieldDefinition` extend that
contract while preserving their existing combat fields and validation. The
This was the Milestone 4 boundary. Milestone 10 subsequently registers the 26
current production definitions and enables only four direct Layer 1–2 Material
mappings. All other equipment remains `destructible = false`; see
`AUTHORED_EQUIPMENT_MATERIALS_SALVAGE_RECIPES_2026-08-28.md` for the exact
mappings, rarities, and fixed yields.

## Runtime ownership and condition

`EquipmentInstance` owns instance identity, its definition identity, and
current condition. Instance snapshots contain only plain Variant data:

```gdscript
{
    "instance_id": "lysandra:main_hand:lysandra_sword:001",
    "definition_id": "lysandra_sword",
    "current_condition": 5,
}
```

The initial instance IDs are deterministic and scoped by heroine, slot, and
definition. This makes identical authored definitions usable by multiple
owners without sharing mutable condition.

`PersonalEquipmentLoadoutState` owns one heroine's instances and the explicit
Main Hand, Off Hand, and Armor assignments. It rejects unknown instances,
incompatible slots, and assigning one instance to more than one slot. Invalid
restoration or assignment is transactional and leaves the current assignment
unchanged.

`RunEquipmentState` owns the personal loadouts for the active demo heroines.
It is initialized from the existing battler catalogue and authored default
loadouts. `BattlerState`, `WeaponState`, `ArmorState`, and `ShieldState` adapt
the shared equipment instances into the established combat interfaces, so
combat, repairs, damage, encounter transitions, and the existing party
condition snapshots continue using one condition value per equipped instance.

## Broken behavior

At zero condition an instance is broken. Authored positive effect IDs are
suppressed while authored negative effect IDs remain effective. The existing
production combat rules retain the same contract:

- a broken or absent Main Hand falls back to the established unarmed action;
- positive armor dodge modifiers stop applying when armor is broken;
- negative armor dodge modifiers continue applying;
- positive shield parry modifiers stop applying when the shield is broken;
- negative shield dodge modifiers continue applying.

Repairing condition above zero restores positive effects through the same
shared instance.

## Persistence boundary

Save Envelope v3 is unchanged. `active_run_snapshot` remains `null`, so runtime
equipment instances and personal assignments are not yet written to production
saves. The plain equipment snapshot APIs exist as a validated future boundary;
they do not activate run autosaves, Continue behavior, Refuge loadouts, or a
parallel save store.

## Manual QA

1. Start a New Campaign and enter a battle with Lysandra, Mira, and Seraphine.
2. Confirm each heroine still has her authored attack and existing armor
   behavior, and that item use and Grapple are unchanged.
3. Use an existing condition-damage event on a heroine's equipped weapon and
   confirm its condition carries into the next battle.
4. Break the Main Hand and confirm the heroine uses the established unarmed
   fallback rather than the broken weapon action.
5. Repair that equipment with an existing repair interaction and confirm its
   authored attack becomes available again.
6. Return to the main menu and confirm save-slot listing and loading remain
   unchanged; active-run equipment is intentionally not resumable yet.
