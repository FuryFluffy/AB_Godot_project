# Post-Wipe Narrative-State Restoration Fix — 2026-08-10

## Runtime failure

After a Seraphine-recruitment or Blood Nun wipe, the regenerated Layer 1 run
could continue with `RunState.narrative_state == null`. This produced two
related Web runtime failures:

- Corrupted Butler outcome classification dereferenced
  `recruited_heroine_ids` on `Nil`.
- Event-room launch dereferenced `narrative_state.to_snapshot()` on `Nil`,
  leaving Butler's Office selected on the Node Map without opening the room.

## Correction

- `RunState.initialize()` now owns a concrete `NarrativeState` instance and
  restores the recovery snapshot into that instance.
- Snapshot restoration validates all fields before committing them.
- Invalid restoration stops run initialization instead of allowing a partial
  run to launch.
- Encounter classification and narrative-flag checks tolerate a missing state
  without crashing.
- Dialogue and Event-room launchers use a guarded narrative snapshot API.
- A missing recovery narrative snapshot prevents restart and reports a visible
  error instead of silently discarding recruitment.

## Preserved rules

- The full-wipe consequence remains exactly -15 Resolve.
- HP and MP recover for recruited heroines.
- Mira remains recruited after a Ruined Chapel wipe.
- Lysandra, Mira, and Seraphine remain recruited after a Blood Nun wipe.
- Unrecruited scene allies are excluded from the recovered party.

## Regression coverage

The recovery regression now reuses the same `RunState` object, matching the
real controller lifecycle, and verifies both two- and three-heroine recovered
parties can prepare Butler's Office with a live narrative snapshot.
