# Stage 15 — graph generation, knowledge and exit-driven discovery

Authorized by “Good, proceed with stagr 15.” Stage 14 was committed as development `3ecbdba7fdabbebf2365b6b5a3fe38e35798df58` and published as `eebecfe57574d62b02784d0c1c536914a0941bed` on `codex/complete-ui-map-rooms-stages-01-14`, with identical trees and remote verification. This stage remains local for review; Stage 16 has not begun.

## Player behavior

- New full Layer 1/2 maps contain 14–16 playable rooms within the required 14–18 budget, excluding the starting anchor. The main route has nine playable rooms. Three branches contain two, two and one–three rooms, yielding three genuine dead ends. Mandatory opening/recruitment/boss gates retain their stable IDs and order. Room selection, topology, content seeds and special-position reservations are deterministic.
- Every room position remains visible. Unknown types show `?`; buttons, hover text and selected details do not expose their identity, encounter or completion status. Only discovered, non-hidden connections are drawn. Selecting an unknown position does not identify it or permit travel.
- Successful room exits reveal eligible adjacent types and connections without requiring Solved. Entering, browsing, or returning through Back does not reveal further adjacency. Room exit bindings capture the real authored lock state; a locked exit cannot be used or reveal beyond it. Hidden edges remain undiscovered.
- Existing within-layer BFS backtracking now checks knowledge, locks and travel eligibility on every edge. Explored dead ends can be retraced. Cross-layer Floor Up/Down remains deferred.
- Visited, successful exit, encounter victory, Solved and Rest use are separate stored facts. The old `cleared` field remains as the legacy visit-resolution/reward compatibility flag. Exploration exit does not fabricate a combat victory or Solved. A room's optional encounter remains available on revisit; winning it after an earlier exit grants its combat Bloom once. Combat-only victory may mark Solved; generic exploration does not invent a completion rule.
- The Jailer-to-Farthest-Cell reverse route discovers from the defeated boss end, without prematurely revealing or visiting the farthest cell. Permanent boss deaths and claimed rewards persist. Two-node story thresholds and Refuge holding graphs remain special transitions outside the full-layer room budget.

## Transitional activation boundary

The Stage 00 audit called for planning final quotas without activating unfinished content. This implementation saves reservations for Elite 1–2, Trap 1–2, Treasury 1–2, Rest 0–1, Alchemy 0–1 and Workshop 0–1 inside the existing room budget. New enum values are registered, and a test-only projection activates the reserved types to verify actual quotas. Production node types remain the existing executable content: zero generated Elite/Trap/Treasury/Rest/Alchemy/Workshop services at this checkpoint. Elite execution belongs to Stage 17; special-room services to Stages 18–21. These reservations allocate graph positions, not new narrative, encounter formations, loot or service definitions. They must be wired to authored executable content before activation. No registered Layer 3–10 content is enabled.

The existing panel-based map is retained, with the minimum node-size and contrast adjustments needed for the larger graph. Flat parchment, emblems, overlays and zoom belong to Stage 16. The original consolidated ZIP remains unavailable locally; the supplied staged prompt and retained Stage 00 audit supplied the requirements for this stage. No replacement art or economy values were invented.

## Ownership and changed files

- `scripts/map/map_node_state.gd`: appended special-room enums and independent knowledge/completion fields; strict validation and absent-field defaults.
- `scripts/map/layer_map_graph.gd`: existing adjacency remains authoritative; adds saved edge knowledge/lock/hidden/exit data, reservations, structural validation and discovery/access queries.
- `scripts/map/layer_map_generator.gd`: expanded deterministic topology and quota reservations; validates room budget, main route, branch lengths, dead ends, registration, unique rooms, keys and mandatory gates.
- `scripts/map/run_state.gd`: discovery at committed exits/resolution and lifecycle entries; per-edge BFS access; separate encounter bookkeeping; safe-point entry rollback includes type knowledge.
- `scripts/exploration/{room_exit_hotspot,event_room_outcome,event_room_screen}.gd`: explicit destination bindings, single-exit fan-out fallback, authored lock handoff and independent Solved outcome field. Multi-exit rooms require unambiguous explicit bindings.
- `scripts/map/{main_controller,layer_map_view}.gd`: production exit binding, information-safe labels/tooltips/routes and optional-encounter revisit behavior.
- `tests/test_map_discovery.gd`, `tools/verify_map_discovery.gd`, `tests/test_map_discovery_ui.gd` and their UID sidecars: seeded topology, discovery/lock/save/compatibility and production-host native QA.
- Existing `tests/{test_node_map,test_opening_event_room_flow}.gd` and `tools/validate_project.py`: update only the superseded seven-column/convergent-route expectations. Recruitment remains a non-bypassable gate; dead-end branches no longer have to converge.
- `tools/run_regression_suite.py`: registers two focused scripts. The unrelated Content Workbench registration/plugin/files remain untouched.

