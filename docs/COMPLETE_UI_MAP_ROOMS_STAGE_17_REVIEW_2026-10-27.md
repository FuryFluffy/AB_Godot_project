# Stage 17 — generated combat-only nodes

Authorization: the user supplied the restored archive and requested completion of Stage 16 followed by Stage 17, then resumed this work on 2026-10-27. Stage 16 is complete; its separate report records supplied artwork and navigation. This stage implements generated Normal/Elite combat entry. Stage 18 is not activated.

## Delivered behavior

New full Layer 1 and Layer 2 maps contain one or two executable Elites within the existing room budget. Reservations exclude mandatory story content, existing encounters, Bell-Pull Gallery and authored material sources. Other reserved special types remain inactive. Generated combat nodes launch combat immediately, with no exploratory hotspots or retreat action.

Layer 1 reuses Hollow Servant + Knife Footman + Prayer-Rag Novice and the existing Red-Wax Acolyte + Hollow Servant alternative. Layer 2 uses the existing pair because its authored battlefield has two enemy spawn slots. Party sizes of one, two and three are retained. No new enemies, stats, recipes, item drops or reward balance were invented.

Two template-based stage bindings support stable generated encounter IDs. Exact authored encounter bindings take precedence, preserving story/recruitment preludes, aftermaths, Dining Service Hall and other existing encounters. CombatEngine, presenter/HUD intentions, EncounterCoordinator and authored battlefields retain their existing ownership.

Victory offers any authored item findings before the summary, grants the existing four-Bloom generic combat reward, resolves/Solves the node and returns to its actual layer map. Generated Elites have no authored item-drop source; their summary explicitly says there are no item findings. Revisiting resolved combat produces no enemies or repeat rewards. Defeat follows the existing summary and loss/end-run flow; the old expedition cannot be retried or restored through Continue. Equipment survives, carried contents and Item Bar contents are lost, surviving Materials bank once, and the tested Resolve consequence persists.

Native visual inspection found the chapel's third enemy hidden behind Seraphine. The authored Enemy3 spawn now uses the adjacent existing Right Nave position, at (1510, 755), instead of (1300, 755). This preserves its zone/anchor, enemy identity and spatial-system ownership. Final screenshots show all three enemies; a real target-click check confirms the support enemy receives input with three heroines present.

## Changed files

- `scripts/map/layer_map_generator.gd`: protected reservation candidates and Elite-only activation/validation.
- `scripts/map/run_state.gd`: existing Elite formation selection respects the selected template's spawn capacity.
- `scripts/map/main_controller.gd`: combat completion guard, generated template binding lookup, findings and correct-layer summary.
- `scripts/data/presentation/combat_stage_binding_definition.gd`, `combat_stage_catalog.gd`, `data/presentation/combat_stage_catalog.tres`: optional template fallback with exact-story precedence; seven existing stages and nine bindings.
- `scenes/battle/battlefields/ruined_chapel_battlefield.tscn`: third enemy uses an existing adjacent position for visibility.
- `tests/test_generated_combat_nodes.gd`, `tests/test_generated_combat_ui.gd`, `tools/verify_generated_combat.gd` and their UIDs: generated-map, persistence and production UI fixtures.
- `tests/test_milestone_15_pilot_a.gd`, `tests/test_static_png_combat_presentation.gd`, `tools/validate_project.py`, `tools/run_regression_suite.py`: explicitly superseded activation/binding expectations and new registrations.
- This report, stage ledger and `docs/evidence/complete_ui_stage17/`.

Stage 15/16 edits in shared files remain intact. Pre-existing Content Workbench changes are unrelated and preserved. Changes remain local/uncommitted; this authorization did not request another publication.

## Persistence and compatibility

No save-version bump, new save store or new serialized run field. New generation activates reserved Elites; saved graphs keep their stored node types/topology and are not regenerated on load. Existing optional map/completion fields from Stage 15 and discovery behavior from Stage 16 remain authoritative. Existing v3 atomic save writes, recovery and pre-node/post-resolution safe points are retained. The native fixture enters via real map Travel and exercises production save boundaries; no mid-combat save is added.

