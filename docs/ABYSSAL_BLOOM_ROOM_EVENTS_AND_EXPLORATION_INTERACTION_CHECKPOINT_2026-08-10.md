# Abyssal Bloom — Room Events and Exploration Interaction Checkpoint

**Date:** 2026-08-10  
**Project:** Abyssal Bloom + RAV (Godot 4.7)  
**Delta from previous summary:** `ABYSSAL_BLOOM_EVENT_ROOMS_GENERATED_CONTENT_CHECKPOINT_2026-08-06.md`  
**Verified code baseline used for this summary:** `preload_2026-08-07_17-48-37.zip`

---

## 1. Scope of this checkpoint

The previous 2026-08-06 summary ended with a functioning Event-room lifecycle, ordinary scoped loot, generated Rusty Key placement, persistent lore, and editor-visible item anchors. Room events were still only planned.

Since then, the project gained a complete first vertical slice for **data-driven room events**, including:

```text
room-specific event sources
+ layer-wide event sources
+ global/cross-layer event sources
→ deterministic event assignment
→ authored RoomEventSpawnAnchor placement
→ visible WorldRoomEvent overlays
→ persistent resolved state
→ weighted outcomes
→ selected-heroine effects
→ LayerNumber-scaled exploding d10 effects
→ Bloom transfer back into RunState
```

A third Layer 1 Event room, **Wax Preparation Room**, was also registered and added to map generation.

Finally, the repeated raw mouse-input implementations used by exploration objects were consolidated under a reusable `ExplorationInteractable` base class.

This document records the confirmed state through the verified `17:48:37` checkpoint. A later proposal to make `EventRoomScreen` consume the generic hover contract directly is listed as **next work**, not as confirmed implementation.

---

## 2. Generated progression-item placement follow-up

The Rusty Key generated-placement system from the previous checkpoint was exercised further with real node graphs.

### Candidate semantics were confirmed

The current Layer 1 Rusty Key rule uses two host candidates:

```text
Wine Cellar
AccessPolicy: NORMALLY_REACHABLE

Butler's Office
AccessPolicy: REACHABLE_WITHOUT_BLOCKING_ROOM
Blocking room definition: wine_cellar_warm_bottles
```

The Butler's Office policy does **not** make it lower priority than the Wine Cellar. It only adds an extra safety test:

```text
Can the Butler's Office node be reached from Start
without traversing any Wine Cellar node?
```

If yes, the Office is a fully valid host alongside the Cellar.

### Important manual seed examples

The normal test seed and the large test seed demonstrated both valid outcomes:

```text
27072026
→ Wine Cellar and Butler's Office can both be safe
→ deterministic selection chose Wine Cellar

56489751432
→ Wine Cellar and Butler's Office appear on independent late branches
→ Office remains reachable without Cellar
→ deterministic selection chose Butler's Office
```

This confirms the intended distinction between:

```text
eligibility
and
seeded selection among eligible nodes
```

There is currently no authored weighting such as "prefer Cellar, fallback to Office." Eligible matching nodes are simply resolved deterministically from the rule-specific random stream.

### Warning path

The placement-result type includes both:

```text
errors
warnings
```

and the resolver was extended to surface rejected-candidate notes even when another candidate succeeds. This is intended to make authoring diagnostics visible without turning a safe fallback into a fatal generation error.

Automated headless regression execution remains awkward in the Web Editor, so this behavior has primarily been checked manually during browser-based development.

---

## 3. Room-event data model — C1

A new family of data Resources was added under:

```text
res://scripts/exploration/events/
```

### `RoomEventEffectDefinition`

Defines composable mechanical effects rather than hardcoding all mechanics into each room event.

Current effect kinds:

```text
HEAL_HP
CHANGE_RESOLVE
CHANGE_CORRUPTION
ROLL_BLOOM_D10_PER_LAYER
```

The resource also determines whether an effect requires a heroine target and validates authored amounts.

### `RoomEventOutcomeDefinition`

Represents one possible outcome of an event.

Current authored fields include:

```text
outcome_id
weight
message
effects[]
```

One outcome may contain multiple effects. This is used by Red Wax for the combined Corruption + Resolve-loss result.

### `RoomEventDefinition`

Defines the actual interactable event.

Important fields:

```text
event_id
display_name
hover_prompt
target_rule
resolve_once
remove_on_resolve
outcomes[]
```

Current target rules:

```text
NONE
SELECTED_HEROINE
```

Validation rejects heroine-affecting effects when the event is not authored to require a selected heroine. This caught an early Red Wax authoring mistake and required:

```text
Target Rule = Selected Heroine
```

### `RoomEventPoolEntryDefinition`

Separates the event's mechanics from its room-world presentation.

It currently holds:

```text
entry_id
room_event
world_texture
world_visual_scale
required_anchor_tag
weight
```

This lets one event definition remain mechanical/data-driven while its visible overlay participates in room-anchor composition.

---

## 4. Room-event anchor authoring and editor preview

A reusable room-event anchor system now parallels the ordinary item-anchor system.

### Main components

```text
RoomEventSpawnAnchor
RoomEventAnchorEditorPreview
room_event_spawn_anchor.tscn
```

### Anchor data

Each `RoomEventSpawnAnchor` contains stable authoring information such as:

```text
anchor_id
anchor_tags
event_visual_scale
event_visual_rotation_degrees
interaction_size
event_z_index
```

It also supports an editor-only `preview_entry`, allowing the actual event sprite to be positioned directly against the room illustration.

### Authoring model

```text
RoomEventPoolEntryDefinition.world_visual_scale
×
RoomEventSpawnAnchor.event_visual_scale
=
runtime event visual scale
```

The first proof was the Tarnished Service Bell placed directly on the Butler's Office desk.

The Web Editor still occasionally shows stale configuration-warning icons after exported values change; this is considered an editor quirk rather than runtime behavior.

---

## 5. Scoped room-event composition — C2

The room-event system now mirrors the already-proven ordinary-loot source/profile architecture.

### New Resources

```text
RoomEventPoolDefinition
RoomEventSourceDefinition
RoomEventProfileDefinition
```

### Composition hierarchy

```text
RoomEventProfileDefinition
└── ordered RoomEventSourceDefinition[]
    ├── source_id
    ├── priority
    ├── pool
    ├── minimum_draws
    ├── maximum_draws
    ├── activation_chance
    └── allow_duplicate_entries
```

Sources are resolved in deterministic order:

```text
priority
→ stable source_id
```

Each source receives an independent random stream using the shared `StableSeedMixer` namespace:

```text
room_event_source
```

Higher-priority sources consume compatible event anchors before broader sources.

### Current source priorities

```text
Butler's Office-specific: 0
Layer 1 common:           100
Global:                   200
```

### Current activation chances in the verified checkpoint

```text
Butler's Office-specific event source: guaranteed/default 1.0
Layer 1 common event source:           0.45
Global event source:                   0.15
```

The proof phase initially used 100% common/global chances, then these were lowered to more realistic values after the full pipeline was confirmed.

---

## 6. Persistent runtime event assignment

`EventRoomScreen` now prepares room events in addition to ordinary items.

### Runtime flow

```text
EventRoomDefinition.event_profile
→ gather RoomEventSpawnAnchors
→ restore existing local_state["event_spawns"]
   or deterministically generate assignments
→ instantiate WorldRoomEvent overlays
→ resolve interaction
→ write resolved outcome back into event_spawns
```

### Stored room-local event state

Each event assignment contains stable information including:

```text
spawn_id
anchor_id
source_id
entry_id
event_id
resolved
```

After resolution, additional result information is stored, including the chosen outcome and target where applicable.

This ensures:

```text
Back → revisit
or
leave → revisit
```

cannot reroll or reactivate an already resolved event.

The event assignment itself is stored inside:

```text
EventRoomInstanceState.local_state["event_spawns"]
```

so event persistence follows the existing Event-room snapshot model rather than introducing a separate state subsystem.

---

## 7. `WorldRoomEvent`

Visible runtime events use:

```text
res://scripts/exploration/events/world_room_event.gd
res://scenes/exploration/components/world_room_event.tscn
```

A `WorldRoomEvent` currently supports:

```text
visible overlay sprite
collision area
hover highlight
activation request
resolved/unresolved state
remove-on-resolve behavior
resolved-but-visible dim state
```

Examples:

```text
Red Wax Vial
→ remove_on_resolve = true
→ disappears when resolved

Bone Dice Cup
→ remove_on_resolve = true
→ disappears when resolved

Tarnished Service Bell
→ remove_on_resolve = false
→ remains visible but dim/inactive
```

---

## 8. Third authored Event room — Wax Preparation Room

Layer 1 now has three generated authored Event rooms:

```text
wine_cellar_warm_bottles
butlers_office
wax_prep_room
```

The new room resource is:

```text
res://data/exploration/rooms/layer1/wax_prep_room.tres
```

with:

```text
Room ID: wax_prep_room
Display Name: Wax Preparation Room
Presentation: res://scenes/exploration/rooms/layer1/wax_prep_room.tscn
Event Profile: wax_prep_room_event_profile.tres
```

