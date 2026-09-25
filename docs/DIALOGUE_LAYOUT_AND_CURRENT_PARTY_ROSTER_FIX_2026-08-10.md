# Dialogue Layout and Current-Party Roster Fix — 2026-08-10

## Runtime findings

- Generated map encounters inherited `EncounterDefinition.party_ids`, whose
  prototype default contained Lysandra, Mira, and Seraphine.
- The solo corridor did not show this fault because its story encounter
  explicitly assigned Lysandra.
- The dialogue panel declared a bottom-wide preset but omitted
  `anchor_top = 1.0`. Godot therefore stretched the visible panel from above
  the viewport to the bottom instead of treating it as a bottom window.
- The always-visible choice scroll also continued reserving height on nodes
  without choices.

## Changes

- `RunState.make_encounter_definition()` now derives `party_ids` from the
  current run-party snapshot in canonical heroine order, followed by future
  party IDs in deterministic order.
- The Corrupted Butler map battle therefore contains only Lysandra at the
  current pre-recruitment stage. Mira can later be added explicitly as a
  scene-present ally by the recruitment milestone without recruiting
  Seraphine or changing global defaults.
- Dialogue presentation is now a full-viewport staging control containing:
  - an independent left full-body actor stage;
  - an independent right full-body actor stage;
  - a fixed 220 px bottom dialogue frame;
  - a speaker portrait column;
  - speaker name, dialogue text, choices, item prompt, and Continue/Finish.
- The two actor textures and their horizontal flip settings are authored per
  `DialogueNodeDefinition`, allowing later node-by-node pose/expression swaps.
- Empty actor stages and the choice scroll hide automatically.
- The development dialogue uses Lysandra's temporary stage sprite and speaker
  portrait to provide a visual runtime check.

## Regression coverage

- The opening/Event-room flow test asserts that the first Corrupted Butler
  map encounter derives a Lysandra-only roster from the run snapshot.
- The dialogue test asserts that the frame is bottom-anchored and compact and
  that two independent actor stages exist.

## Runtime test gate

1. Complete the Lysandra-only corridor opening.
2. Enter the first Corrupted Butler battle and confirm only Lysandra appears
   in combat and in the combat HUD.
3. Enter an Event room with the developer dialogue enabled.
4. Confirm the room and shared exploration HUD remain visible.
5. Confirm Lysandra's staged sprite appears above the compact bottom box.
6. Confirm the speaker text and both choice buttons are visible.
7. Select the Warm Wine Flask and confirm the item route still advances and
   consumes one flask.
8. Finish the dialogue and confirm room hotspots become interactive again.
