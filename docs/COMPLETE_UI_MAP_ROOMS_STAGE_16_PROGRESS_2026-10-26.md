# Stage 16 — initial partial checkpoint (superseded)

**Update:** The user restored the archive, and Stage 16 is complete. See `COMPLETE_UI_MAP_ROOMS_STAGE_16_REVIEW_2026-10-26.md`. The text below records the earlier missing-assets checkpoint.

## Status and scope

Authorized by “Good, proceed to stage 16.” Stage 16 is **incomplete**. Navigation and live-route presentation work is implemented locally; final parchment/emblem/overlay integration and visual acceptance are blocked on the original supplied package. Stage 17 has not begun. No commit or upload was requested for this stage.

The supplied staged prompt remains at `/home/fluffy56/Downloads/CODEX_AB_COMPLETE_UI_MAP_AND_ROOMS_STAGED_PROMPT.md`. The original `/home/fluffy56/Downloads/AB_Complete_UI_Map_and_Rooms_v1.zip` and earlier temporary extracted handoff are absent. Searches of the repository, Downloads, Desktop, the home directory (including hidden paths), and `/tmp` did not locate `occult_parchment_flat.png`, `Node_Map_Art`, `presentation_notes.json`, the package ZIP, or `NODE_MAP_AND_SPECIAL_ROOMS.md`. The retained Stage 00 audit specifies the art requirements but cannot replace the assets or their exact manifest mappings.

## Implemented behavior

- Wheel zoom, plus/minus buttons, bounded middle-button pan, Fit map, and Current room focus. Zoom ranges from 100–250% in 25% steps; these are presentation tuning values.
- Keyboard arrows and the existing directional input actions move focus between visible room positions. Off-screen focus pans the node into view; Enter retains ordinary node selection. Current room focuses without selecting or travelling. Toolbar controls remain outside the zoomed content.
- Live routes and buttons share one zoom/pan transform. Route lines stop outside button bounds. Only known, non-hidden connections are drawn. Known locked edges display a temporary text marker and remain inaccessible under the existing RunState rules.
- Updated the map hint to describe discovery, wheel zoom, and middle drag. Existing unknown labels, safe tooltips/details, and separate travel confirmation remain intact.
- Rebinding a map resets presentation and removes obsolete buttons. No map knowledge, completion, travel, content, or reward state is changed by navigation.

## Files changed in Stage 16

- `scripts/map/layer_map_view.gd`: presentation transform, controls, focus navigation, live route filtering/lock labels. Extends the Stage 15 version already in the working tree.
- `scenes/main/main.tscn`: player-facing map hint.
- `tools/verify_map_navigation.gd` and UID; `tests/test_map_navigation_ui.gd` and UID: production Main-scene fixture and suite entry.
- `tools/run_regression_suite.py`: one new test registration; existing Stage 15 and unrelated Content Workbench registrations preserved.
- This progress report, combined ledger, and `docs/evidence/complete_ui_stage16/`.

Stage 15 edits remain local and intact. Unrelated Content Workbench files and `project.godot` changes are preserved.

## Ownership and compatibility

No serialized fields, IDs, enums, save versions, migration rules, or generation contracts changed in Stage 16. Zoom, pan, and focus are transient view state. Existing Stage 15 graph knowledge and RunState travel guards remain authoritative. No new room/service activation, paid Intel behavior, or cross-layer controls.

## Verification

- `python3 tools/validate_project.py --allow-generated-cache`: passed, **254 named classes**.
- `GODOT_BIN=/home/fluffy56/.local/bin/godot4 python3 -B tools/run_regression_suite.py`: **68/68 scripts passed**, exit 0, zero GDScript parse/compile/runtime errors. Includes the unrelated existing Content Workbench test. Stage 15 discovery UI remains 24/24; new Stage 16 navigation is 61/61.
- `python3 -B -m unittest discover -s tools -p 'test_*.py'`: **13/13 passed**.
- Native Godot 4.7.2 Compatibility run of `tools/verify_map_navigation.gd`: **61/61 checks passed**, exit 0, at 1920×1080, 1600×900, 1280×720 and 1024×768. Mouse wheel/buttons, middle drag, keyboard, injected gamepad direction, focus, fit, unknown selection, known locks, hidden edges, graph-state preservation and rebinding checked. Nine screenshots generated; three retained and visually inspected, including the corrected route endpoints.
- Native presentation still reports the established five ObjectDB/three resource shutdown diagnostics. The broader suite retains existing teardown diagnostics and intentional invalid-save diagnostics; these are not concealed as clean output.
- `git diff --check` passes; changed source, test, scene and runner diffs reviewed. No Stage 16 backend/save changes or unrelated additions. Editor-generated sidecars for old evidence were removed.

Native reproduction: run Godot with `--path . --script tools/verify_map_navigation.gd -- --map-captures=/tmp/ab-stage16-captures` and isolated `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, and `XDG_CACHE_HOME` paths. Logs and selected captures are in `docs/evidence/complete_ui_stage16/`.

 Native fixture uses isolated user/config/cache paths and the production Main scene with a seeded test graph, not a normal campaign save. All screenshots still show the existing text-button presentation, not approved Stage 16 artwork.

## Remaining work and blocker

Restore or reattach `AB_Complete_UI_Map_and_Rooms_v1.zip` (or its extracted folder including `Node_Map_Art`, manifests, root implementation stages and detailed map spec). Then inspect the actual approved artwork and finish:

- Flat parchment with correct aspect ratio; eleven emblems and exact manifest aliases, including Intel/identified traps.
- Independent state overlays for current location, selection/focus, visited, encounter clear, Solved, used Rest, and approved edge locks as specified. Current-location bloom belongs behind the icon; no duplicate medallion frame.
- Responsive final art sizing and native visual checks at supported sizes; final stage acceptance against the recovered detailed checklist.

The missing files are an asset/specification blocker, not an unresolved gameplay-design question. No replacement imagery or guessed manifest mappings were introduced. Boss art remains provisional as specified. Physical-controller and normal-campaign player acceptance are also pending.

## Player check for the available controls

Open an existing run's map. Use the wheel or +/− to zoom; middle-drag to pan. Use Fit map to restore every position. Use Current room to focus your location without moving the party. Arrow keys move focus, Enter selects, and Travel retains its existing eligibility check. Unknown rooms must retain question marks and anonymous details. Hidden routes must remain absent. A known locked route must not permit travel.

Suggested eventual commit for this partial implementation: `feat: add bounded map zoom and focus navigation`. Do not describe Stage 16 as complete until its artwork and detailed acceptance checks are finished.
