# Complete UI / Map / Rooms — Stage 24 acceptance review

Stage 24 adds a reproducible combined campaign acceptance journey and records the final cumulative checks. Production gameplay and save formats are unchanged. Automated acceptance and native-rendered fixture review passed for the paths explicitly listed below; a fully manually played campaign and physical-gamepad acceptance remain outstanding. User instructions to proceed are not recorded as player verification.

## Combined campaign

`tools/verify_combined_acceptance.gd`, registered through `tests/test_combined_acceptance.gd` in the official regression runner, carries one campaign through the following boundaries:

1. Established Refuge preparation: authored repair, unequip/re-equip of the same repaired armor, fixture-only salvage using the existing definition/yield, test-only production into Stash, transfer into a heroine Backpack, and ordered Party Apply. Empty shipped Alchemy/Crafting catalogs and disabled unauthored paid bed/Level Up services are checked before using fixtures.
2. Gallery fixture replay checks the entire campaign, discovered knowledge and durable save document for unwanted changes. Load restores the combined gear/inventory/order snapshot exactly.
3. Permanent Castle Memory and Submit, plus temporary Layer 1 Passage, are bought through the Intel screen. Cancel and Load preserve paid ownership and wallet; ordinary departure retains the unused Passage.
4. A generated Layer 2 layout, seed **7**, contains Treasury, Trap, Alchemy, Rest, Normal and Elite rooms. Actual Travel launches those hosts. A partial chest claim, trap observer state, field crafting/discovery and used room Rest each survive production exit and Continue with equality checks on the whole campaign safe point.
5. Field production spends current-run Materials while banked stock stays unchanged. Actual combat receives purchased Submit; an existing enemy is placed adjacent to establish Grapple through its controller. Backpack is available in ordinary combat and blocked during Struggle. Submit advances one stage, heals one HP and spends remaining Actions. Normal loot abandonment, victory summaries and map return use the production handlers.
6. Return banks surviving Materials, records the layout and preserves ordered party and permanent recipe knowledge. A second expedition reuses that layout with fresh content and no carried-over room claims or banked Materials. Defeat preserves registered equipment identities/condition and permanent knowledge, clears consumables and the ended-run safe point, and retains the unused paid Passage. That Passage then starts at the defeated Layer 1 boss and remains consumed after Continue.

**Fixture boundaries:** prior story, recruited heroines, boss deaths, starting funds, damaged/salvage equipment and optional Gallery media are supplied by the harness. Production recipes remain unauthored: the test recipe exists only in the isolated process, is changed to discovery-only for the field visit, and is unregistered afterward. Route access is primed at an adjacent node; this is not proof of a manually traversed route. Party draft order is assigned before clicking Apply. Some inventory/service/Return operations call the actual production controller directly. Battle outcomes are injected after real encounters start; they do not prove ordinary combat balance or a normally won campaign. Mouse/key events are automated native viewport input, not physical device use. Defeat recovery itself uses production behavior without a recovery fixture.

## Executed results

Evidence is under `docs/evidence/complete_ui_stage24/`. All Godot runs use isolated XDG data/config/cache locations; the harness also selects its own test save directory. No player campaign slot was used.

