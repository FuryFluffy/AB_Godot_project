# Abyssal Bloom — Layer 1 Solo Opening and Event-Room Regression Milestone

**Date:** 2026-08-10  
**Engine:** Godot 4.7  
**Baseline:** `preload_2026-08-10_09-07-20.zip`

## Implemented run opening

The production run now begins with the canonical Layer 1 sequence:

```text
new seeded run
→ generated map prepared but hidden
→ Lysandra alone in Opening Servant Corridor
→ one Hollow Servant, no dialogue preamble
→ victory outcome
→ generated Layer 1 map revealed
```

The opening is a pre-map story encounter rather than a generated map node. Its
stable identifiers are separate from the later Corrupted Butler encounter, so
Mira's recruitment battle remains available for the dialogue milestone.

The encounter uses:

- `opening_servant_corridor_opening` template;
- party composition: Lysandra only;
- enemy composition: one Hollow Servant;
- a seed derived through `StableSeedMixer`;
- the existing six-slot run inventory and progression snapshot.

Victory transfers Lysandra's HP, MP, Resolve, Corruption, equipment damage,
inventory, progression, and earned Bloom into `RunState`. The opening reward
cannot be claimed twice. Map travel is rejected until victory.

Defeat does not reveal the map or carry a zero-HP snapshot forward. The return
control restarts the same seeded run and opening encounter.

## Solo combat presentation

The reusable combat HUD now derives its visible heroine cards from the actual
encounter roster. In the opening it displays only Lysandra and fits the Party
Strip frame to one card while preserving the user's authored bottom-left
position. Three-member developer and later run encounters retain the authored
three-card frame.

## Event-room regression foundation

`tests/test_opening_event_room_flow.gd` covers the state contracts that the
dialogue and remaining Layer 1 content will depend on:

- identical seeds produce identical assignments of all three Event rooms;
- the generated Rusty Key always has a valid host;
- when hosted in Butler's Office, the key remains reachable without crossing
  the Wine Cellar that it may be needed to unlock;
- Back preserves local room state and returns to the entrance without clearing;
- completion clears the pending Event-room node;
- collected item assignments remain collected after revisit;
- resolved room-event assignments remain resolved after revisit;
- party, inventory, and Bloom transfer back into `RunState`;
- Bloom already handed off through Back is not replayed on later completion.

The regression manifest now contains 24 scripts.

## Runtime verification checklist

1. Generate a new run and confirm combat opens before the map is shown.
2. Confirm only Lysandra and one Hollow Servant are present.
3. Lose once and use **Return to the Beginning**; confirm the same seed
   restarts, HP/MP recover, and the 15 Resolve full-wipe penalty remains.
4. Win and use **Enter the Layer 1 Map**.
5. Confirm Lysandra's remaining state, inventory quantities, and 4 Bloom persist.
6. Confirm the first generated node remains the separate Corrupted Butler
   encounter.
7. Enter an Event room, collect or resolve content, press Back, revisit, and
   confirm that content does not respawn.

## Next milestone

Build the dialogue framework on top of `ExplorationInteractable` and the
existing room-event outcome model. Mira's Corrupted Butler recruitment and
Seraphine's Ruined Chapel recruitment should be its first authored flows.
