# Complete UI / Map / Rooms — Stage 20 review

Stage 20 implements Rest rooms with one fixed recovery offer. The user authorized proceeding after Stage 19 and resumed final verification on October 30. Changes remain local and uncommitted alongside Stages 15–19; unrelated Content Workbench changes are preserved. Stage 21 is not activated.

## Behavior

New full Layer 1/2 maps activate their existing zero-or-one reserved Rest position, using Abandoned Guest Bedroom or Prison Infirmary and existing backgrounds. Generation assigns one of six offers uniformly using the stable room content seed and node ID. The offer is saved, never selected by the player, and a later layer may repeat it. Existing map topology and optional-room frequency are unchanged.

The six authored Resources provide: add 50% maximum HP; add 50% maximum MP; both; add 20 Resolve; subtract 20 Corruption; or restore full HP/MP/Resolve and add 50 Corruption to each active heroine. Percentages add an amount based on maxima, using the existing ordinary-Rest ceiling convention. All values respect existing bounds. HP-restoring offers revive defeated active heroines when HP becomes positive; other offers leave them defeated. A confirmed capped/no-change offer still uses the room's one recovery, with the actual before/after values visible first.

Clicking the bed opens the existing recovery confirmation interface with exactly one offer, every active heroine, and all four before/after resource values. Cancel changes nothing. The modal blocks conflicting party, inventory, exit and ordinary-Rest actions. Confirm has no currency or Material cost and never consumes ordinary Stage 14 Rest charges. Refuge bed rules remain unchanged.

Rest Used and Solved remain independent. Leaving these empty authored rooms completes their content without spending recovery. An unused offer remains available on revisit and after loading. A successfully used bed cannot reopen confirmation, and map details distinguish available from spent recovery.

## Persistence and compatibility

No save-version bump or destructive migration. Optional `MapNodeState.rest_offer_id` defaults to zero for old snapshots; explicit values must be integral numbers from zero through six. Assigned offers use IDs one through six. Existing `rest_used` persists consumption. Stored maps retain their existing types, content and topology; loading does not activate reserved Rest positions or generate missing offers.

The transaction validates the current room and recomputes the preview before committing, rejecting stale party/offer requests. It stages a separate RunState with current party, inventory/equipment ownership and room outcome, marks recovery used, and writes the existing atomic CampaignSaveSlotStore checkpoint before publishing the staged state. Failed writes preserve live party values, the unused flag and the prior durable document. Successful writes reopen the room with fresh views. Archived layer graphs are preserved. The completed service becomes the pre-node checkpoint for continuing the room; ordinary combat/dialogue save boundaries are unchanged.

`EventRoomDefinition.solve_on_exit` defaults false and is enabled only on these two empty Rest room definitions. Existing content-completion rules remain authoritative elsewhere.

## Files changed

- Three scripts in `scripts/exploration/rest/`: authored offer Resource, pure recovery/preview rules and bed hotspot intent.
- Six offer Resources in `data/exploration/rest/`; two room Resources and two scenes; event-room catalog registration.
- EventRoomDefinition and EventRoomScreen integrate authored exit completion and the shared confirmation modal. MapNodeState, LayerMapGenerator, RunState and MainController integrate assignment, saved state, transactional recovery and map details.
- State/UI tests and `tools/verify_rest_rooms.gd`, regression registration, and Stage 15/17 assertions updated only for the explicitly activated Rest milestone. Alchemy/Workshop remain inactive.
- This review, stage ledger and `docs/evidence/complete_ui_stage20/` retain validation evidence. `files_changed.txt` and `source_sha256.txt` identify all 32 source/content/test/UID files changed against the Stage 19 baseline.

## Validation

All **77 regression scripts** are covered across the interrupted and resumed runs, with no test failures reported. The original official `python3 -B tools/run_regression_suite.py` run completed 71 scripts and was interrupted during script 72, `test_battle_composition.gd`, when the session ended. Its log is preserved. The remaining six scripts were rerun through the same runner's isolated environment and execution helpers: **6/6 passed, each exit 0; resumed runner exit 0**. Neither log contains GDScript parse/compile/runtime diagnostics. This report does not claim an uninterrupted 77-script exit status.

- Rest state: **3,998 checks, zero failures**, including 200 generated layers, all six assignments, optional absence/presence, cross-layer repeats, JSON round trips, legacy absence, malformed values, bounds, pure previews, stale rejection and staged recovery persistence.
- Final headless and native production interface: **154 checks each, zero failures**. Covers actual Travel/bed/Cancel/Confirm/exit input; all six offers; failed-write rollback and retry; exact before/after application; defeated heroines; duplicate confirmation; unused Solved revisit; Continue; and independent ordinary charges, Bloom and Materials.
- The earlier cumulative UI run had **148 checks, zero failures**. Final map-description text was corrected after that run started, with six additional assertions and the complete **154-check** fixture rerun headlessly and natively.
- Python tooling: **13/13 passed**. Project validator: **262 named GDScript classes**. Final editor import has no GDScript parse/compile errors.
- Full Stage 20 diff reviewed against the saved Stage 19 baseline; final whitespace and stat checks recorded with handoff. No unrelated changes removed.

Existing ObjectDB/resource shutdown diagnostics remain: the focused fixtures report five objects and three resources, previously traced to dialogue condition and authored-position Resources. The cumulative cancel-input test also reports four leaked TextServer shaped-text RIDs. Deliberate corrupt-save JSON diagnostics remain in existing save tests. These are retained in logs, separate from GDScript parse/compile/runtime failures.

## Native QA and remaining acceptance

Godot 4.7.2, OpenGL Compatibility on Intel Iris Xe exercised production Main/map/room/save hosts at 1920×1080, 1600×900, 1280×720 and 1024×768. The fixture primes the preceding route and forces offer IDs only to cover all six variants; recovery and save transactions use production code. Offers one and six cover all four resolutions; the other offers cover 1280×720.

Eight screenshots were visually inspected and retained, showing every offer, the per-heroine Corruption warning for full recovery, both room backgrounds, the smallest supported confirmation layout and the corrected spent-room map description. These are native scripted QA and manual image inspection. A full manually played campaign and physical-gamepad acceptance remain pending.

No unresolved Stage 20 design blocker remains. Suggested commit: `feat: complete stage 20 single-offer Rest rooms`.

Next milestone: Stage 21 — field Alchemy/Workshop and permanent recipe discovery, awaiting instruction.