## Persistence and compatibility

The production v3 envelope, atomic store, backups and pre-node/post-resolution safe points remain unchanged. Graph snapshots add `edge_states` and `reserved_node_types`. Node snapshots add `type_known`, `exit_completed`, `encounter_cleared`, `solved`, and `rest_used`. Legacy layouts are restored verbatim, not regenerated to the new budget. Legacy knowledge derives from visited/resolved adjacency; old event clearance does not invent Solved or Rest use. Malformed explicit fields, nonexistent/duplicate edges, invalid reservations and invalid enum values reject before the live RunState restore commits. Existing item/reward/preparation migrations remain.

Interrupted nodes retain the selected content seed and pre-exit knowledge. Successful exits persist new knowledge with the room/inventory outcome at the existing post-resolution boundary. Failed pre-node writes roll back visitation and newly learned type information. New fields do not create mid-node saves or a parallel persistence service.

## Verification

Completed on 2026-10-26. `GODOT_BIN=/home/fluffy56/.local/bin/godot4 python3 -B tools/run_regression_suite.py` passed **67/67 scripts**, exit 0, with no GDScript runtime/compile/parse errors. This includes the unrelated pre-existing Content Workbench test. `python3 tools/validate_project.py --allow-generated-cache` passed with **254 named classes**. `python3 -B -m unittest discover -s tools -p 'test_*.py'` passed **13/13 tests**. The focused graph test passed **1,449 checks**, including 200 full-layer generations. Headless and final native UI each passed **24 checks**. `git diff --check`, diff/stat review and inspection of the new test/tool files passed. An initial run found three expectations tied to the superseded convergence layout; those tests were corrected to assert the still-mandatory recruitment gate, then the full suite passed. Native QA uses the production Main scene and EventRoomScreen, injected mouse/keyboard input, and isolated data. Four resolutions: 1920×1080, 1600×900, 1280×720 and 1024×768. Five captures generated; three retained under `evidence/complete_ui_stage15/`. The fixture checks unknown Boss hover/details, selection without discovery, non-overlapping visible positions, real Wine Cellar exit bindings/lock rejection, successful exit discovery without Solved/combat victory and Continue snapshot restoration. Its unlocked state is supplied explicitly for this isolated UI check; this is not a claimed normal-campaign playthrough or a new key-use rule.

Existing Godot shutdown resource/ObjectDB warnings remain. Some valid key-placement profiles report that the Office alternative is inaccessible behind Wine Cellar; the guaranteed key then uses the reachable Wine Cellar candidate. This is a placement diagnostic, not a failed generation or a missing key. State tests validate required-item placement over 200 generated layers.

## Player verification

1. Start a new campaign and finish the opening. Verify all positions are shown, only the first discovered connection/type is exposed, and clicking/hovering an unknown room reveals no identity.
2. Follow the required recruitment route. Enter an exploration room, inspect or leave through Back, and confirm no further connections appear. Successfully use an eligible exit and confirm its adjacency appears even when items remain.
3. At Wine Cellar, confirm the locked exit reveals nothing beyond it. Unlock through the existing key interaction, exit, and confirm discovery. Walk into a dead end and backtrack through explored passages.
4. Continue from a post-resolution save: layout, known connections, room contents and completion facts should match. Interrupt a pending room: Continue should preserve its original seed and pre-exit knowledge.
5. On the Refuge-less Jailer-victory path, verify return traversal reaches Farthest Cell without repeat boss rewards.

Normal campaign and physical-gamepad acceptance remain for the user. No unresolved Stage 15 design blocker; special-room execution and final artwork remain explicitly scoped to later stages. Suggested commit: `feat: add persistent map discovery and branched layer generation`.
