# Abyssal Bloom — Event Rooms and Generated Content Checkpoint

**Date:** 2026-08-06  
**Project:** Abyssal Bloom + RAV (Godot 4.7)  
**Checkpoint scope:** Event-room lifecycle, room-state persistence, visible pickups, progression-key placement, persistent lore, scoped loot composition, and editor authoring support.

---

## 1. Current high-level design

Abyssal Bloom currently uses only two top-level room categories:

1. **Combat rooms** — Regular, Elite, and Boss encounters.
2. **Event rooms** — Illustrated point-and-click rooms containing visible overlay objects such as ordinary loot, progression items, lore, locks, exits, and future room events.

Items, lore, traps, and environmental interactions are not separate map-node types. They are content hosted inside Event rooms or, later, inside Combat rooms.

The exploration presentation model is:

```text
Generated node map
→ enter authored illustrated room
→ interact with visible overlay objects
→ preserve the correct state scope
→ return to map, revisit, or clear the room
```

The current six-slot Item Bar is still acting as the temporary run inventory. A full shared party inventory and equipment system remains deferred.

---

## 2. Reusable Event-room lifecycle

The reusable Event-room pipeline is operational.

### Main components

```text
EventRoomDefinition
EventRoomCatalogDefinition
EventRoomInstanceState
EventRoomOutcome
EventRoomScreen
```

### Current lifecycle

```text
Map node selected
→ MainController resolves room_definition_id through the catalog
→ EventRoomScreen is instantiated
→ EventRoomInstanceState is restored or created
→ room presentation scene is instantiated
→ pickups, locks, exits, lore, party state, and Item Bar are prepared
→ player exits or presses Back
→ EventRoomOutcome returns updated snapshots to RunState
```

### Persistent room data

`EventRoomInstanceState.local_state` currently stores room-local information such as:

```text
item_spawns
locks
later: room_events, containers, traps, choices
```

Room state is keyed by stable map-node IDs and stable authored IDs. Scene-node references and NodePaths are not stored in run snapshots.

---

## 3. Event-room exploration UI

`EventRoomScreen` currently contains reusable exploration UI:

```text
Party Strip
Item Bar
Hover/feedback label
Exploration command bar
```

### Party Strip

The Party Strip is populated from the run party snapshot using the battler catalog. Current HP, MP, Resolve, Corruption, and other state survive room exit and revisit.

### Item Bar

The six-slot Item Bar is available in Event rooms. Items can be collected and used on selected heroines. Warm Wine was the first fully tested Event-room item-use proof.

### Command bar

The current exploration command bar contains:

```text
Inventory — deferred
Party     — deferred
Back      — working
Log       — deferred
```

`Back` returns the party to the previous map node without clearing the Event room. It preserves:

```text
collected pickups
inventory
party state
room locks
room-local snapshots
```

The command-bar `%NodeName` references require the four buttons to be marked **Unique Name in Owner** in the scene.

---

## 4. Authored Event rooms

Two Event rooms are currently registered and generated in Layer 1.

### Wine Cellar of Warm Bottles

```text
Room ID: wine_cellar_warm_bottles
```

Implemented content:

- Wine Cellar background.
- Ordinary Warm Wine pickup anchors.
- Rear exit with closed/open visual states.
- Rusty lock interaction.
- Rusty Key selection and consumption.
- Persistent unlocked/open state.
- Room clear through the rear exit.
- Back without clearing.

### Butler’s Office

```text
Room ID: butlers_office
```

Implemented content:

- Butler’s Office background.
- Ordinary item anchors.
- Clearable rear exit.
- Back without clearing.
- Persistent `Butler’s Records` lore overlay.
- Compatible safe anchor for a generated Rusty Key.

Both room definitions are registered in:

```text
res://data/exploration/rooms/event_room_catalog.tres
```

Both rooms are placed once per current Layer 1 run, on different eligible nodes, with placement determined by the run seed.

---

## 5. Ordinary visible item pickups

