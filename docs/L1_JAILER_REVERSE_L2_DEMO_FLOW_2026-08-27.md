# Layer 1 → Jailer → Reverse Layer 2 Demo Flow — 2026-08-27

Milestone 8 completes the intended Refuge-less demo route without adding a new
map, campaign, save, combat, or Refuge subsystem.

## Route

- The existing deterministic tutorial Layer 1 retains its opening, recruitment,
  exploration-room, and Blood Nun anchors.
- Blood Nun victory retains the authored **Go Up** / **Go Down** choice. Go Up
  remains a disabled Layer 3 threshold; Go Down immediately creates the small
  containment-side Jailer entry and writes the existing pre-node safe point.
- Jailer defeat retains the authored Refuge-origin dialogue, normal defeat-loss
  transfer, and one-time transition to the Bloom Refuge hub.
- Jailer victory is committed as victory. It records the boss once, generates
  Milestone 7's deterministic full Layer 2 graph from the Refuge-less Layer 2
  seed, clears the Jailer node, and places the party at that boss/end node.
- Map travel is already reciprocal, so the stored forward topology needs no new
  orientation field. The party follows legal incoming connections backward to
  `l2_refuge_farthest_cell`; the exact graph and current/pending node state are
  retained in active-run snapshots.
- Reaching Farthest Cell alive creates the existing Refuge ownership boundary
  with the voluntary-return transfer policy, recovers HP/MP, sets the existing
  one-time Refuge flag, and opens the existing hub. It does not synthesize a
  dialogue result.

## Persistence and compatibility

The Jailer pre-node state and the post-victory reverse-route state use the
existing pre-node/post-node safe-point contracts. Saving the resulting Refuge
uses the existing atomic Refuge save and replaces `active_run_snapshot` with
`null`, so Continue cannot reopen the resolved route.

No serialized field or Save Envelope shape changed. Save Envelope remains
version 3. Older valid v3 active-run snapshots and Milestone 7 generated graph
snapshots retain their previous meaning because direction is represented by the
already-serialized current node and graph connections.

## Deliberate deferrals

Generic registered Layer 2 rooms remain generic non-combat resolution nodes.
No new dialogue, enemies, battles, loot, room activation, Refuge UI, combat
balance, Grapple behavior, or Layer 3 content is introduced here.

## Validation

Run:

```sh
python3 tools/validate_project.py --allow-generated-cache
python3 tools/test_run_regression_suite.py
GODOT_BIN="$HOME/.local/bin/godot4" python3 tools/run_regression_suite.py
git diff --check
```

Focused route coverage is in `tests/test_l1_l2_demo_flow.gd`, with transition
safe-point and Continue-clearing coverage in
`tests/test_active_run_safe_points.gd`.
