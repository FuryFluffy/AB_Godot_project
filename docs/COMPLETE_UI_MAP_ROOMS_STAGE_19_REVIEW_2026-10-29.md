# Complete UI / Map / Rooms — Stage 19 review

Stage 19 implements authored Trap rooms, saved Awareness/disarm checks, committed-item consequences, alarm combat continuation, and native CPU particle feedback. Stage 20 is not activated. Work remains local and uncommitted alongside Stages 15–18; unrelated Content Workbench changes are preserved.

## Authorization and provisional content

The user requested Stage 19 and explicitly approved the proposed provisional values: one or two trapped hotspots, at least one safe visible item, two successes for Intellect + Awareness detection and plain Agility disarm, Expert automatic detection, and equally weighted Poison Fog (−1 HP / −5 Resolve), Corruption (+20), or an alarm with two Hollow Servants. Existing heroine sheets are unchanged. These parameters live in `data/exploration/traps/`, not presentation code.

The user also authorized native particles from the supplied guidance. Repository/local branch inspection found Light Arrow mechanics but no existing particle implementation. This change uses the established room/encounter ownership and timer cleanup conventions; it does not claim to reuse unavailable Light Arrow VFX.

New full Layer 1/2 maps activate their existing one-or-two reserved Trap positions. Cold Pantry and Guard Station Without Guards use existing ordinary-room backgrounds. Each scene has three named visible item anchors, one inspectable concealed cache, and an open passage. Four deterministic draws reuse the existing approved layer-specific supply pools, item IDs, quantities, and weights; each room has its own registered source ID. No new item, equipment, recipe, salvage mapping, currency price, or narrative text is invented. Existing room lore and interaction handlers remain available; these two variants add no new lore entries. Later services and Layers 3–10 remain inactive.

## Behavior and boundaries

- `RoomTrapDefinition`, `RoomTrapProfile`, and `RoomTrapState` own validated balance data, deterministic assignments, per-observer Awareness outcomes, disarm outcomes, and one-shot consequences. Candidate IDs and effect IDs are sorted before seeded selection. A different seed can choose different items and effects.
- `RoomTrapController` bridges authored anchors to the production DialogueRunner, item markers, Disarm/Collect/Ignore dialog, and shared Loot controller. It never changes a heroine sheet. Each living observer gets at most one saved check per room/trap; changing selection, reopening interfaces, or gaining skill levels does not reroll that observer. A newly present, previously unchecked heroine can be checked on a later entry.
- The detector speaks the authored place and item name. Notice completion stays in room state, avoiding an unregistered campaign dialogue ID. Failed detection creates no marker or notice. The selected interactor may differ from the detector.
- Loot validates capacity and ownership before committing destination, claim and trap effect, then notifying observers. Preview, inspection, Ignore, cancellation and refused pickup cause no effect. Materials still route to the shared pouch. Successful disarm leaves the item available with a safe marker; failed disarm immediately triggers once, without consuming its item.
- HP/Resolve/Corruption use existing BattlerState bounds and loss rules on the interactor only. A lethal party-wide outcome enters the existing defeat/Refuge ownership path; surviving run Materials are banked.
- Alarm combat uses the active party and two independently identified instances of the existing Hollow Servant sheet, AI and static PNG poses. Catalog arrays and alias definitions are encounter-local. CombatEngine and Grapple rules are unchanged. Existing layer battlefields/stage bindings and the ordinary combat Bloom reward are reused. There is no additional first-clear/fight-item reward.
- Alarm victory returns to the remaining room, preserving other items and concealed content. Victory alone does not mark the room Solved. The victory transaction is idempotent when a durable-write retry is required.
- Feedback uses room-owned `CPUParticles2D`, procedural soft particle textures, green/violet color ramps and a short timer. It captures the item anchor before the sprite disappears and inherits the fitted room transform. The Loot panel closes on a triggered effect so feedback is visible. The bell pulse precedes alarm transition. Effects never apply rules themselves, replay on load, or survive room teardown.

## Persistence and compatibility

No save version bump or destructive migration. Optional `local_state.item_traps` stores the assigned effect parameters, seeds, observer records, detector/interactor IDs, detected/announced/disarmed/triggered flags, the disarm result and alarm pending/resolved flags. Missing fields in pre-Stage-19 rooms remain valid because the entire trap extension is optional. Malformed explicit flags, rules, checks, contradictory alarms, or trap IDs without a visible item record reject before restore commits. Existing saved map types/topology are retained; new Trap activation applies only to new generation.

The existing atomic CampaignSaveSlotStore and pre-node/post-resolution envelope remain in use:

1. Initial assignment and entry detection finish before ordinary room interaction. After the entry notice completes (or immediately if no notice is needed), a prepared pre-node checkpoint records the checks and announcement. A failure blocks interaction behind Retry. An interruption during the notice resumes the existing pre-node dialogue boundary.
2. A triggered alarm commits the room/claim state and writes a pre-combat checkpoint with the pending alarm before leaving the room. Continue recreates the same encounter seed without collecting the item or playing its feedback again.
3. Victory writes the resolved alarm and party/inventory/reward state as the checkpoint before room continuation. A failed write keeps the summary available for Retry, without awarding twice.
4. Ordinary subsequent stat-trap/disarm/item interactions remain subject to existing node-boundary saving. Exiting saves their room state. Interrupting an unresolved ordinary node rolls back the whole node to its prepared checkpoint; this is not a mid-combat or arbitrary mid-room save system.

## Changed files

Core changes: `scripts/exploration/traps/` (five scripts), EventRoomDefinition/InstanceState/Screen, RoomItemSpawnAnchor, RunLootController, EncounterDefinition/CombatEncounter, RunState/MainController, MapNodeState and LayerMapGenerator.

Content changes: four trap Resources; two room definitions/scenes; two source/profile pairs; EventRoomCatalog and RewardSourceCatalog registration. Existing canonical background images, item pool contents, heroine sheets and forty-room registry are unchanged.

Verification changes: `tests/test_room_traps.gd`, `tests/test_trap_interface.gd`, `tests/test_trap_rooms_ui.gd`, two `tools/verify_trap_*.gd` fixtures, regression registration and the explicitly superseded Stage 15/17 expectations that required special-room quotas are not yet executable / Trap positions remain inactive. Corresponding Godot UID files are included. This review, the stage ledger and `docs/evidence/complete_ui_stage19/` retain the handoff evidence. `files_changed.txt` lists the Stage 19 source/content/test delta against the Stage 18 checkpoint.

## Validation and native QA

- Focused trap state: **1,109 checks, zero failures**, including 200 generated layers, stable assignments, safe items, rolled/automatic detection, disarm success/failure, capacity previews/rejection, partial claims, one-shot effects, legacy maps and malformed saved state.
- Final headless and native interface fixtures: **25 checks each, zero failures**.
- Final headless and native production fixtures: **65 checks each, zero failures**, including independent repeated enemies and targeting, same-seed interrupted alarm recovery, no repeat entry dialogue, write-failure retries, idempotent rewards, preserved room contents and lethal trap defeat/Material banking.
- Project validator: **passed, 259 named GDScript classes**. Godot editor import completed without GDScript parse/compile errors; UID sidecars generated.
- Python tooling: **13/13 tests passed**.
- `python3 -B tools/run_regression_suite.py`: **75/75 scripts passed**, exit 0; zero GDScript parse/compile/runtime diagnostics. Includes the unrelated Workbench suite. Stage 15 map state **1,453/1,453**, discovery UI **24/24**, Stage 16 navigation **100/100**, and the existing combat/Treasury/save suites remain green.
- The initial cumulative run found the superseded Stage 15 quota assertion; it now checks executable required quotas while explicitly keeping future services inactive. The suite was rerun after that correction. A final conversion of effect-ID sorting to explicit String comparison was separately rechecked with the full trap state and production-flow fixtures.
- Final diff/check/stat and full Stage 19 review performed against the Stage 18 baseline; unrelated changes preserved. Source checksums and the exact changed-file list are retained with the evidence.

Native QA uses Godot 4.7.2, OpenGL Compatibility, Intel Iris Xe. The fixtures instantiate production Main/map/room/encounter/save hosts at 1920×1080, 1600×900, 1280×720 and 1024×768. Real mouse/key input covers travel, trap choice/Ignore, Begin and independent enemy targeting; production APIs commit Loot and disarm transactions. Preceding route state is primed, and battle victory is forced after live encounter initialization. Alarm kind and a failed-disarm threshold are overridden only in the fixture to exercise both transition paths deterministically. The interface fixture uses synthetic automatic detection and a Treasury background to isolate the shared bridge; the production fixture uses the actual new ordinary rooms and production detection thresholds.

Nine retained screenshots are manually inspected for dialog readability, local clouds, item/marker alignment, fitted rooms and two independently displayed Hollow Servants. Poison's native screenshot exercises the presentation directly; its actual stat/disarm transactions are covered by the state and production defeat tests. These are native scripted QA and manual image inspection, not a complete manually played campaign or physical-gamepad acceptance pass; those acceptance checks remain pending.

Known existing ObjectDB shutdown diagnostics are retained. In the Stage 19 fixtures, verbose inspection identifies `dialogue_condition_definition.gd`, `dialogue_condition_group.gd` and `authored_position.gd` (five objects / three resources). Deliberate corrupt-save JSON diagnostics in existing tests are also retained. They are distinct from GDScript parse/compile/runtime failures.

No unresolved Stage 19 design blocker remains. Provisional balance still needs normal playtesting. Suggested commit: `feat: complete stage 19 authored traps and alarm room continuation`.
