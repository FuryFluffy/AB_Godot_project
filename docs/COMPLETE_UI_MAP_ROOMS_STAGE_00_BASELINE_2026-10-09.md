# Stage 00 baseline evidence — 2026-10-09

These checks ran against the existing local checkout, including the pre-existing Content Workbench changes. Stage 00 adds documentation only. Passing old behavior tests does not certify the consolidated future-stage requirements.

## Commands and exits

| Command | Result |
| --- | --- |
| `godot4 --version` | `4.7.2.stable.official.ed1daf0bf`, exit 0 |
| `python3 tools/validate_project.py --allow-generated-cache` | Exit 1, 24 diagnostics below |
| `python3 tools/run_regression_suite.py` | Exit 1 at the same structural prerequisite; did not execute Godot tests |
| `PYTHONDONTWRITEBYTECODE=1 python3 tools/test_run_regression_suite.py` | Exit 0, 4 tests passed |
| Direct current `TESTS` list, each with isolated XDG directories | 48/48 passed, all exit 0 |
| `godot4 --headless --path <project> --quit-after 5`, isolated XDG | Exit 0; cleanup warnings below |
| `godot4 --path <project> --quit-after 5`, isolated XDG | Exit 1; no X11/Wayland display |
| `godot4 --headless --path <project> --script /tmp/ab_stage00_evidence/audit_probe.gd`, isolated XDG | Exit 0, renderer/12 graphs/two Elite branches below |
| SHA-256 check against extracted root manifest | 124/124 entries match |

No editor import, user save, renderer setting or graphical interaction was changed for these checks. Tests use the repository's existing import cache and fresh temporary user/config/cache roots for each process. The Content Workbench test creates and cleans its own inactive test draft.

## Direct-script reproduction

From the project root, the executed harness imported the runner's existing `TESTS` and `isolated_godot_environment`, ran the following command for each entry with a 180-second timeout, captured stdout/stderr to a separate log, and recorded each return code. This bypasses only the blocked runner prerequisite for diagnosis; it does not make structural validation green.

```python
import importlib.util
import subprocess

spec = importlib.util.spec_from_file_location("runner", "tools/run_regression_suite.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
failed = []
for test in runner.TESTS:
    with runner.isolated_godot_environment() as environment:
        result = subprocess.run(
            ["/home/fluffy56/.local/bin/godot4", "--headless", "--path",
             str(runner.ROOT), "--script", "res://" + test],
            env=environment, timeout=180,
        )
    if result.returncode:
        failed.append(test)
print(f"{len(runner.TESTS) - len(failed)}/{len(runner.TESTS)} passed; failures={failed}")
raise SystemExit(bool(failed))
```

All 48 logs contain their script's success summary, with no `SCRIPT ERROR` lines. The corruption tests print expected invalid-JSON errors. Several tests report shutdown leaks; these remain baseline diagnostics, not ignored evidence of a clean shutdown.