## Validation

- `python3 tools/validate_project.py --allow-generated-cache`: passed, **254 named classes**, including after the final chapel change.
- `GODOT_BIN=/home/fluffy56/.local/bin/godot4 python3 -B tools/run_regression_suite.py`: **70/70 scripts passed**, exit 0; zero GDScript runtime/compile/parse errors. The suite's Stage 17 UI run had 97 checks before the final target-click assertion was added.
- `python3 -B -m unittest discover -s tools -p 'test_*.py'`: **13/13 passed**.
- Generated combat state: **3,849 checks, zero failures**, covering 100 seeded full graphs, supported party sizes, bindings, legacy graph restore and exactly-once outcomes.
- Preserved map checks in the full suite: Stage 15 state **1,453**, discovery UI **24**, Stage 16 navigation **100**, all zero failures.
- Final Stage 17 UI fixture, after the chapel correction and target-click assertion: **98/98 headless and 98/98 native**, exit 0.
- Final chapel follow-up: **6/6 scripts passed**, exit 0: spatial battle, spatial combat, position contacts, enemy AI, battlefield authoring and static PNG presentation. These checks cover the small authored placement adjustment made while the cumulative suite was running.
- Final `git diff --check` passes; changed-file/stat/full-diff review found no unrelated edits introduced by this stage.

The full development suite includes the unrelated Content Workbench test. Baseline ObjectDB/resource shutdown diagnostics remain, and invalid-save tests deliberately emit parse diagnostics. These are distinguished from GDScript runtime/compile/parse errors.

## Native QA and reproduction

Run `godot4 --path . --script tools/verify_generated_combat.gd -- --combat-captures=/tmp/ab-s17-verified-captures` with isolated XDG data/config/cache roots. It instantiates the production Main scene, clicks an actual reachable generated node and Travel, starts the existing encounter/order flow, then forces the outcome to exercise real victory/loot/defeat callbacks. It primes the preceding route as completed; it does not claim a manually played full campaign or a naturally won battle.

The fixture searches seeds 1–50 for real generated formations (Layer 1 trio at `l1_c4_n3`, Layer 1 pair at `l1_c4_n4`, Layer 2 pair at `l2_c2_n0` in the selected runs). Normal Layer 2 loot uses seed 333 and `l2_c1_n0`. Covered resolutions: 1920×1080, 1600×900, 1280×720 and 1024×768. Input includes mouse map travel/summary/target clicks and Escape/cancel/confirm on surplus loot. The defeat case departs through the real Refuge ownership boundary and checks the durable ended-run save.

Twenty final capture files were generated; seven inspected screenshots and seven validation logs are retained. Evidence captures and logs are retained in `docs/evidence/complete_ui_stage17/`. Visual review checks three-/two-/one-heroine presentation, corrected support visibility, outcome summaries, resolved map and defeat return. Normal-campaign play and physical-gamepad acceptance remain for the user.

## Failure provenance and remaining work

Earlier fixture failures came from an incompletely resolved starting node and comparing the emptied run equipment container after ownership had transferred to Refuge; fixtures were corrected to represent the actual lifecycle. The first added visibility assertion treated transparent heroine image padding as a visual obstruction; it was replaced with a production target-mode click test, while retaining the actual authored spawn correction found by screenshot review. No existing failing test was removed or weakened to hide a production regression.

An earlier native launch was rejected by automatic approval review because the account had reached a usage limit. The resumed request used the normal approval process and native execution succeeded. There is no remaining approval blocker.

No unresolved Stage 17 gameplay design blocker. Elite-specific item drops remain unauthored; existing reward behavior is used. Later Treasury, Trap, Rest and station activation stays gated. Next requested milestone would be Stage 18: Treasury authoring and saved room contents.

Suggested commit: `feat: activate generated Elite combat nodes and preserve encounter flows`.
