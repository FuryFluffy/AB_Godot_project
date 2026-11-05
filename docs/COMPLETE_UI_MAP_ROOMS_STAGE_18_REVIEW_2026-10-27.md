# Stage 18 — Treasury authoring and saved room contents

Authorization: after Stage 17 the user said “Good, proceed” and later resumed this task. The supplied package defines the two rooms and persistence contract. It does not supply reward tables or cache discovery rules. The user's explicit content decision was: **“Author modest seeded rewards from existing items and Materials, with caches revealed by inspecting their location.”** This decision authorizes the tables below and inspection behavior.

## Delivered behavior

New full Layer 1/2 maps activate one or two reserved Treasury positions. Layer 1 uses Servants' Storehouse; Layer 2 uses Confiscated Belongings Store. Both use the supplied backgrounds unchanged, with separate runtime collectible sprites, container hotspots, and an open passage. Existing story gates, encounters, material sources, map budgets, stable node IDs and deterministic content seeds are preserved. The forty-entry registration catalog is unchanged. Trap, Rest and field station reservations remain inactive.

Each room draws six seeded records: two visible items, two coffer contents, one drawer content and one concealed floor-cache content. Containers reuse the Stage 12 Loot/Backpack transaction controller. Closing, partial collection, full backpacks, leaving, revisiting and production save/load preserve exact remaining quantities. Only successfully exhausted visible pickups disappear. Material collection uses the existing run Materials route.

Inspecting the authored floor location reveals its cache and opens its contents. Before inspection its hover label names the ordinary surface, without reward names or counts. Hidden remaining content prevents Solved; the map does not disclose secret counts or locations. Solved publishes through the existing room outcome after all six records are exhausted. Opening a container or simply leaving the room does not solve it.

Background, runtime items and hit areas share one uniform transform fitted above the exploration dock. Source coordinates are 1659×948; no stretching or cropping is applied. Hotspot proposals were visually checked against the backgrounds, then authored as scene anchors/collision shapes. Collectible rewards remain separate from painted furniture. The generic container supports an optional existing room-lock ID; these two rooms use hidden caches and open exits, without adding a new key or lock economy.

## Authored reward tables

Each row lists the quantity per draw and raw weight. Six draws allow repeated entries. Existing resolver rules multiply current-layer entry weights by three; this is unchanged. Layer 2's Layer 1 bandage entry retains its raw weight. There is no guaranteed item, additional Bloom grant or separate first-clear reward.

| Layer | Existing stable item ID | Quantity | Raw weight |
| --- | --- | ---: | ---: |
| 1 | `l01_bandage_roll` | 2 | 3 |
| 1 | `l01_servants_tonic` | 1 | 2 |
| 1 | `l01_smelling_salts` | 1 | 2 |
| 1 | `mat_l01_red_wax` | 2 | 3 |
| 1 | `mat_l01_servant_cloth` | 2 | 3 |
| 2 | `l02_chain_oil` | 1 | 1 |
| 2 | `l02_bitter_wakefulness_tonic` | 1 | 1 |
| 2 | `l01_bandage_roll` | 2 | 3 |
| 2 | `mat_l02_chain_links` | 2 | 3 |
| 2 | `mat_l02_prison_iron` | 2 | 3 |

No item definitions, equipment, recipes, salvage mappings or narrative canon were added. These small editable tables implement the user's authorized content approach; normal play remains the next balance acceptance step.

## Changed files

- `assets/exploration/treasuries/`: two approved background PNGs and their import settings.
- `scenes/exploration/rooms/layer1/l1_treasury_servants_storehouse.tscn` and `layer2/l2_treasury_confiscated_belongings.tscn`: authored item, container, cache and exit geometry.
- Matching definitions under `data/exploration/rooms/layer1/` and `layer2/`, plus `event_room_catalog.tres` registration.
- `data/exploration/item_pools/treasury_layer_1.tres`, `treasury_layer_2.tres`, matching files in `loot_sources/` and `loot_profiles/`, and `data/rewards/reward_source_catalog.tres` registration.
- `scripts/exploration/interactions/room_loot_container_hotspot.gd`: reusable presentation/intent component.
- `scripts/exploration/items/room_item_spawn_anchor.gd`: optional stable container binding.
- `scripts/exploration/event_room_definition.gd`, `event_room_instance_state.gd`, `event_room_screen.gd`: opt-in fitting/completion, validated discovery state, container collection and persisted-empty generation guard.
- `scripts/map/layer_map_generator.gd`, `map_node_state.gd`, `main_controller.gd`, `run_state.gd`: Treasury activation/entry, generic known-node description and transactional restore validation.
- `tests/test_treasury_rooms.gd`, `tests/test_treasury_ui.gd`, `tools/verify_treasuries.gd` and UIDs; registrations in `tools/run_regression_suite.py`. Stage 17's `test_generated_combat_nodes.gd` now allows this explicitly authorized Treasury activation while retaining later-stage guards.
- `docs/design/complete_ui_map_rooms_v1/hotspot_anchor_proposals.json`: retained original proposals; this review, stage ledger and `docs/evidence/complete_ui_stage18/`.