| Script under `tests/` | Exit | Actual success summary |
| --- | --- | --- |
| `test_content_workbench.gd` | 0 | Content Workbench: 308 checks, 0 failures. |
| `test_combat_kernel.gd` | 0 | Combat kernel tests passed. |
| `test_battle_flow.gd` | 0 | Battle flow tests passed. |
| `test_spatial_battle.gd` | 0 | Spatial battle tests passed. |
| `test_spatial_combat.gd` | 0 | Spatial combat integration tests passed. |
| `test_position_contacts.gd` | 0 | Position contact adjacency tests passed. |
| `test_enemy_ai.gd` | 0 | Enemy AI rulebook tests passed. |
| `test_ordinary_combat.gd` | 0 | Ordinary combat completion tests passed. |
| `test_board_interaction.gd` | 0 | Board interaction tests passed. |
| `test_cancel_input_routing.gd` | 0 | Central cancel-input routing tests passed. |
| `test_grapple_foundation.gd` | 0 | Grapple foundation tests passed. |
| `test_grapple_move_reactions.gd` | 0 | Grapple Move Reaction tests passed. |
| `test_item_system.gd` | 0 | Item and run inventory state tests passed. |
| `test_canonical_item_ids.gd` | 0 | Canonical item Stable-ID tests passed. |
| `test_reward_sources.gd` | 0 | Deterministic reward-source and routing tests passed. |
| `test_item_sprite_library.gd` | 0 | Stable-ID item sprite library tests passed. |
| `test_node_map.gd` | 0 | Layer 1 Node Map tests passed. |
| `test_layer_room_registry.gd` | 0 | Layer 1–2 room registry tests passed. |
| `test_registered_room_presentations.gd` | 0 | Registered room presentation tests passed. |
| `test_layer_generator_activation.gd` | 0 | Layer 1–2 generator activation tests passed. |
| `test_opening_event_room_flow.gd` | 0 | Opening and Event-room flow tests passed. |
| `test_dialogue_foundation.gd` | 0 | Dialogue foundation regression tests passed. |
| `test_production_dialogue_authoring.gd` | 0 | Production dialogue authoring tests passed. |
| `test_layer1_novel_integration.gd` | 0 | Layer 1 novel integration tests passed. |
| `test_layer_transition.gd` | 0 | Layer 1 to Layer 2 transition tests passed. |
| `test_jailer_refuge_origin.gd` | 0 | Immediate Jailer and Bloom Refuge origin tests passed. |
| `test_bloom_refuge_hub.gd` | 0 | Bloom Refuge hub and campaign-boundary tests passed. |
| `test_production_save_slots.gd` | 0 | Production campaign save-slot tests passed. |
| `test_active_run_safe_points.gd` | 0 | Active-run safe-point tests passed. |
| `test_campaign_lifecycle.gd` | 0 | Campaign lifecycle and seed-scope tests passed. |
| `test_l1_l2_demo_flow.gd` | 0 | Layer 1 to reverse Layer 2 demo-flow tests passed. |
| `test_layer_2_first_slice.gd` | 0 | Layer 2 first playable slice tests passed. |
| `test_heroine_kits.gd` | 0 | Starting party kit tests passed. |
| `test_ability_resources.gd` | 0 | Ability Resource tests passed. |
| `test_weapon_resources.gd` | 0 | Weapon Resource tests passed. |
| `test_refuge_salvage_recipes.gd` | 0 | Refuge Material, salvage, and recipe tests passed. |
| `test_refuge_management_ui.gd` | 0 | Refuge management UI tests passed. |
| `test_weapon_techniques.gd` | 0 | Weapon technique and progression tests passed. |
| `test_layer_1_enemy_roster.gd` | 0 | Layer 1 enemy roster tests passed. |
| `test_combat_hud.gd` | 0 | Combat HUD tests passed. |
| `test_reusable_merge.gd` | 0 | Reusable merge tests passed. |
| `test_encounter_startup.gd` | 0 | Encounter startup test passed. |
| `test_battle_composition.gd` | 0 | Battle Composition tests passed. |
| `test_battlefield_authoring.gd` | 0 | Visual Battlefield Authoring tests passed. |
| `test_battler_visual_profiles.gd` | 0 | Battler Visual Profile tests passed. |
| `test_static_png_combat_presentation.gd` | 0 | Static-PNG combat presentation tests passed. |
| `test_combat_stage_triggers.gd` | 0 | Combat-stage trigger lifecycle tests passed. |
| `test_milestone_15_pilot_a.gd` | 0 | Milestone 15 Pilot A integration tests passed. |

## Diagnostic provenance

The 24 structural messages below reproduce the September checkpoint's failure families. The background aggregate contains 22 filenames in the actual output, rather than the 21 stated in the older Workbench handoff. Current tests read the Resource defaults/links successfully, while this structural check reports serialization/content-contract discrepancies. This audit does not repair either validator or content to force a pass.

