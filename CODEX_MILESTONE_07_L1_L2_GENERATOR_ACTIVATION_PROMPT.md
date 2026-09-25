# Milestone 7 — L1–L2 Generator Activation

## Goal

Activate the existing authored Layer 1 and Layer 2 room registry as a deterministic, data-driven map generator. A new campaign must produce valid, traversable Layer 1 and Layer 2 subgraphs from the already registered room data, with stable node identities and deterministic seeds.

This milestone creates the generator foundation only. It does **not** implement the final Layer 1 → Jailer → reverse Layer 2 demo route; that is Milestone 8.

## Read before editing

Read these completely before planning or changing code:

- `AGENTS.md`
- `README.md`
- `docs/ACTIVE_RUN_SAFE_POINTS_AND_CONTINUE_2026-08-26.md`
- `docs/REFUGE_OWNERSHIP_AND_RUN_RESOLUTION_2026-08-26.md`
- the current Layer Map, node-map UI, room registry, room-definition, campaign lifecycle, and active-run persistence code
- the existing generator/map/regression tests, especially `test_layer_room_registry.gd`, `test_layer_transition.gd`, `test_node_map.gd`, `test_opening_event_room_flow.gd`, and `test_layer_2_first_slice.gd`
- `project_sources/02-04-ABYSSAL_BLOOM_LAYER_1_2_ROOM_AND_BATTLEMAP_VISUAL_SPEC_2026-07-24-1-1-.md`
- `project_sources/05-ABYSSAL_BLOOM_LAYER_NARRATIVE_REFERENCE_L1-L5_2026-08-11-1-.md`, only to identify already-authored L1/L2 anchors; do not invent narrative content.

Inspect the current state and write a concise implementation plan before editing. Extend the existing map/state architecture; do not create a parallel generator or replace working map UI.

## Locked functional contract

### Generator inputs and determinism

1. Use the existing registered authored L1/L2 rooms as the sole production content source. Do not add, rename, delete, or regenerate room artwork/resources in this milestone.
2. A `campaign_seed`, layer identifier, and the authored registry must deterministically produce the same topology, selected room IDs, node IDs, node types, connections, and node seeds.
3. Use explicit deterministic seed derivation. Do not use ambient RNG, wall-clock time, random device state, or iteration order that can vary between launches.
4. Node IDs and node seeds must remain stable after save/load and active-run Continue. Reconstructing from the same valid snapshot/seed must not reshuffle unresolved content.
5. Keep generated graph/runtime snapshots plain and serializable. Preserve the current active-run snapshot schema/version unless a narrow, backwards-safe extension is required by this milestone.

### Layer subgraphs

1. Generate a valid authored subgraph for each of L1 and L2.
2. Each generated layer contains **10–13 playable nodes**, inclusive. Entrance/transition markers that are not playable content nodes must not be counted as playable nodes.
3. Every layer has exactly one reachable entry/start node and one reachable authored exit/boss-route node. Do not hard-code a single fixed sequence.
4. Topology must contain meaningful branching and later convergence:
   - at least one genuine choice where two distinct forward routes are reachable;
   - at least one downstream convergence before the exit route;
   - no isolated nodes, dangling forward-only branches, self-links, or inaccessible selected rooms;
   - no bypass that reaches the exit/boss route without passing all required generator gates.
5. Preserve existing backtracking/revisit semantics and current-node/selected-node/pending-node invariants. A cleared node may remain revisitable where the existing map rules permit it; the generator must not create duplicate reward-bearing nodes by revisiting.
6. Use the current map presentation and interaction conventions. Do not add a new map screen, pan/zoom redesign, minimap, or map-art/UI overhaul.

### Required node reservation and content safety

1. Select registered rooms by their authored identifiers and declared categories/tags/roles—not filename guessing or hard-coded positional indices.
2. Reserve every currently executable required room/anchor needed by the existing opening, event, transition, and boss-route systems. Do not make an existing required flow probabilistic.
3. At minimum, retain deterministic reachable placement for the currently implemented L1 opening route, Wine Cellar, Butler’s Office, and the executable L2/Jailer-origin slice when their registry metadata marks them required.
4. If the registry lacks enough valid authored candidates to satisfy a required topology constraint, fail generation with a clear diagnostic; never silently duplicate a room or substitute an unrelated room.
5. Only select room/node types that have executable production handling. Do not activate incomplete authored items, dialogue, enemies, rewards, equipment, materials, scenes, or content merely because they are registered.
6. Preserve any existing room completion/event snapshot behavior. A node’s resolved state must remain bound to that node ID, not only to the underlying room ID.

