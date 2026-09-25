# Refuge Ownership and Run Resolution — 2026-08-26

> **Milestone 11 update (2026-08-29):** the ownership model documented here is
> now exposed by the production Refuge management UI. The Refuge snapshot also
> owns an explicit ordered six-slot `prepared_item_bar_slots` field. See
> `REFUGE_SERVICES_AND_INVENTORY_UI_2026-08-29.md`. Statements below that no UI
> exists describe the original Milestone 5 checkpoint.

## Scope

Milestone 5 activates the existing Save Envelope v3 `refuge_snapshot` for
persistent ownership data. It does not add inventory, Stash, loadout, party,
Materials, or crafting UI; active-run persistence remains explicitly null.

`RefugeOwnershipState` owns the persistent gameplay domains at the Bloom
Refuge. The existing `NarrativeState` remains authoritative for Story and Lore
facts, and `KnowledgeState` remains authoritative for Knowledge. Those systems
continue to persist under `campaign_snapshot`; they are not duplicated in the
Refuge record.

## Snapshot schema

The plain-Variant Refuge snapshot is:

```gdscript
{
    "selected_party_ids": ["lysandra", "mira", "seraphine"],
    "prepared_item_bar_slots": [
        {
            "slot_index": 0,
            "item_id": "<combat-usable Stable ID or empty>",
            "quantity": 0,
        },
        # Exactly 6 ordered slots.
    ],
    "heroine_records": {
        "<heroine_id>": {
            "heroine_id": "<heroine_id>",
            "preparation_slots": [
                {
                    "slot_index": 0,
                    "item_id": "<Stable ID or empty>",
                    "quantity": 0,
                },
                # Exactly 15 ordered slots.
            ],
            "equipment_loadout": {
                "heroine_id": "<heroine_id>",
                "instances": {
                    "<instance_id>": {
                        "instance_id": "<instance_id>",
                        "definition_id": "<equipment Stable ID>",
                        "current_condition": 0,
                    },
                },
                "slots": {
                    "main_hand": "<instance_id or empty>",
                    "off_hand": "<instance_id or empty>",
                    "armor": "<instance_id or empty>",
                },
            },
            "memento_id": "<item Stable ID or null>",
        },
    },
    "stash": {
        "item_stacks": [
            {
                "stack_index": 0,
                "item_id": "<ordinary item Stable ID>",
                "quantity": 1,
            },
        ],
        "equipment_instances": {
            "<instance_id>": {
                "instance_id": "<instance_id>",
                "definition_id": "<equipment Stable ID>",
                "current_condition": 0,
            },
        },
    },
    "key_chain": {"<key Stable ID>": 1},
    "banked_materials": {"<material Stable ID>": 1},
}
```

The current selected-party API accepts validated order changes among the three
recruited demo heroines without changing encounter composition. Its default is
Lysandra, Mira, Seraphine. The Stash is deterministic and unbounded because no
authored capacity exists. Item stacks still obey each definition's stack
and Stash ownership.

## Transfer boundaries

Starting a run moves the ordered six-slot Item Bar and each selected heroine's preparation slots, equipment
instances and assignments, and Memento into `RunInventoryState` and
`RunEquipmentState`. It also moves the shared Key Chain. Their deployed Refuge
records are emptied, while Stash and banked Materials remain untouched.

Voluntary return moves equipment and Mementos back with current condition and
banks every remaining run Material. Existing pre-milestone behavior retained
ordinary backpack contents across a voluntary return, so they are moved back
into the corresponding persistent preparation slots. The surviving Item Bar
becomes the next Refuge preparation configuration. No new consumable reward,
discard, or conversion rule was introduced.

Defeat returns equipment and Mementos with their current condition, including
zero-condition broken equipment. It clears the Item Bar and all heroine
backpacks, loses ordinary keys, and banks every remaining run Material. Key
persistence is definition metadata, never a name or rarity inference. The
currently registered Rusty Key, Ledger Seal, and Guiltless Key explicitly use
`RUN_ONLY`; no persistent key is currently authored.

Banked Materials have no withdrawal operation. They cannot be sent back to a
run, preparation inventory, Item Bar, backpack, Key Chain, Memento slot, or
Stash. This was the Milestone 5 boundary. Milestone 10 adds transactional
Refuge-only salvage and one repair service against this same banked
Material store; it does not add a second store or withdrawal path. See
`AUTHORED_EQUIPMENT_MATERIALS_SALVAGE_RECIPES_2026-08-28.md`.

## Save compatibility and validation

Production saves remain Save Envelope v3 and continue using the existing
atomic primary/backup implementation. Refuge-boundary saves keep
`active_run_snapshot == null`; active runs continue using their separate safe
points. New Refuge-boundary saves contain the populated schema above. Existing
v3 documents without `prepared_item_bar_slots` remain valid and import their
migrated campaign Item Bar when available; otherwise they receive six safe
empty slots. Pre-v3 saves remain incompatible and preserved.

Externally supplied Refuge dictionaries are deep-duplicated and completely
validated before ownership is committed. Validation covers heroine identities,
party order, 15-slot ordering, Stable IDs, categories, quantities, stack
limits, equipment definitions and assignments, unique instance ownership,
Memento ownership, Key Chain membership, and banked Material membership.

The isolated `quiet_cell_blanket` compatibility remains limited to the legacy
campaign Item Bar load boundary. It is not admitted to preparation, Stash,
Keys, Materials, or Mementos.

## Manual QA

1. Start a New Campaign and confirm the existing Lysandra, Mira, Seraphine
   composition and order.
2. Establish the Refuge, save, and inspect the slot JSON under `user://saves`;
   confirm `save_version` is 3, `refuge_snapshot` is populated, and
   `active_run_snapshot` is null.
3. With prepared items, Stash contents, a damaged or broken equipped item, a
   Memento, and banked Materials, save and load the slot; confirm all values and
   ownership assignments survive.
4. Begin a run and confirm preparation/loadout/Memento ownership moves into the
   runtime state while Stash and banked Materials do not move.
5. Return voluntarily and confirm Materials bank, equipment condition and
   Mementos return, and surviving backpack contents return to preparation.
6. Lose a later run and confirm Item Bar, backpacks, and the ordinary Rusty Key
   are lost while Stash, equipment condition (including broken state),
   Mementos, banked Materials, Story/Lore flags, and Knowledge survive.
7. Confirm Main Menu, save slots, combat, Grapple, Item Bar, Rusty Key lock, and
   Refuge screens retain their existing presentation. No new inventory,
   Stash, crafting, autosave, Continue/resume, or room UI should appear.
