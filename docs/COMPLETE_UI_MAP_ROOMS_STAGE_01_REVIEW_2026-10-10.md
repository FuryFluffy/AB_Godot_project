# Stage 01 — Refuge room and contextual navigation

Completed implementation on 2026-10-10; final handoff checked 2026-10-11; **awaiting user verification**. Stage 02 has not started. Authorization was “good, proceed” after the Stage 00 audit commit `cdd0830`; “Resume from where you left” continued this stage. No Stage 01 commit or push has been made.

## Outcome and scope

The normal Refuge entry now presents the unchanged authored room, five separate supplied prop textures, eight polygon hotspots, and Bloom as the only persistent HUD value. Art and interaction geometry share one aspect-preserving 1344×768 transform. Mouse hover and keyboard/controller focus highlight the selected silhouette; mouse hover uses Godot tooltips. Transparent prop margins are not click targets. The Records cutout avoids the adjacent Loadouts rack.

Each hotspot opens one contextual panel, docked opposite its room position. Existing equipment, party ordering, inventory transfers, banked Materials, Key Chain, repair, salvage, and Layer 2 launch remain connected to their existing owners. Long pages scroll, input cannot pass through the panel, and focus stays inside it. Closing restores the opening hotspot. Equipment selectors, salvage confirmation, Settings, Load, and exit confirmations close before their parent. Escape cannot both close a station and open System. Controller Start accesses the same room/menu cancellation route; directional navigation uses the delivered spatial neighbors.

The system menu offers Save, Load, Main Menu, Settings, and Quit. Save calls the existing Refuge boundary writer. Load uses the same campaign-load path as Main Menu Load, including its existing active-descent abandonment behavior; the Load page explains this. Main Menu and Quit require their in-game confirmation. Settings reuse `UserSettingsStore`, with an additional Refuge interface scale from 1.0 to 1.3. Hidden Main Menu controls no longer consume gameplay Escape. The application’s permanent MAIN MENU button is hidden while Refuge is active.

Rest, Alchemy, Crafting, Records sections, Intel, and Level Up remain clearly unavailable. No shell charges or changes ownership. Companion interactions remain deferred. The old inventory/equipment/service controls are retained in compact pages: the final shared Backpack/Item Bar layout, exact-source Loadouts, Workbench redesign, production, recovery, Expedition hub, and Records are still their separate later stages. The development-only Layer 1 restart control remains in the scene but is hidden from the production room.

## Files and reused owners

| Files | Change |
| --- | --- |
| `scenes/refuge/bloom_refuge_screen.tscn` | Replace permanent dashboard with room shell and reusable authored service pages; preserve unique control names and handlers. |
| `scripts/refuge/ui/refuge_room_shell.gd` and `.uid` | Shared room fit, prop layering, station pages, modal input/focus, system menu, settings presentation. |
| `scripts/refuge/ui/refuge_room_hotspot.gd` and `.uid` | Polygon hit tests and hover/focus feedback. |
| `scripts/refuge/bloom_refuge_screen.gd` | Adapt existing management UI to the shell; nested cancellation and system intentions. |
| `scripts/refuge/ui/refuge_slot_grid.gd` | Clip long labels and allow equal-width cells in the compact page; quantities/selection/transactions unchanged. |
| `scripts/map/main_controller.gd` | Refuge visibility/system signals; delegate Save to `_save_active_refuge` and session actions to the application. |
| `scripts/app/application_root.gd` | Hide global chrome over Refuge; connect menu actions to existing application lifecycle. |
| `scripts/menu/main_menu_screen.gd` | Ignore Escape while hidden. |
| `scripts/save/user_settings_store.gd` | Optional persisted Refuge scale, default 1.0, clamped to 1.0–1.3; preserve it when Main Menu changes other settings. |
| `project.godot` | Explicitly select `gl_compatibility`, resolving the audited renderer discrepancy. Existing Workbench plugin setting is preserved. |
| `assets/refuge/props/{alchemy_apparatus,crafting_toolbox,expedition_map,repair_toolkit,weapon_stand}.png` and `.import` | Five byte-identical delivered props. Mipmap import/filtering prevents severe downscale shimmer. |
| `data/refuge/placement.json`, `data/refuge/hotspots.json` | Byte-identical delivered layout, polygons and directional neighbors. Geometry remains subject to player review. |
| `tests/test_refuge_management_ui.gd` | Retain service assertions; supersede five-tab expectation; add mouse, focus, nested cancellation, settings and production application/save/load integration checks. |
| `tools/preview_refuge_room.gd` and `.uid` | Runnable visual fixture; no campaign slot or launch connection. Capture mode renders fixed-size Godot SubViewports. |
| This report, `COMPLETE_UI_MAP_ROOMS_STAGE_LEDGER.md`, `docs/evidence/complete_ui_stage01/` | Handoff, results and selected actual Godot captures. Evidence directory has `.gdignore`. |