| Command / check | Result | Evidence |
| --- | --- | --- |
| `python3 tools/validate_project.py --allow-generated-cache` | Passed, 270 named GDScript classes | `validation.log` |
| `GODOT_BIN=/home/fluffy56/.local/bin/godot4 PYTHONDONTWRITEBYTECODE=1 python3 tools/run_regression_suite.py` | **85/85 scripts passed, exit 0**; no GDScript parse/compile/runtime errors | `regression.log` |
| Combined journey within official suite | 154 checks, zero failures | `regression.log` |
| `godot4 --path . --script res://tools/verify_combined_acceptance.gd -- --acceptance-captures=res://docs/evidence/complete_ui_stage24/screenshots` | 154 checks, zero failures; desktop process exit 0 | `native.log`, 14 PNGs |
| `godot4 --path . --script res://tools/verify_run_recovery.gd -- --recovery-captures=res://docs/evidence/complete_ui_stage24/recovery_screenshots` | 40 checks, zero failures; exit 0 | `native_recovery.log`, 10 PNGs |
| `godot4 --path . --script res://tools/verify_trap_interface.gd -- --trap-captures=res://docs/evidence/complete_ui_stage24/traps_screenshots` | 25 checks, zero failures; exit 0 | `native_traps.log`, 7 PNGs |
| `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tools -p 'test_*.py'` | 13 tests passed; exit 0 | `python.log` |
| `git diff --check`, source manifest and Stage 24 diff review | Passed; exact five-file source delta reviewed, no unrelated source changes | `diff_check.txt`, `source_sha256.txt` |

The standalone `focused.log` also prints 154 checks/zero failures, but its session wrapper subsequently reported termination (143); it is supplemental, not the final process-exit gate. The official cumulative run and desktop run supply that gate. Development logs are retained separately and are not passing acceptance evidence. Harness development corrected an invalid enum, a full exact-slot destination, an unaffordable second temporary purchase, and input sent before a deferred layout/focus scroll completed. No gameplay assertion was weakened and no production rule was changed to make the test pass.

Historical baseline: Stage 00's 24 structural diagnostics were repaired in Stage 02 and are not current failures. Existing ObjectDB/resource shutdown diagnostics and deliberately corrupted-save JSON diagnostics still appear in the cumulative suite. Their presence must not be confused with a new GDScript parse/compile/runtime failure or with clean shutdown certification. See the Stage 00 baseline and individual test logs for their original context.

## Coverage beyond the combined fixture

The official suite reruns the existing focused contracts rather than duplicating every specialized scenario in the journey:

| Acceptance requirement | Focused coverage and limits |
| --- | --- |
| Ordinary pre-Refuge Rest and Return | `test_run_recovery.gd`, `test_run_recovery_ui.gd`; native recovery rerun. Two uses, party-wide half HP/MP, revival, +10 Corruption, failed saves, Cancel and supported safe points. Ordinary-Rest native fixture intentionally has no authored room background. |
| Reverse Layer 2, first Refuge origin and representative Refuge-less scenario | `test_l1_l2_demo_flow.gd`, `test_layer_transition.gd`, `test_jailer_refuge_origin.gd`, `test_campaign_lifecycle.gd`; production state transitions with seeded story/outcome fixtures, not a manual campaign. |
| Partial containers, keys, party/order, gear and condition | Treasury, inventory/loadout, run-party, active-safe-point and production-save scripts; whole-snapshot comparisons in combined journey. Ordinary/scoped-key behavior remains the existing contract. |
| Detected/disarmed/triggered traps, alarm sequencing and cleanup | `test_room_traps.gd`, `test_trap_interface.gd`, `test_trap_rooms_ui.gd`; native synthetic trap profile shows selected-recipient consequences, violet/green particles, expiry and room-exit cleanup. Combined journey covers seeded observer-state persistence; it does not independently force every trap result. |
| Used and unused room Rest | `test_rest_rooms.gd`, `test_rest_rooms_ui.gd`; six offers, persisted usage independently of Solved, revival and transactional save failures. Combined journey uses the generated offer, including a valid no-op recovery when current resources are already capped. |
| Learned recipes/material ownership | `test_field_production.gd`, `test_field_production_ui.gd`, Refuge production tests and first-origin fixtures; production recipes stay empty. Combined journey exercises banked-to-Stash and run-to-Backpack domains, Return and later defeat. |
| Purchases/Memory/Passage/save rollback | Intel/Submit and Castle Memory state/UI scripts cover temporary/permanent prices, wrong layer/price, duplicate or failed writes, content refresh, locks, ordinary departure and both Passage layers. Combined journey connects earlier preparation/room state with Return, Memory and defeat. |
| Gallery isolation | Records tests plus combined campaign/knowledge/document equality around replay. Optional Gallery media is test content; no new production unlocks are claimed. |
| Equipment defeat protection | Existing run/equipment/lifecycle tests and combined identity/condition check preserve the current registry-based protection. The deferred equipped-only loss policy is not implemented. |
| Input, focus, click-through and viewport support | Existing UI tests exercise nested Escape/focus and modal blocking; map navigation includes synthetic joypad-button input. New native runs cover mouse/key input and 1920×1080, 1600×900, 1280×720, 1024×768. Physical-controller hardware is unrun. |

