# Layer 1–2 Generator Activation — 2026-08-27

Milestone 7 activates the existing forty-room Layer 1–2 registry as the sole
room-selection source for production Layer 1 and ordinary Layer 2 maps. It
extends the existing `LayerMapGenerator`, graph, RunState, map UI, and active-run
snapshot boundaries; it does not introduce a parallel route system.

## Deterministic generation

- A positive campaign-derived run seed, layer identity, and the authored room
  catalog determine room selection, topology, stable node IDs, connections,
  node types, and per-node content seeds.
- Layer-specific seed namespaces isolate room selection, edge construction,
  and node content without ambient or time-based randomness.
- Each layer contains one non-playable start marker followed by 10–13 unique
  playable nodes across six forward columns.
- Every result has a real branch, downstream convergence, complete
  entry-to-exit reachability, and mandatory entry/pre-exit gates that cannot be
  bypassed.
- Invalid or insufficient catalog data returns a clear generation error before
  a graph is installed in RunState.

## Required authored anchors

Layer 1 reserves the opening corridor, the three required exploration rooms
(Wine Cellar, Butler's Office, and Wax Preparation Room), the Ruined Chapel
recruitment encounter, and the Blood Nun boss room. The event rooms share the
first branched column so the generated Rusty Key placement can never require
passing its own Wine Cellar lock.

The authored Lower Kitchen is now the fixed first generated combat room for
the Corrupted Butler and Mira recruitment. This keeps the map's room identity,
battlefield geometry, and reviewed background coherent rather than applying a
generic Ruined Chapel field to a seed-selected strong-room identity.

Milestone 15 Pilot A adds Dining Service Hall and Bell-Pull Gallery to the
ordinary Layer 1 filler selection. Their stable room IDs, like every other
candidate, are seed-selected without replacement, so each can appear but
neither is universal. Dining Service Hall cannot replace the reserved
Corrupted Butler strong-room route. A later presentation pass gives every
art-backed filler an explicit background-and-exit exploration definition. The
`strong_battle_candidate` remains authoring metadata for later encounters;
presentation-only rooms cannot produce unbound generic battles.

Layer 2 reserves the Farthest Cell entry, Chain Maintenance first-slice battle,
Jailer's Gate pre-exit convergence, and Jailer's Containment boss room. Safe
generic registry entries fill the remaining route. The art-pending Intake
Corridor and entries tagged for required but unfinished narrative are excluded.

Selection of a registry entry does not imply combat or narrative content.
Generated nodes store `authored_room_id` for identity and set
`room_definition_id` only for one of the thirty-nine explicit exploration
definitions. Dining Service Hall additionally receives its fixed existing
encounter/template IDs; Bell-Pull Gallery receives no battle or reward. Other
generic rooms open their registered art and normal exit without invented
dialogue, enemies, or mechanics. Intake Corridor remains excluded while its
art is pending.

## Persistence and compatibility

`MapNodeState` snapshots now include plain serializable `authored_room_id` and
`content_seed` fields. Restoring older valid Save Envelope v3 active-run data
remains backwards-safe: authored identity falls back to the existing executable
room ID and an absent content seed defaults to zero. New generated non-combat
nodes use their stable content seed at the pre-node safe point; battle seed
allocation remains unchanged so established retry behavior is preserved.

Pre-node and post-node snapshots retain the complete generated graph, current
and pending node identities, resolution state, and reward-claimed flags.
Continue therefore resumes the stored topology rather than regenerating or
reshuffling unresolved content. Save Envelope version 3 and its backup,
corruption, and incompatibility rules are unchanged.

## Scope boundary

Milestone 8 now reuses this exact graph for the final Layer 1 → Jailer → reverse
Layer 2 demo route: after a real Jailer victory, the current node is the cleared
boss/end node and reciprocal travel carries the party toward the Farthest Cell.
It does not activate incomplete room content, add rewards or loot tables, change
combat/Grapple, or alter map presentation. Existing backtracking and first-clear
reward semantics are retained. See
`docs/L1_JAILER_REVERSE_L2_DEMO_FLOW_2026-08-27.md`.

## Validation

Run:

```sh
python3 tools/validate_project.py --allow-generated-cache
python3 tools/test_run_regression_suite.py
GODOT_BIN=/home/fluffy56/.local/bin/godot4 python3 tools/run_regression_suite.py
git diff --check
```

Focused coverage is in `tests/test_layer_generator_activation.gd`, with active
snapshot integration assertions in `tests/test_active_run_safe_points.gd`.