The transaction authorities remain `RefugeManagementController`, `RefugeOwnershipState`, `RunState`, and `CampaignSaveSlotStore`; none was replaced. Atomic writes, validation, backup recovery, safe points, stable IDs, seeded generation, registered-equipment protection, and return/defeat rules remain unchanged.

Unrelated existing Workbench changes remain uncommitted and untouched: `addons/`, its three content-authoring documents, `tests/test_content_workbench.gd`/`.uid`, and its added entry in `tools/run_regression_suite.py`. The already-modified `project.godot` retains that plugin entry alongside this stage’s renderer addition.

## Compatibility and assets

No campaign migration, envelope-version change, new economy values, recipes, room activation or gameplay mutation policy. Saves remain envelope v3. Existing settings version 1 files without `refuge_ui_scale` load at 1.0. Main Menu settings updates retain the new optional value.

The original background is unchanged:

`assets/backgrounds/layer_2/sdxl_curated/07_Bloom_Refuge_Transformed.png`

SHA-256: `2ecc1b1705148364aa2789734bbd0922a4329a2d70300db3054412d9a53f82f1`.

All five copied PNG hashes match the source package, as do both layout JSON files. Supplied reference images are not used as runtime UI or economy data.

## Executed checks

| Command/check | Exact result |
| --- | --- |
| `python3 tools/validate_project.py --allow-generated-cache` | Exit 1, exactly the same 24 diagnostics as Stage 00; final log byte-identical to the baseline. |
| `python3 tools/run_regression_suite.py` | Exit 1 at its validator prerequisite; no claim that the gated runner passes. |
| All 48 current `TESTS` entries, invoked independently as `godot4 --headless --path <repo> --script res://<test>` with a fresh `isolated_godot_environment()` per process | **48/48 exit 0, zero SCRIPT ERROR reports.** Results and durations in `evidence/complete_ui_stage01/direct_results.json`. |
| Expanded Refuge UI test, rerun after final navigation/settings/scene changes | Exit 0: `Refuge management UI tests passed.` Final evidence in `final_ui.log`. |
| `python3 tools/test_run_regression_suite.py` | **4 tests passed**, exit 0. An initial module-style invocation used the wrong Python import path; rerunning the file directly resolved that invocation error. |
| `godot4 --headless --path . --editor --import` | Exit 0; new scripts and textures imported. Sandbox editor-listener socket diagnostics remain environmental. |
| Actual graphical Godot review fixture | Exit 0; **36 successful fixed-size captures**: room, focus, eight stations, System and Settings at 1280×720, 1920×1080 and 1024×768. |
| `git diff --check` and review of full changed source/scene diff | Clean whitespace; changes reviewed against this stage and existing dirty Workbench files. |

The 24 structural failures are the already documented Quiet Cell Blanket canonical flag, twenty room-identity diagnostics, two registry order/ID diagnostics, and the aggregate background mapping diagnostic. They are unchanged and were not repaired as unrelated Stage 01 work.

Existing teardown diagnostics remain: common ObjectDB/resource-use warnings; the Refuge UI script reports 27 ObjectDB instances/24 resources at exit (same class of pre-existing fixture cleanup warnings); corruption/recovery tests intentionally log their existing malformed-JSON cases. These are recorded, not represented as clean logs. No new GDScript parse/runtime errors were observed.