### Campaign and persistence integration

1. New Campaign must initialize the deterministic generated L1 map through the normal opening flow.
2. Existing legal travel must operate against generated graph edges rather than test-only/fixed graph construction.
3. Milestone 6 pre-node and post-node safe points must capture sufficient generated map/run state for Continue to resume identically, without replaying a resolved node or reward.
4. Refuge return, defeat, abandonment, and Refuge save behavior must continue clearing active-run state exactly as Milestones 5–6 define.
5. Continue before the first safe point remains disabled. This milestone must not create mid-node, mid-dialogue, or mid-combat saves.
6. Do not change Save Envelope version `3`, its corruption/.bak rules, or pre-v3 incompatibility behavior.

## Explicitly out of scope

- The full intended L1 → Jailer → reverse L2 progression, gate corrections, and final victory/defeat boundaries (Milestone 8).
- Loot tables, reward weighting, or activation of incomplete loot/items (Milestone 9).
- Equipment/material authoring, salvage, recipes, crafting, or Refuge services/UI (Milestones 10–11).
- New dialogue/cutscene production content (Milestone 12).
- Combat, Grapple, enemy AI, balance, actions, targeting, status timing, or encounter mechanics.
- Background, battlemap, sprite, animation, visual-profile, camera, or UI-art changes.
- Any broad cleanup of the accepted failing-test baseline.

## Tests and validation

Add focused generator tests that prove, at minimum:

1. Same campaign seed + layer produces byte-equivalent logical graph data (nodes, room IDs, types, connections, IDs, and node seeds).
2. Different seeds may vary route/room selection while every generated graph still satisfies the topology invariants.
3. Both L1 and L2 produce 10–13 playable nodes using only valid registered rooms.
4. Required executable anchors are reachable and never omitted when their metadata requires them.
5. Branching, convergence, entry-to-exit reachability, and no-bypass gating are validated structurally.
6. Invalid/insufficient registry data fails clearly and transactionally; it does not create duplicate room use or a partial active run.
7. Generated graph snapshot → restore → Continue preserves node IDs, pending selection, node seeds, cleared-state behavior, and does not duplicate a resolved reward.
8. Existing backtracking and legal-travel behavior still works against a generated graph.

Run:

- structural validation;
- regression-runner self-tests;
- all focused generator, map, layer-transition, opening, active-run safe-point, save-slot, campaign-lifecycle, and room-registry tests;
- the complete Godot 4.7.2 suite;
- `git diff --check`.

The accepted baseline before this milestone is **20 passing / 15 failing across 35 scripts**. Do not repair unrelated existing failures. Report any change in failures script-by-script and explain whether it is directly caused by this milestone.

## Manual Godot QA

Do not commit. Report the exact changed files and validation results, then leave these checks for review:

1. Start several New Campaigns; confirm L1 map layouts vary across campaign seeds while remaining readable and traversable.
2. Restart with the same stored campaign seed; confirm L1 node/room layout and node content seeds match.
3. Confirm at least one visible branch converges before the L1 exit/boss route and backtracking remains available where expected.
4. Traverse an implemented event room, resolve it, leave/revisit it, and confirm its result/reward is not replayed.
5. Force-close at a pre-node and post-node safe point; Continue and verify the same generated map/node identities and no duplicate resolved reward.
6. Exercise existing L2/Jailer-origin entry only as far as current production flow supports; ensure no broken transition or missing-room error occurs.
7. Smoke-test Main Menu, Refuge return/defeat boundaries, combat, Grapple, Item Bar, Key Chain, and Refuge presentation.

## Completion standard

Milestone 7 is complete only when the authored L1/L2 registry generates deterministic valid subgraphs, required executable anchors are protected, generated graph state survives save/Continue correctly, focused tests pass, and the full suite introduces no unrelated regression. Do not commit.