The ordinary room-item pipeline is operational.

### Main components

```text
RoomItemPoolEntryDefinition
RoomItemPoolDefinition
RoomLootSourceDefinition
RoomLootProfileDefinition
RoomItemSpawnAnchor
WorldItemPickup
```

### Runtime flow

```text
RoomLootProfileDefinition
→ ordered loot sources
→ deterministic activation and draw count
→ weighted compatible entry selection
→ unused compatible RoomItemSpawnAnchor
→ WorldItemPickup
→ SixSlotInventoryState
→ collected state stored in item_spawns
```

### Pickup behavior

`WorldItemPickup` provides:

- visible room overlay sprite;
- hover highlight;
- hover name/feedback;
- click-to-collect;
- transactional inventory insertion;
- removal only after inventory insertion succeeds;
- collected persistence through Back and revisit.

Current `Sprite2D` placement uses the sprite centre at the anchor centre. Current authored anchors compensate for that convention.

---

## 6. Scoped ordinary-loot composition — Checkpoint B

Event rooms no longer rely on one isolated item pool. Loot is composed from multiple reusable scopes.

### Current hierarchy

```text
room-specific pool
+ layer-common pool
+ future cross-layer/castle-common pool
+ future global pool
+ separately generated progression items
```

### Data structure

```text
RoomLootProfileDefinition
└── Array[RoomLootSourceDefinition]
    ├── source_id
    ├── priority
    ├── pool
    ├── minimum_draws
    ├── maximum_draws
    ├── activation_chance
    └── allow_duplicate_entries
```

Sources are resolved by:

1. `priority`;
2. stable `source_id` order.

Each source gets an independent deterministic random stream. Higher-priority sources claim compatible anchors before broader common sources.

### Current scoped pools

#### Wine Cellar-specific

```text
Warm Wine Flask
```

Warm Wine can appear only in the Wine Cellar-specific source.

#### Butler’s Office-specific

```text
Ledger Seal
```

Ledger Seal can appear only in the Butler’s Office-specific source.

#### Layer 1 common

```text
Servant’s Tonic
Smelling Salts
```

The same Layer 1 common source can be referenced by any Layer 1 Event-room profile that should allow those items.

### Current expected composition

#### Wine Cellar

```text
1 Warm Wine Flask
+ chance of 1 Layer 1 common item
+ possible generated Rusty Key
```

#### Butler’s Office

```text
1 Ledger Seal
+ chance of 1 Layer 1 common item
+ persistent Butler’s Records when undiscovered
+ possible generated Rusty Key
```

### Duplicate handling

When `allow_duplicate_entries` is disabled, the same pool entry cannot be drawn twice by one source. A temporary two-draw test confirmed that the common source selects one Servant’s Tonic and one Smelling Salts rather than duplicates, provided enough compatible anchors exist.

---

## 7. Generated progression-item placement — Checkpoint A

The Rusty Key is no longer ordinary room loot and is no longer hardcoded inside `RunState`.

### Main components

```text
GeneratedRoomItemHostCandidate
GeneratedRoomItemPlacementRule
GeneratedRoomItemPlacementResult
GeneratedRoomItemPlacementResolver
StableSeedMixer
```

### Host-candidate access policies

```text
NORMALLY_REACHABLE
REACHABLE_WITHOUT_BLOCKING_ROOM
```

Current Rusty Key candidates:

- **Wine Cellar** — normally reachable because the key anchor is on the accessible side of its internal lock.
- **Butler’s Office** — eligible only if the office can be reached without traversing the Wine Cellar node.

### Resolver behavior

The resolver:

- takes only a graph, placement rules, and a run seed;
- contains no scene-node dependency;
- contains no Layer 1 room IDs internally;
- finds every graph node matching candidate room definitions;
- evaluates reachability from the start node;
- excludes configured blocking-room nodes;
- sorts hosts by stable node ID;
- gives each assignment an independent deterministic RNG stream;
- accumulates multiple validation errors in one pass;
- returns no partial requests when any rule fails.