```text
Project validation failed:
- /home/fluffy56/Desktop/abyssal_bloom_item_sprites_l1_l2_room_registry_2026-08-21_GODOT_4_7/data/items/layer_2/quiet_cell_blanket.tres: legacy Quiet Cell Blanket must contain canonical_workbook_item = false
- /home/fluffy56/Desktop/abyssal_bloom_item_sprites_l1_l2_room_registry_2026-08-21_GODOT_4_7/data/rooms/layer_1/01_opening_servant_corridor.tres: incomplete Layer room identity
- /home/fluffy56/Desktop/abyssal_bloom_item_sprites_l1_l2_room_registry_2026-08-21_GODOT_4_7/data/rooms/layer_1/02_servant_ledger_alcove.tres: incomplete Layer room identity
- /home/fluffy56/Desktop/abyssal_bloom_item_sprites_l1_l2_room_registry_2026-08-21_GODOT_4_7/data/rooms/layer_1/03_wine_cellar_warm_bottles.tres: incomplete Layer room identity
- /home/fluffy56/Desktop/abyssal_bloom_item_sprites_l1_l2_room_registry_2026-08-21_GODOT_4_7/data/rooms/layer_1/04_servant_dormitory.tres: incomplete Layer room identity
- /home/fluffy56/Desktop/abyssal_bloom_item_sprites_l1_l2_room_registry_2026-08-21_GODOT_4_7/data/rooms/layer_1/05_ruined_confessional.tres: incomplete Layer room identity
- /home/fluffy56/Desktop/abyssal_bloom_item_sprites_l1_l2_room_registry_2026-08-21_GODOT_4_7/data/rooms/layer_1/06_coat_beside_service_door.tres: incomplete Layer room identity
- /home/fluffy56/Desktop/abyssal_bloom_item_sprites_l1_l2_room_registry_2026-08-21_GODOT_4_7/data/rooms/layer_1/07_ruined_chapel.tres: incomplete Layer room identity
- /home/fluffy56/Desktop/abyssal_bloom_item_sprites_l1_l2_room_registry_2026-08-21_GODOT_4_7/data/rooms/layer_1/08_blood_nun_processing_chapel.tres: incomplete Layer room identity
- /home/fluffy56/Desktop/abyssal_bloom_item_sprites_l1_l2_room_registry_2026-08-21_GODOT_4_7/data/rooms/layer_1/10_cold_pantry.tres: incomplete Layer room identity
- /home/fluffy56/Desktop/abyssal_bloom_item_sprites_l1_l2_room_registry_2026-08-21_GODOT_4_7/data/rooms/layer_1/11_linen_sorting_room.tres: incomplete Layer room identity
- /home/fluffy56/Desktop/abyssal_bloom_item_sprites_l1_l2_room_registry_2026-08-21_GODOT_4_7/data/rooms/layer_1/12_bell_pull_gallery.tres: incomplete Layer room identity
- /home/fluffy56/Desktop/abyssal_bloom_item_sprites_l1_l2_room_registry_2026-08-21_GODOT_4_7/data/rooms/layer_1/13_butlers_office.tres: incomplete Layer room identity
- /home/fluffy56/Desktop/abyssal_bloom_item_sprites_l1_l2_room_registry_2026-08-21_GODOT_4_7/data/rooms/layer_1/14_dishwashing_hall.tres: incomplete Layer room identity
- /home/fluffy56/Desktop/abyssal_bloom_item_sprites_l1_l2_room_registry_2026-08-21_GODOT_4_7/data/rooms/layer_1/15_service_stair_landing.tres: incomplete Layer room identity
- /home/fluffy56/Desktop/abyssal_bloom_item_sprites_l1_l2_room_registry_2026-08-21_GODOT_4_7/data/rooms/layer_1/16_wax_prep_room.tres: incomplete Layer room identity
- /home/fluffy56/Desktop/abyssal_bloom_item_sprites_l1_l2_room_registry_2026-08-21_GODOT_4_7/data/rooms/layer_1/17_abandoned_guest_bedroom.tres: incomplete Layer room identity
- /home/fluffy56/Desktop/abyssal_bloom_item_sprites_l1_l2_room_registry_2026-08-21_GODOT_4_7/data/rooms/layer_1/18_laundry_boiler_room.tres: incomplete Layer room identity
- /home/fluffy56/Desktop/abyssal_bloom_item_sprites_l1_l2_room_registry_2026-08-21_GODOT_4_7/data/rooms/layer_1/19_dining_service_hall.tres: incomplete Layer room identity
- /home/fluffy56/Desktop/abyssal_bloom_item_sprites_l1_l2_room_registry_2026-08-21_GODOT_4_7/data/rooms/layer_1/20_sorting_vestibule.tres: incomplete Layer room identity
- /home/fluffy56/Desktop/abyssal_bloom_item_sprites_l1_l2_room_registry_2026-08-21_GODOT_4_7/data/rooms/layer_2/01_offering_list_room.tres: incomplete Layer room identity
- Layer 1 room registry order/IDs differ from the canonical twenty-room list
- Layer 2 room registry order/IDs differ from the canonical twenty-room list
- delivered L1–2 backgrounds absent from the room registry: 01_Opening_Servant_Corridor.png, 02_Servant_Ledger_Alcove.png, 03_Servant_Dormitory.png, 04_Wine_Cellar_of_Warm_Bottles.png, 06_Cold_Pantry.png, 07_Linen_Sorting_Room.png, 08_Dishwashing_Hall.png, 09_Butlers_Office.png, 10_Service_Stair_Landing.png, 11_Bell_Pull_Gallery.png, 12_Coat_Beside_the_Service_Door.png, 13_Wax_Preparation_Room.png, 14_Abandoned_Guest_Bedroom.png, 15_Ruined_Confessional.png, 16_Laundry_Boiler_Room.png, 17_Dining_Service_Hall.png, 18_Sorting_Vestibule.png, 19_Ruined_Chapel_Exploration.png, 20_Ruined_Chapel_Battle.png, 21_Blood_Nun_Processing_Chapel.png, 01_Offering_List_Room.png
```