Earlier Stage 15–17 changes in shared files and unrelated Content Workbench changes remain intact. This stage is local/uncommitted.

## Persistence and compatibility

No save-version bump or destructive migration. Optional `container_id` is stored on existing item assignment records; optional `revealed_containers` lives inside existing room `local_state`. Missing discovery defaults to an empty dictionary. Explicit malformed new values reject before restore commits. Item identities, quantities, resolution seeds and claims continue to use the existing RewardSourceResolver/LootClaim contract.

An existing `item_spawns` list is authoritative even when empty, preventing a new reward roll on reopening. New maps activate Treasuries; old saved graphs retain their stored node types and topology. The production v3 atomic slot store, validation, backups and recovery remain unchanged. Collection does not create mid-room saves: interruption resumes the existing pre-node safe point; normal exit writes the post-resolution safe point with remaining room contents and inventory together.

## Validation

- `GODOT_BIN=/home/fluffy56/.local/bin/godot4 python3 -B tools/run_regression_suite.py`: **72/72 scripts passed**, exit 0; zero GDScript parse/compile/runtime diagnostics. This run includes the original 73-check Treasury UI fixture.
- `python3 tools/validate_project.py --allow-generated-cache`: passed, **255 named GDScript classes**.
- Python tooling: **13/13 tests passed**.
- Treasury state: **1,012 checks, zero failures**, including 200 generated layers, deterministic contents, content validation, compatibility and malformed discovery state.
- Stage 17 generated combat state against Treasury activation: **3,849 checks, zero failures**.
- Final headless/native Treasury UI: **75/75 each**, exit 0, including two additional explicitly empty saved-list checks. Production code was unchanged after the full suite started.
- Preserved full-suite checks: Stage 15 state **1,453**, discovery UI **24**, Stage 16 navigation **100**, Stage 17 UI **98**, all zero failures.
- Final `git diff --check`, stat and full-diff review completed; unrelated Workbench edits and previous stages preserved.

The development suite includes the unrelated Content Workbench test. Known ObjectDB/resource shutdown diagnostics and deliberate invalid-save JSON diagnostics are retained in logs and distinguished from GDScript parse/compile/runtime errors.

## Native QA and reproduction

Run `godot4 --path . --script tools/verify_treasuries.gd -- --treasury-captures=/tmp/ab-s18-captures` with isolated XDG data/config/cache directories. The fixture instantiates production Main, travels through the map into actual generated Treasuries at seed 333 (`l1_c3_n3`, `l2_c4_n2`), opens coffers with mouse clicks, closes with Escape, clicks cache locations and exits, and reads/restores the real production save document. The preceding route is primed. Full backpack contents are injected solely for capacity coverage; authored rewards are not replaced. Collection calls the production transaction API rather than simulating every drag or context-menu click.

Native checks cover 1920×1080, 1600×900, 1280×720 and 1024×768, container source rows, whole-room fit, closed-window preservation, partial claims, refused pickup, discovery, Solved and exhausted revisits. Twenty screenshots were generated. Six room, coffer, cache and solved-map screenshots were visually reviewed and retained with seven validation logs. Both background files were also byte-compared successfully with the supplied ZIP. The later empty-list assertion changes only the fixture, not presentation.

This is native scripted QA plus manual screenshot inspection, not a manually played complete campaign or physical-gamepad test. Those player acceptance checks remain pending. No unresolved Stage 18 design blocker remains; Stage 19 awaits the next instruction.

Earlier development fixture failures concerned obsolete inventory API names, missing SubViewport physics picking, and incorrect assumptions about nested save-document paths/JSON numeric representation. The fixture was corrected to use actual production APIs and serialization. No failing production expectation was removed to hide a regression.

Suggested commit: `feat: add persistent authored Treasury rooms and container loot`.