It is registered in the Event-room catalog and included in `LAYER_1_EVENT_ROOM_POOL` together with the Wine Cellar and Butler's Office.

The Wax Preparation Room currently serves primarily as a second/third host for shared room events and as a visual proof that the event system is not tied to one specific room scene.

---

## 9. Current room-event content

Three events now prove the three intended source scopes.

### 9.1 Tarnished Service Bell — room-specific

**Scope:** Butler's Office only  
**Stable event ID:** `tarnished_service_bell`

Current behavior:

```text
click bell
→ resolve once
→ display message:
   "The bell answers with a distant chime from somewhere inside the walls."
→ bell remains visible
→ bell becomes dim and non-interactable
→ revisit preserves resolved state
→ new run restores an unresolved bell
```

The Bell currently has no mechanical party effect. It is the clean message-only event proof.

---

### 9.2 Red Wax Vial — Layer 1 common

**Scope:** Layer 1 Event rooms with compatible event anchors  
**Stable event ID:** `red_wax_vial`  
**Target rule:** `SELECTED_HEROINE`

Current weighted outcomes are equally weighted:

```text
restorative_warmth
→ heal 3 HP

corrupting_residue
→ +10 Corruption

devouring_residue
→ +10 Corruption
→ -10 Resolve
```

The selected heroine's `BattlerState` is modified immediately and the Party Strip refreshes in the Event room.

After resolution:

```text
vial disappears
→ room snapshot remembers resolution
→ party snapshot carries stat changes back to RunState
```

During testing, all three visible Red Wax Vials in one run happened to produce:

```text
+10 Corruption
-10 Resolve
```

This was noted but not treated as a confirmed RNG defect. Because there are only three equally weighted outcomes, matching results are possible; further investigation is only warranted if multiple unrelated seeds repeatedly show suspicious synchronization.

---

### 9.3 Bone Dice Cup — global/cross-layer

**Scope:** global event source  
**Stable event ID:** `bone_dice_cup`

The event uses the effect kind:

```text
ROLL_BLOOM_D10_PER_LAYER
amount = 1
```

The dice count is therefore:

```text
current layer number × 1d10
```

Examples:

```text
Layer 1  → 1d10
Layer 5  → 5d10
Layer 10 → 10d10
```

The event reuses the existing recursive exploding-natural-10 dice behavior. Bloom gained equals the sum of all base and explosion roll values.

Example:

```text
Base roll: 10
Explosion: 10
Explosion: 1
Total: 21 Bloom
```

The current textual presentation still reports base rolls and explosion rolls separately. A cleaner future presentation such as:

```text
Bloom Roll: 10! → 10! → 1
Total: 21 Bloom
```

would be easier to read, but the mechanical result is functioning.

---

## 10. Explicit layer number support

`LayerMapGraph` now contains:

```gdscript
layer_id: StringName
layer_number: int
```

Layer 1 generation explicitly sets:

```text
layer_id = layer_1
layer_number = 1
```

`MainController` passes `run_state.graph.layer_number` into `EventRoomScreen.prepare_room()`.

This is what lets a single global Bone Dice Cup definition scale automatically on future layers without Layer-specific copies of the event resource.

---

## 11. Event-room Bloom handoff

The Event-room outcome pipeline was extended with:

```text
EventRoomOutcome.bloom_delta
```

Inside a room, Bone Dice results accumulate in:

```text
EventRoomScreen.pending_bloom_delta
```

When the player leaves through either Back or normal room completion:

```text
EventRoomScreen
→ EventRoomOutcome.bloom_delta
→ RunState.apply_event_room_outcome()
→ RunState.bloom += bloom_delta
```

This keeps Bloom transfer within the same transactional handoff already used for:

```text
inventory snapshot
party snapshot
room-local snapshot
Back/clear node state
```

### C3 regression and fix

An early typo in `RunState.apply_event_room_outcome()` used:

```text
bloon_delta
```

instead of:

```text
bloom_delta
```

Because this occurred before both Bloom application and node finalization, it caused two apparently unrelated symptoms at once:

```text
Bone Dice reported gained Bloom but map Bloom did not increase

Back / room completion returned to map but travel state remained blocked
```

Correcting the typo restored both systems.

A second dormant typo in an event-effect error dictionary used a misspelled `succeeded` key; this path was identified for cleanup as well.

After correction, manual testing confirmed:

```text
Back from unresolved Event room works
normal Event-room completion works
map travel unlocks correctly
Bloom increases on map
Bone Dice produces varying deterministic rolls
```