Python runner output:

```text
Godot import/class cache is absent; bootstrapping the project editor.
....
----------------------------------------------------------------------
Ran 4 tests in 0.004s

OK
```

Headless application startup:

```text
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

WARNING: 5 ObjectDB instances were leaked at exit (run with `--verbose` for details).
   at: cleanup (core/object/object.cpp:2536)
ERROR: 3 resources still in use at exit (run with --verbose for details).
   at: clear (core/io/resource.cpp:822)
```

Graphical application startup (not graphical QA):

```text
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
ERROR: X11 Display is not available
   at: DisplayServerX11 (platform/linuxbsd/x11/display_server_x11.cpp:6943)
WARNING: Display driver x11 failed, falling back to wayland.
     at: setup2 (main/main.cpp:3380)
ERROR: Can't connect to a Wayland display.
   at: init (platform/linuxbsd/wayland/wayland_thread.cpp:5589)
ERROR: Could not initialize the Wayland thread.
   at: DisplayServerWayland (platform/linuxbsd/wayland/display_server_wayland.cpp:2296)
ERROR: Can't create the Wayland display server.
   at: create_func (platform/linuxbsd/wayland/display_server_wayland.cpp:2264)
ERROR: Unable to create DisplayServer, all display drivers failed.
Use "--headless" command line argument to run the engine in headless mode if this is desired (e.g. for continuous integration).
   at: setup2 (main/main.cpp:3390)
WARNING: 6 ObjectDB instances were leaked at exit (run with `--verbose` for details).
     at: cleanup (core/object/object.cpp:2536)
```

The cancel-input test also reports 28 resources and four shaped-text RID allocations still in use; the Refuge management UI test reports 24 resources. Other test cleanup counts vary. Both save-corruption suites print `Parse JSON failed. Error at line 0: Expected key` while their corruption/recovery assertions pass. No shutdown cleanup fix is included.

## Read-only runtime audit probe

The temporary probe initializes no campaign save and changes no project files. It reads the effective renderer setting, generates two layers for six fixed seeds, counts non-START nodes and non-START/non-BOSS degree-one nodes, runs the current generator validator, and directly invokes the existing Elite composition helper. This does not prove the full Elite encounter plays correctly with every party size.

```gdscript
extends SceneTree

func _init() -> void:
	print("AUDIT_RENDERER_SETTING=", ProjectSettings.get_setting("rendering/renderer/rendering_method", "<unset>"))
	print("AUDIT_RENDERER_SETTING_OVERRIDE=", ProjectSettings.get_setting_with_override("rendering/renderer/rendering_method"))
	print("AUDIT_FEATURES=", ProjectSettings.get_setting("application/config/features"))
	var generator := LayerMapGenerator.new()
	for seed_value: int in [1, 111, 222, 333, 8128, 27072026]:
		for layer: int in [1, 2]:
			var graph: LayerMapGraph = generator.generate_layer_1(seed_value) if layer == 1 else generator.generate_layer_2_run(seed_value)
			var counts: Dictionary = {}
			var dead_ends: int = 0
			for value: Variant in graph.nodes.values():
				var node := value as MapNodeState
				counts[node.get_type_label()] = int(counts.get(node.get_type_label(), 0)) + 1
				if node.node_type != MapNodeState.NodeType.START and node.node_type != MapNodeState.NodeType.BOSS and node.incoming_ids.size() + node.outgoing_ids.size() == 1:
					dead_ends += 1
			print("AUDIT_GRAPH ", JSON.stringify({"seed": seed_value, "layer": layer, "playable": graph.nodes.size()-1, "counts": counts, "non_start_non_boss_dead_ends": dead_ends, "validation": generator.validate_generated_layer(graph)}))
	var node := MapNodeState.new()
	node.node_type = MapNodeState.NodeType.ELITE
	var run := RunState.new()
	print("AUDIT_ELITE_EVEN=", run._make_enemy_composition(node, 2))
	print("AUDIT_ELITE_ODD=", run._make_enemy_composition(node, 3))
	quit()
```

Output:

```text
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

AUDIT_RENDERER_SETTING=forward_plus
AUDIT_RENDERER_SETTING_OVERRIDE=forward_plus
AUDIT_FEATURES=["4.7", "GL Compatibility"]
AUDIT_GRAPH {"counts":{"Battle":2,"Boss":1,"Room":7,"Start":1},"layer":1,"non_start_non_boss_dead_ends":0,"playable":10,"seed":1,"validation":""}
AUDIT_GRAPH {"counts":{"Battle":1,"Boss":1,"Room":10,"Start":1},"layer":2,"non_start_non_boss_dead_ends":0,"playable":12,"seed":1,"validation":""}
AUDIT_GRAPH {"counts":{"Battle":2,"Boss":1,"Room":8,"Start":1},"layer":1,"non_start_non_boss_dead_ends":0,"playable":11,"seed":111,"validation":""}
AUDIT_GRAPH {"counts":{"Battle":1,"Boss":1,"Room":10,"Start":1},"layer":2,"non_start_non_boss_dead_ends":0,"playable":12,"seed":111,"validation":""}
AUDIT_GRAPH {"counts":{"Battle":2,"Boss":1,"Room":8,"Start":1},"layer":1,"non_start_non_boss_dead_ends":0,"playable":11,"seed":222,"validation":""}
AUDIT_GRAPH {"counts":{"Battle":1,"Boss":1,"Room":9,"Start":1},"layer":2,"non_start_non_boss_dead_ends":0,"playable":11,"seed":222,"validation":""}
AUDIT_GRAPH {"counts":{"Battle":2,"Boss":1,"Room":8,"Start":1},"layer":1,"non_start_non_boss_dead_ends":0,"playable":11,"seed":333,"validation":""}
AUDIT_GRAPH {"counts":{"Battle":1,"Boss":1,"Room":10,"Start":1},"layer":2,"non_start_non_boss_dead_ends":0,"playable":12,"seed":333,"validation":""}
AUDIT_GRAPH {"counts":{"Battle":2,"Boss":1,"Room":7,"Start":1},"layer":1,"non_start_non_boss_dead_ends":0,"playable":10,"seed":8128,"validation":""}
AUDIT_GRAPH {"counts":{"Battle":1,"Boss":1,"Room":9,"Start":1},"layer":2,"non_start_non_boss_dead_ends":0,"playable":11,"seed":8128,"validation":""}
AUDIT_GRAPH {"counts":{"Battle":2,"Boss":1,"Room":9,"Start":1},"layer":1,"non_start_non_boss_dead_ends":0,"playable":12,"seed":27072026,"validation":""}
AUDIT_GRAPH {"counts":{"Battle":1,"Boss":1,"Room":8,"Start":1},"layer":2,"non_start_non_boss_dead_ends":0,"playable":10,"seed":27072026,"validation":""}
AUDIT_ELITE_EVEN=[&"red_wax_acolyte", &"hollow_servant"]
AUDIT_ELITE_ODD=[&"hollow_servant", &"knife_footman", &"prayer_rag_novice"]
WARNING: 5 ObjectDB instances were leaked at exit (run with `--verbose` for details).
   at: cleanup (core/object/object.cpp:2536)
ERROR: 3 resources still in use at exit (run with --verbose for details).
   at: clear (core/io/resource.cpp:822)
```

`GL Compatibility` is only the configured feature label here; the effective setting returned `forward_plus`. Headless mode uses no normal graphical display, and the graphical launch could not connect to one, so the active rendered backend was not verified. Proposed later renderer correction requires preserving the uncommitted plugin setting.

## Package integrity and evidence retention

```json
{
  "entries": 124,
  "mismatches": [],
  "zip_sha256": "d4953693878099a5a29d447c2f5a3611a969aab19f45c0ede5466a820be3099b"
}
```

Extracted handoff: `/tmp/ab_complete_ui_handoff_2026-10-09/AB_Complete_UI_Map_and_Rooms_v1`.
Original archive: `/home/fluffy56/Downloads/AB_Complete_UI_Map_and_Rooms_v1.zip`.
Raw per-script logs and result JSON: `/tmp/ab_stage00_evidence/` (temporary; may be removed by system cleanup). The durable test summaries, important diagnostics, probe source and output are included in this document. The ZIP itself remains the source for re-extraction.

## Verification boundary

No normal campaign path was manually played in Stage 00. No native UI screenshot or particle recording was captured. Existing automated fixtures cover campaign state transitions, reverse Layer 2, boss permanence, inventory/loss/banking, rewards and saves; new UI/map/room behavior remains unimplemented and untested. Reference images were visually inspected as design inputs, not runtime evidence.

Final documentation review: structural validation after writing the documents again returned exit 1 with output byte-for-byte identical to the baseline's 24 diagnostics. `git diff --check` returned exit 0. `git diff --stat` and the full tracked diff still show only the user's pre-existing project/plugin and runner changes (two files, five added lines). The three new untracked Markdown documents were reviewed separately, including `git diff --no-index --check /dev/null <document>`: no whitespace diagnostics (exit 1 denotes the new-file difference). Final status contains the original Workbench changes plus these three documents only. No test expectation was edited.