The focused additions verify all eight stations through synthesized viewport mouse events, no panel click-through, spatial Right/Accept, Tab confinement, single-Escape consumption, origin restoration, nested Settings/selector/salvage cancellation, unchanged ownership while browsing, UI-scale persistence without art movement, exact production Save/Load wallet restoration, Main Menu confirmation cancellation/acceptance, and absence of application chrome. Application Save/Load uses a dedicated test directory; settings tests restore the previous file. All task executions used isolated XDG data/config/cache directories.

## Rendered evidence and remaining manual QA

Graphical runs used Godot `4.7.2.stable.official.ed1daf0bf`, OpenGL 4.6 / **Compatibility**, Mesa Intel Iris Xe. Unlike Stage 00’s sandbox-only attempt, a display-authorized isolated fixture successfully rendered. Fixed-size SubViewports avoid window-manager resizing ambiguity. PNG dimensions were checked. The last screenshot refresh initially hit an automatic permission-review timeout; its permitted retry succeeded with exit 0 and all 36 captures refreshed. These are engine renders of the actual scene, not browser previews.

Selected retained captures:

- [Default room, 1280×720](evidence/complete_ui_stage01/1280x720_room.png)
- [Records focus silhouette, 1280×720](evidence/complete_ui_stage01/1280x720_focus.png)
- [Working service panel, 1280×720](evidence/complete_ui_stage01/1280x720_repair.png)
- [Compact Stash, 1024×768](evidence/complete_ui_stage01/1024x768_stash.png)
- [System menu, 1920×1080](evidence/complete_ui_stage01/1920x1080_system.png)

Visual inspection covered the room, props, focus outline, Stash, Loadouts, Workbench, Expedition, Rest and Settings across these captures; filtering and panel opacity were corrected after inspection. Full captures and raw logs are also under `/tmp/ab_stage01_evidence/`. The reviewed fixture uses canonical battler starting values and default ownership. It does not prove a newly played campaign, physical controller behavior, or a human mouse-hover/tooltip timing check. The fixture’s Save/Load/Main Menu/Quit actions are disabled without the application connection; normal campaign integration is covered by the separate application test. Fixture launch is disabled.

### Runnable entry and short player checklist

Normal entry: start the project’s `scenes/app/application_root.tscn`, then Main Menu Load an established Refuge campaign, or reach Refuge through normal play. No new debug shortcut is added to the production menu.

For isolated room review from the repository directory:

```bash
stage01_review_dir="$(mktemp -d /tmp/ab-refuge-review.XXXXXX)"
XDG_DATA_HOME="$stage01_review_dir/data" XDG_CONFIG_HOME="$stage01_review_dir/config" XDG_CACHE_HOME="$stage01_review_dir/cache" godot4 --path . --script res://tools/preview_refuge_room.gd
```

1. Confirm the room shows only Bloom; hover the bed, chest, toolbox, apparatus, repair kit, rack, books and map. Check highlights/tooltips and the Books/Rack boundary.
2. Open all eight stations; close each and check originating focus. Resize and check art/hotspot alignment. Check long pages by scrolling.
3. Use arrows/D-pad, Accept, Tab and Cancel. From the bare room, Escape/Start opens System. One Cancel closes only the topmost selector, confirmation or page.
4. In a normal campaign, exercise an existing transfer, repair and salvage cancellation/confirmation. Check quantities, instance condition and status feedback.
5. In System, test Save/Load, Settings/scale, and cancellation of Main Menu/Quit. Confirm no permanent MAIN MENU button overlays Refuge. Check the normal Layer 2 launch/return entry.
6. Confirm unavailable services cannot execute or charge anything. Review the proposed hotspot geometry and readability with a physical controller before accepting the stage.

## Blockers and next stage

No unresolved gameplay rule blocks Stage 01. User visual/input verification remains pending; the unrelated structural gate remains red. Later service prices, recipe/recovery mappings and final station layouts remain at their designated stages.

After verification/continue, **Stage 02** is shared inventory views and ownership mapping: the reusable fifteen-slot Backpack, six-slot Item Bar, Key-ring and Materials presentation, before Stage 03’s transaction changes. Do not implement Stage 02 until authorized.

Suggested commit message: `feat: add spatial Refuge room and contextual station menus`.