---

## 12. Deterministic event RNG

Room-event randomness is intentionally divided into independent namespaces.

### Source activation and entry selection

```text
StableSeedMixer(
    room generation seed,
    "room_event_source",
    source_id
)
```

### Weighted outcome selection

The event outcome uses a stable identifier based on:

```text
spawn_id + event_id
```

under the namespace:

```text
room_event_outcome
```

### Bone Dice roll

The actual Bloom dice roll receives its own stable namespace:

```text
room_event_bloom_dice
```

using the event spawn, outcome, and effect identity.

The intended properties are:

```text
same run/room/event instance
→ same outcome and roll

adding unrelated events
→ should not perturb existing event results

re-entering a resolved event
→ does not reroll because result state is already stored
```

This follows the same project-owned deterministic-randomness discipline now used by generated progression items and ordinary loot sources.

---

## 13. Event assets added

The new visible event overlays are now part of the project:

```text
res://assets/exploration/layer1/butler_office/bell.png
res://assets/exploration/layer1/wax_prep_room/red_wax.png
res://assets/exploration/dice_cup.png
```

They are authored as separate room-overlay sprites rather than baked into the room backgrounds, preserving the point-and-click room model and editor anchor placement workflow.

---

## 14. Shared exploration interaction foundation

After the room-event vertical slice was stable, exploration input duplication was refactored.

A new base class now exists:

```text
res://scripts/exploration/interactions/exploration_interactable.gd
```

### `ExplorationInteractable`

The common base owns low-level interaction behavior:

```text
mouse enter / exit
left-click activation
interaction enabled/disabled state
input_pickable control
hover visual application
programmatic request_interaction()
generic interaction signals
```

It exposes overridable contract methods such as:

```text
get_interaction_id()
get_interaction_display_name()
get_interaction_prompt()
_get_hover_visual()
_get_hover_modulate()
_get_idle_modulate()
_interaction_hover_state_changed()
_interaction_requested()
```

### Migrated exploration objects

The following now inherit `ExplorationInteractable`:

```text
WorldItemPickup
WorldLorePickup
WorldRoomEvent
RoomExitHotspot
RoomLockHotspot
```

Their existing domain-specific signals remain intact.

For example:

```text
WorldItemPickup
→ common base handles mouse
→ subclass emits pickup_requested(world_item_id)

WorldRoomEvent
→ common base handles mouse
→ subclass emits activation_requested(spawn_id)

RoomLockHotspot
→ common base handles mouse
→ subclass emits interaction_requested(lock_id)
```

This means the refactor changed the input boundary without forcing the gameplay controller to understand one generic "do everything" signal.

### Controller/keyboard benefit

The new base also enables future non-mouse input to call:

```text
focused_interactable.request_interaction()
```

rather than fabricating mouse events.

That provides a clean base for later keyboard/controller focus and accessibility work.

---

## 15. Behavior-preserving interaction refactor verification

The shared-interaction refactor was manually tested and confirmed not to break the existing Event-room interactions.

Verified behaviors include:

```text
ordinary item hover and pickup
Butler's Records hover and persistent collection
Service Bell hover, one-time resolution, dim resolved state
Red Wax heroine targeting and disappearance
Bone Dice activation and disappearance
Wine Cellar locked-door interaction
wrong-item lock feedback
Rusty Key consumption and unlock
open-door exit behavior
Back from uncleared Event room
normal room completion
```

This is the first point where the project has enough concrete interaction types to justify the abstraction without speculating about future object behavior.

---

## 16. Current Layer 1 Event-room composition

The current generated Event-room set is:

```text
Wine Cellar
Butler's Office
Wax Preparation Room
```

Their content composition is now conceptually:

### Wine Cellar

```text
room-specific ordinary loot
+ Layer 1 common ordinary loot chance
+ possible generated Rusty Key
+ Layer 1 common event chance (Red Wax)
+ global event chance (Bone Dice)
+ internal Rusty lock / exit
```

### Butler's Office

```text
room-specific ordinary loot
+ Layer 1 common ordinary loot chance
+ possible generated Rusty Key
+ persistent Butler's Records lore
+ guaranteed room-specific Bell event
+ Layer 1 common event chance (Red Wax)
+ global event chance (Bone Dice)
```

### Wax Preparation Room

```text
Layer 1 common event chance (Red Wax)
+ global event chance (Bone Dice)
```

The Wax Preparation Room currently has no dedicated ordinary-loot profile in the verified resource, making it a useful clean room-event proof rather than another combined-content room.

---

## 17. Current exploration state scopes

