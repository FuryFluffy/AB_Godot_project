# Stage 16 — completed map presentation

The user restored `/home/fluffy56/Desktop/For_upload/AB_Complete_UI_Map_and_Rooms_v1.zip` and explicitly authorized finishing Stage 16 and proceeding to Stage 17. This supersedes the earlier partial checkpoint and missing-assets blocker. Stage 17 does not require another review pause under that instruction; player acceptance is still separate from implemented/tested status.

## Delivered

The supplied flat parchment and eleven engraved-gold medallions now display the actual generated graph. Independent violet Current ring (behind the type), Visited, Solved, used-Rest, selection and focus overlays coexist. Known locks are attached to actual known blocked edges; hidden/unknown edges have no placeholders. Encounter clearance is shown truthfully in known-room tooltips, separately from Solved. No extra medallion frame, baked preview, Floor Up/Down action, purchased Intel activation, or new room service.

Mouse wheel/button zoom, bounded middle-drag pan, Fit map, Current room, directional keyboard/gamepad focus, Enter selection, anonymous unknown tooltips/details and existing travel/backtracking are retained. Texture aspect ratios are preserved. Native screenshot review prompted mipmapped linear filtering for small engraved artwork and stronger route contrast. The supplied source image bytes remain unchanged; only Godot import settings enable mipmaps. Boss art remains provisional; remaining symbols/overlays retain their source package's review status.

The restored detailed specification explicitly says ordinary adjacency reveals **connections only**; without Scouting, adjacent room types remain unknown until entry. The retained audit had omitted this qualifier. `LayerMapGraph.reveal_adjacency` now defaults to route-only discovery, with an explicit identification parameter for the later Scouting integration. Locked/hidden exits still block adjacency identification. Existing saved `type_known` values are retained; no discoveries are erased and no save migration/version bump occurs. Tests replace the superseded Stage 15 neighbor-identification expectation and add explicit route/Scouting separation coverage.

## Files and ownership

- `assets/map/revision_2/`: exact supplied map/control/state/Intel assets, trap-marker aliases and manifests, plus normal Godot imports. Alias registration is inert.
- `scripts/map/map_art_library.gd` (+UID): manifest-backed texture/type mapping; legacy ITEM/EVENT map to exploration.
- `scripts/map/layer_map_view.gd`: aspect-correct composition and independent overlays, navigation and live routes; safe focus disposal when rebinding a different layer.
- `scripts/map/layer_map_graph.gd`: corrected adjacency identification default; no new persistence fields.
- `scenes/main/main.tscn`: navigation hint from the earlier partial implementation.
- `tests/test_map_discovery.gd`, `tools/verify_map_discovery.gd`, `tools/verify_map_navigation.gd`, `tests/test_map_navigation_ui.gd` and UIDs, runner registration: focused state and native presentation coverage.
- `docs/design/complete_ui_map_rooms_v1/`: exact restored root stage/authority/check documents, map gameplay spec and particle guidance, retained for future stages. These are reference specifications, not new authorization to implement all stages.
- Review/progress/ledger and `docs/evidence/complete_ui_stage16/`.

Graph/run state, encounter sequencing, save ownership and safe points remain in their existing owners. Presentation queries never mutate knowledge/completion. Prior Stage 15 and unrelated Content Workbench work remains intact; no commit/push was requested.

## Validation and evidence

- `python3 tools/validate_project.py --allow-generated-cache`: passed, 254 named classes.
- `GODOT_BIN=/home/fluffy56/.local/bin/godot4 python3 -B tools/run_regression_suite.py`: **68/68 scripts passed**, exit 0, zero GDScript parse/compile/runtime errors. Includes the pre-existing Content Workbench test.
- `python3 -B -m unittest discover -s tools -p 'test_*.py'`: **13/13 passed**.
- Map state: **1,453 checks**, zero failures, including 200 seeded full graphs. Discovery UI: **24/24**.
- Final targeted presentation: **100/100** headless checks, including cross-layer rebind/focus disposal added after the full suite.
- Native Godot 4.7.2 Compatibility: **99/99** presentation checks, exit 0; real Main scene, injected mouse, keyboard and gamepad-direction input at 1920×1080, 1600×900, 1280×720 and 1024×768. Twelve screenshots generated; five final art captures retained. Inspected aspect/layout, independent badges, unknown presentation, focused zoom and lock routes. The final native pass includes filtering/contrast changes; the subsequent rebind guard is covered by the 100-check headless run.
- Existing five ObjectDB/three resources shutdown diagnostics persist; broader suite retains baseline diagnostics and intentional invalid-save checks. One native approval review timed out; its permitted retry succeeded.
- `git diff --check` and changed-file/diff review completed. No new Stage 16 design blocker.

This is fixture-based native QA, not a full normal-campaign or physical-controller playthrough. Those user checks remain pending.

## Player review

Open a run's map: unknown rooms should use the question-mark medallion, with only discovered routes shown. Enter a reachable unknown room to identify it; leaving via an open exit reveals routes without Scouting identification. Use zoom, middle-drag, Fit map, Current room, arrows and Enter. Confirm Current is distinct from selected/focused, and that solved/visited/used-Rest badges do not replace the room type. Used-Rest/special-type coexistence is demonstrated by the isolated art fixture until those services activate in their later stages.

Native fixture: `godot4 --path . --script tools/verify_map_navigation.gd -- --map-captures=/tmp/ab-s16-art-captures`, with isolated XDG user/config/cache roots. Suggested commit: `feat: integrate supplied node-map art and discovery presentation`.