## Native inspection

Engine: **Godot 4.7.2 stable**, OpenGL **Compatibility**, Intel Mesa Iris Xe (ADL GT2), OpenGL 4.6 / Mesa 26.1.6. All 31 final PNGs were visually reviewed, using full-size images for representative interactions and contact sheets for the complete set. The four sizes above are actual render target dimensions. Dialogs, named recipients, remaining resources, summary actions and Struggle controls are visible; room and battlefield imagery retain their authored aspect ratios. Gray margins in non-matching aspect ratios and the deliberately empty ordinary-Rest fixture are not missing production assets. Trap clouds appear at the source anchor and are removed after expiry or room exit. No new production visual blocker was found in the inspected captures.

Useful retained captures: `screenshots/1280x720_field_craft.png`, `screenshots/1024x768_submit_struggle.png`, `screenshots/1280x720_final_passage.png`, `recovery_screenshots/1024x768_rest_confirmation.png`, and `traps_screenshots/1024x768_corruption_cloud.png`. `screenshots_sha256.txt` identifies the exact reviewed files.

## Stage 00–24 status

“Implemented” means the supported authorized scope; it does not turn missing content into a functioning service. The historical dated reviews and `COMPLETE_UI_MAP_ROOMS_STAGE_LEDGER.md` retain per-stage commands/counts. The current suite is the cumulative recheck. Player verification remains separate in every row.

| Stage | Implementation at handoff | Test / evidence status | User verification |
| --- | --- | --- | --- |
| 00 | Audit/plan complete | Historical baseline recorded, including 24 former structural failures | Audit accepted to proceed |
| 01 | Refuge framework implemented | Refuge management/UI checks; historical native captures | Continue authorized; player QA pending |
| 02 | Shared inventory implemented; structural prerequisite repaired | Shared-view and validator checks | Continue authorized; player QA pending |
| 03 | Atomic transfers/stacks implemented | Transfers, rollback and conservation tests; combined transfer | Continue authorized; player QA pending |
| 04 | Loadouts implemented | Loadout exchange tests; combined repair/equip/reload | Continue authorized; player QA pending |
| 05 | Repair/Salvage implemented | Workbench tests; combined authored repair and fixture salvage | Continue authorized; player QA pending |
| 06 | Production interfaces/transactions implemented; recipes deliberately empty | Refuge production and combined test-only recipe | Continue authorized; playable recipe content deferred |
| 07 | Bed presentation implemented; paid effects unavailable | Rest-shell tests and disabled-service check | Player QA pending; effects/costs/eligibility unauthored |
| 08 | Ordered Party/Expedition implemented; Level Up unavailable | Expedition tests and combined Apply/departure | Player QA pending; upgrade backend unauthored |
| 09 | Records/Gallery supported scope implemented | Records and combined isolated replay | Player QA pending; missing archive content unavailable |
| 10 | Compact run/combat/Struggle dock implemented | HUD tests and live combined combat/Struggle captures | Player QA pending |
| 11 | Combat Backpack permissions/Actions implemented | Backpack tests; combined ordinary/Grapple access | Player QA pending |
| 12 | Loot capacity/source lifetimes implemented | Loot/Treasury tests; combined partial claim and fight abandonment | Player QA pending |
| 13 | Current-run Party implemented | Run-party state/UI tests; combined order persistence | Player QA pending |
| 14 | Ordinary Rest/Return implemented | Recovery tests; 40-check native rerun and combined Return | Player QA pending |
| 15 | Graph constraints/discovery implemented | Generator, map discovery and lifecycle tests | Player QA pending |
| 16 | Flat map presentation implemented | Map navigation/discovery UI tests and current Passage capture | Player QA pending |
| 17 | Combat-only Normal/Elite implemented | Generated combat state/UI tests; combined summaries/defeat | Player QA pending; natural battle balance unverified |
| 18 | Persistent Treasury implemented | Treasury state/UI tests; combined partial-container Continue | Player QA pending; provisional rewards |
| 19 | Item traps/native particles implemented | Trap tests and 25-check native effect rerun | Player QA pending; provisional thresholds/effects |
| 20 | Single-offer Rest rooms implemented | Rest-room state/UI tests; combined used-room Continue | Player QA pending |
| 21 | Field production/discovery implemented; recipes deliberately empty | Field tests; combined materials/discovery/Return/defeat | Player QA pending; provisional first-visit grants |
| 22 | Intel ownership/Submit implemented | Intel/Submit tests; combined purchases and Struggle | Player QA pending; provisional prices |
| 23 | Castle Memory/layer-specific Passage implemented | 1,524 state checks plus UI and combined multiple-expedition journey | Player QA pending; provisional prices |
| 24 | Combined acceptance harness and evidence implemented | Final cumulative result above; 154 native journey +40 recovery +25 trap checks | Full normal-play campaign and physical-gamepad acceptance still required |