The project now has five clearly distinct exploration-content scopes.

### Ordinary item

```text
Scope: current run
Result: Item Bar / future party inventory
Persistence: room snapshot + run inventory
```

### Generated progression item

```text
Scope: current run with reachability safety rules
Result: ordinary inventory item after pickup
Persistence: generated assignment + room snapshot + run inventory
```

### Lore collectible

```text
Scope: persistent KnowledgeState
Result: profile/save knowledge unlock
Persistence: across runs
```

### Room event

```text
Scope: room-local resolution + current-run mechanical effects
Result: message / heroine effect / Bloom / future event outcomes
Persistence: event_spawns in EventRoomInstanceState
```

### Shared exploration interaction

```text
Scope: presentation/input contract only
Result: hover, activation, enabled state
Persistence: none
Gameplay meaning remains in each concrete subclass/controller path
```

This separation is important: the new `ExplorationInteractable` does not become a new gameplay-state owner.

---

## 18. Known temporary limitations and observations

1. The six-slot Item Bar is still the temporary complete run inventory.
2. Inventory, Party, and Log exploration command-bar functions remain deferred except for Back.
3. Persistent Knowledge still has no Journal UI.
4. Production save slots / run resume / migration / `user://` persistence remain deferred.
5. Event outcomes currently use a small fixed set of `RoomEventEffectDefinition.Kind` values. More complex room-event mechanics may later justify reuse of a broader shared effect framework.
6. Repeatable room events are deliberately not implemented; current validation expects one-time resolution.
7. Current event interaction is mouse-first. The shared base now enables future programmatic/controller activation, but no focus-navigation system exists yet.
8. Bone Dice feedback is mechanically correct but could be presented more clearly as an exploding roll chain.
9. Three Red Wax Vials in one test run all rolled the same `+10 Corruption / -10 Resolve` result. This remains an observation, not a confirmed RNG defect.
10. Automated headless regression scripts still cannot be conveniently launched from the Godot Web Editor; manual deterministic-seed regression remains the normal workflow there.
11. The temporary KnowledgeState Web Editor save path remains intentionally non-production until the dedicated save-development cycle.

---

## 19. Proposed next interaction cleanup — NOT part of verified checkpoint

After the verified `17:48:37` checkpoint, the next proposed pass was to make `EventRoomScreen` directly consume the generic:

```text
ExplorationInteractable.interaction_hover_changed
```

contract.

That would consolidate the screen's separate item/lore/event hover handlers and allow locks and exits to expose the same hover-label path.

The proposed result would be:

```text
ExplorationInteractable
→ one common EventRoomScreen hover presenter
→ display name + prompt + contextual target information
```

with typed activation still remaining separate:

```text
item → inventory
lore → KnowledgeState
event → event resolver
lock → key logic
exit → room outcome
```

Because this pass had not yet been reported as tested when this summary was requested, it should **not** be treated as part of the stable checkpoint recorded above.

---

## 20. Recommended next gameplay milestone

Once the generic hover/UI pass is confirmed, additional abstraction is not currently necessary.

The next useful work should return to actual gameplay content by adding the first new interaction built on the finished systems, for example:

```text
trap
environmental mechanism
container/chest-style event
shrine
hidden reward
encounter-triggering room event
```

A good next vertical slice would use:

```text
RoomEventProfileDefinition
→ RoomEventSpawnAnchor
→ WorldRoomEvent
→ ExplorationInteractable input
→ deterministic outcome
→ room/run persistence
```

without introducing another independent interaction architecture.

---

## 21. Stable checkpoint statement

Relative to the 2026-08-06 summary, Abyssal Bloom now has a functioning end-to-end **room-event framework** rather than only a planned one.

The confirmed pipeline is:

```text
seeded Layer map
→ authored Event room
→ room-specific / layer-wide / global event profile
→ deterministic source activation and entry assignment
→ compatible authored event anchor
→ visible event overlay
→ common interaction input
→ weighted deterministic outcome
→ heroine / room / run effect
→ persisted event resolution
→ transactional EventRoomOutcome
→ map state and Bloom remain correct on Back / completion
```

The three current event proofs cover the important initial dimensions:

```text
Tarnished Service Bell
→ room-specific, message-only, remains visible resolved

Red Wax Vial
→ layer-common, selected-heroine target, weighted stat effects

Bone Dice Cup
→ global, LayerNumber-scaled exploding d10, Bloom reward
```

Together with the new `ExplorationInteractable` base, the exploration side of the prototype now has a reusable foundation for substantially more Event-room content without adding another bespoke click/hover implementation for every new object.