### Stable seed mixing

The project now owns a stable FNV-1a-based seed mixer. Random streams are namespaced, for example:

```text
generated_room_item|run_seed|assignment_id
room_loot_source|room_generation_seed|source_id
```

Adding or reordering unrelated placement rules does not relocate an existing assignment.

### RunState boundary

`RunState.initialize()` now receives generated placement rules and stores only the resolver output:

```text
generated_room_item_requests
```

`RunState` no longer contains hardcoded references to:

```text
wine_cellar_warm_bottles
butlers_office
layer_1_rusty_key_01
```

### Tested placement examples

Manual seed tests confirmed:

- Wine Cellar and Office may appear on the same branch or different branches.
- The Wine Cellar may remain the key host when it blocks the Office.
- The Office may host the key when independently reachable.
- Both rooms may appear close to the boss without producing a soft lock.
- Repeating the same seed reproduces placement and contents.

Tested seeds included:

```text
27072026
111
222
333
56489751432
```

---

## 8. Rusty Key and lock interaction

The Rusty Key remains a normal item resource rather than a special keyring entry.

### Current interaction

```text
click locked door with no selected item
→ lock description

select wrong Item Bar item and click lock
→ explanatory message
→ item is not consumed

select Rusty Key and click lock
→ key is consumed
→ lock state is persisted
→ door visual changes
→ exit becomes usable
```

The key is assigned at run generation, while physical placement and collection use the normal room pickup pipeline.

This separates:

```text
progression safety and host selection
from
room presentation and pickup interaction
```

---

## 9. Persistent lore collectibles

`Butler’s Records` is the first persistent Knowledge collectible.

### Main components

```text
LoreEntryDefinition
LoreCatalogDefinition
KnowledgeState
WorldLorePickup
```

### Behavior

```text
visible paper-bundle overlay
→ hover like a pickup
→ click to collect
→ does not enter Item Bar
→ knowledge ID is stored persistently
→ overlay disappears
→ does not spawn in later runs
```

The first entry is:

```text
Lore ID: butler_records
Title: Butler’s Records
```

A Journal/Knowledge UI is deliberately deferred to the save-development cycle.

### Web Editor testing note

The correct long-term save path is:

```gdscript
user://knowledge_state.json
```

During Web Editor testing, a temporary `res://save_test/...` path was used. Browser/project reload currently clears the temporary state, which is useful for repeated testing, but it is not a production save solution and does not appear as a normal imported project file.

---

## 10. Editor-visible item-anchor previews

`RoomItemSpawnAnchor` now supports editor-time previews through a tool script and a preview child node.

### Current authoring model

```text
RoomItemPoolEntryDefinition.world_visual_scale
×
RoomItemSpawnAnchor.item_visual_scale
=
final runtime sprite scale
```

### Preview workflow

```text
select RoomItemSpawnAnchor
→ assign Preview Entry
→ view representative sprite directly in the room scene
→ move anchor
→ adjust anchor scale and rotation
→ inspect pickup bounds
```

The preview entry affects editor visualization only. It does not change the runtime loot roll.

### Current art-pipeline decision

Per-entry sprite offsets were considered but deliberately deferred. Future hand-authored assets will follow a consistent template:

- similar canvas framing within an item category;
- consistent transparent padding;
- predictable object occupation of the canvas;
- anchor placement authored with the known centre-to-centre convention.

`world_visual_scale` remains available as an exceptional correction value, but the preferred workflow is disciplined asset normalization.

---

## 11. Current state scopes

The project now distinguishes four content scopes clearly.

### Ordinary item

```text
Scope: current run
Result: Item Bar / later party inventory
Persistence: room snapshot + run inventory
Example: Warm Wine Flask, Ledger Seal, Servant’s Tonic
```

### Generated progression item

```text
Scope: current run, with reachability rules
Result: normal inventory item
Persistence: resolver assignment + room snapshot + run inventory
Example: Rusty Key
```