## Content decisions and remaining acceptance gates

No new design decision is required to retain this supported implementation. Existing intentional gaps remain:

- Production recipes stay empty by explicit user decision. Test-only outputs/costs are not authored economy data. Paid Refuge Resolve/Corruption services and Level Up require approved definitions before activation. Gallery/Bestiary/history content remains unavailable where unauthored.
- Treasury rewards/cache discovery are the user-approved modest seeded provisional content. Traps retain approved provisional 1–2 trapped items, at least one safe item, 2-success Awareness/Agility thresholds, Expert automatic detection, and the three equally weighted consequences. No balance acceptance is implied.
- Station grants remain provisional: Layer 1 stations grant 2 Red Wax +2 Servant Cloth; Layer 2 stations grant 2 Chain Links +2 Prison Iron. Seven supported Intel options cost 10 Bloom per run or 1,000 permanently. Submit costs 100 permanently and uses the approved older level-1 bundle (25% Climax damage and 2 Climax healing). Castle Memory costs 10/1,000; Passage costs 100×layer per run and 100 times that permanently, with per-layer ownership.
- A human normal-play pass from New Game through story, reverse Layer 2/Refuge, preparation, expedition, natural combat, Return, defeat and Continue is still required. Prior-route and outcome fixtures do not replace it. A physical-gamepad pass through focus, selectors, nested Cancel and combat targeting is also still required. These are acceptance gaps, not reported successes.
- Layers 3–10, cross-layer travel and Companion interactions are not implemented or activated by this work. Package/export certification and Forward+/other hardware renderer testing were not run.

## Files, compatibility and handoff

Stage 24 changes only the new verifier/test and their two Godot UID files, the runner registration, this report, the stage ledger and evidence. `baseline_sha256.json` records source hashes before Stage 24; `source_sha256.txt` and `files_changed.txt` list its exact source delta. Earlier Stage 15–23 work and unrelated Content Workbench changes are preserved.

No production save migration, schema/version bump, balance adjustment or gameplay edit. Existing saves retain their Stage 23 compatibility behavior, atomic writes/backups and pre-node/post-resolution persistence. No mid-combat or mid-dialogue saving is added.

Suggested commit: `test: add stage 24 combined campaign acceptance and final evidence`.

Changes remain local and uncommitted. The next acceptance step is the normal-play and physical-controller checklist above, followed by any explicitly authorized content authoring. The supplied stage sequence ends at 24; no Stage 25 is inferred.