### Lore collectible

```text
Scope: persistent profile/save knowledge
Result: Knowledge unlock
Persistence: across runs
Example: Butler’s Records
```

### Future room event

```text
Scope: room state and/or current run
Result: message, roll, party effect, reward, trap, encounter, etc.
Persistence: resolved event state in room snapshot
```

---

## 12. Known temporary limitations

1. The six-slot Item Bar is still the temporary complete inventory.
2. No full inventory/equipment screen exists yet.
3. Inventory, Party, and Log exploration buttons remain deferred except for Back.
4. Persistent Knowledge has no Journal UI yet.
5. Only two authored Event rooms currently exist.
6. Room-event anchors and event pools are not implemented yet.
7. Combat-room environmental interactions are not implemented yet.
8. Save slots, run resume, migration, and production `user://` persistence remain deferred.
9. Replacing custom Resource scripts in the Web Editor can clear serialized Inspector values. After `EventRoomDefinition` changed, both room resources temporarily lost Identity and Presentation values and had to be restored manually.
10. Current upright item sprites use centre-to-centre anchor placement; asset-template discipline is being used instead of per-entry pivot offsets for now.

---

## 13. Next planned milestone: scoped room-event spawning

The next system should mirror the ordinary-loot composition architecture while resolving events rather than inventory pickups.

### Planned parallel structure

```text
RoomEventPoolEntryDefinition
RoomEventPoolDefinition
RoomEventSourceDefinition
RoomEventProfileDefinition
RoomEventSpawnAnchor
WorldRoomEvent
```

A room definition will eventually contain both:

```gdscript
loot_profile: RoomLootProfileDefinition
event_profile: RoomEventProfileDefinition
```

### Planned event scopes

#### Butler’s Office-specific event

**Tarnished Service Bell**

```text
Scope: Butler’s Office only
Interaction: ring once
Initial outcome: message-only proof
Persistence: current room/run; remains resolved after Back/revisit
```

#### Layer 1 common event

**Opened Red-Wax Vial**

```text
Scope: Layer 1 Event rooms with compatible event anchors
Target: selected heroine
Possible outcomes:
- heal 3 HP
- gain 10 Corruption
- gain 10 Corruption and lose 10 Resolve
```

#### Global cross-layer event

**Bone Dice Cup**

```text
Scope: global event source across layers
Dice count: current layer number
Die: d10
Explosion rule: existing exploding-d10 mechanism
Reward: gain Bloom equal to the total roll
```

Examples:

```text
Layer 1  → 1d10 exploding
Layer 5  → 5d10 exploding
Layer 10 → 10d10 exploding
```

The roll should use a deterministic seed derived from stable run, room, and event IDs. The resolved result must be stored so re-entering cannot reroll it.

### Required next assets

```text
service_bell.png
opened_red_wax_vial.png
bone_dice_cup.png
```

Each asset should follow the current overlay template and be authored against an appropriate room background before transparent extraction.

---

## 14. Recommended immediate sequence

```text
1. Generate the three room-event overlay assets.
2. Add RoomEventSpawnAnchor with editor preview support.
3. Add room-specific, layer-common, and global event pools/sources/profiles.
4. Add deterministic event assignment and persistent room-event state.
5. Prove Service Bell message-only resolution.
6. Add selected-heroine outcome composition for the Red-Wax Vial.
7. Reuse the existing exploding-d10 resolver for the Bone Dice Cup.
8. Add traps, hidden rewards, choices, and encounter-triggering events afterward.
```

---

## 15. Stable checkpoint statement

At this checkpoint, the project has a functioning data-driven foundation for:

```text
seeded map placement
→ multiple authored Event rooms
→ room-specific and shared loot scopes
→ deterministic ordinary pickups
→ soft-lock-safe generated progression items
→ persistent room locks and room state
→ persistent lore knowledge
→ editor-visible item-anchor authoring
```

The next development cycle extends the same principles to visible, deterministically spawned room events.
