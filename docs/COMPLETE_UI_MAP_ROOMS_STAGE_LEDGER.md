# Combined UI, map and rooms stage ledger

Updated 2026-10-25. This is the single Stage 00–24 ledger for `AB_Complete_UI_Map_and_Rooms_v1`; it replaces neither existing runtime state nor historical checkpoint evidence. Follow the supplied root `02_IMPLEMENTATION_STAGES.md`. Work proceeds one authorized stage at a time and pauses for user verification/continue after each stage. Corrections remain in the current stage.

Stage 00 report: `COMPLETE_UI_MAP_ROOMS_STAGE_00_AUDIT_2026-10-09.md`.
Executed evidence: `COMPLETE_UI_MAP_ROOMS_STAGE_00_BASELINE_2026-10-09.md`.

| Stage | Deliverable | Implementation | Executed checks | User verification | Evidence / dependency |
| --- | --- | --- | --- | --- | --- |
| 00 | Local audit and combined plan | Complete (audit documents only) | Baseline complete; 48/48 direct Godot scripts, 4/4 Python; structural gate fails; graphical QA unavailable | Accepted to proceed | Audit committed as `cdd0830`; no gameplay/UI edits |
| 01 | Refuge room framework | Complete; committed/pushed | 48/48 direct Godot scripts; expanded UI checks; 4/4 Python; 36 graphical fixture captures; historical structural failures repaired in Stage 02 | Continue authorized; player QA pending | `COMPLETE_UI_MAP_ROOMS_STAGE_01_REVIEW_2026-10-10.md`; original background, five props/eight hotspots, menus/focus; Compatibility explicit |
| 02 | Shared inventory views | Complete; committed/pushed | Structural validator passes; 49/49 regression scripts; 9/9 validator tests and 4/4 runner tests; 45 actual Godot captures | Continue authorized; player QA pending | `COMPLETE_UI_MAP_ROOMS_STAGE_02_REVIEW_2026-10-14.md`; mixed ownership, independent selector, native contextual bar |
| 03 | Atomic inventory transfers/stacks | Complete; committed/pushed | 50/50 Godot scripts; 13/13 Python tests; 100-operation conservation sequence; 60 native-input/capture checks | Continue authorized; player QA pending | `COMPLETE_UI_MAP_ROOMS_STAGE_03_REVIEW_2026-10-15.md` |
| 04 | Refuge Loadouts | Complete; committed/pushed | Validator passes; 51/51 Godot scripts; 13/13 Python tests; 58 native-input/capture checks | Continue authorized; player QA pending | `COMPLETE_UI_MAP_ROOMS_STAGE_04_REVIEW_2026-10-15.md`; exact-source exchange, Nothing, rollback/reload |
| 05 | Repair/Salvage | Complete; committed/pushed | Validator passes; 52/52 Godot scripts; 13/13 Python tests; 53 native-input/capture checks | Continue authorized; player QA pending | `COMPLETE_UI_MAP_ROOMS_STAGE_05_REVIEW_2026-10-15.md`; production salvage candidates absent, fixture explicitly labelled |
| 06 | Alchemy/Crafting | Interfaces/transactions complete locally; recipes deliberately empty | Validator passes; 53/53 Godot scripts; 13/13 Python tests; 114 native-input/capture checks | Continue authorized; player QA pending | `COMPLETE_UI_MAP_ROOMS_STAGE_06_REVIEW_2026-10-16.md`; user explicitly deferred authored recipes |
| 07 | Refuge bed | Presentation complete locally; paid recovery unavailable | Validator passes; 54/54 Godot scripts; 13/13 Python tests; 93 native-input/capture checks | Continue authorized; player QA pending | `COMPLETE_UI_MAP_ROOMS_STAGE_07_REVIEW_2026-10-17.md`; recovery effects/costs/eligibility unauthored |
| 08 | Expedition/Party/Level Up/Intel shells | Supported scope complete locally; paid upgrades/Intel unavailable | Validator passes; 55/55 Godot scripts; 13/13 Python tests; 120 native checks | Pending | `COMPLETE_UI_MAP_ROOMS_STAGE_08_REVIEW_2026-10-17.md`; ordered draft/apply, inactive preservation, accessed floors |
| 09 | Records/Gallery | Supported scope complete locally; missing content unavailable | Validator passes; 56/56 Godot scripts; 13/13 Python tests; 124 native checks | Pending | `COMPLETE_UI_MAP_ROOMS_STAGE_09_REVIEW_2026-10-18.md`; discovered lore, optional media and isolated dialogue replay |
| 10 | Compact run/combat/Struggle dock | Supported scope complete locally | Validator passes; 57/57 Godot scripts; 13/13 Python; 488 focused and 488 native checks pass, including 14 live encounter checks | Pending | `COMPLETE_UI_MAP_ROOMS_STAGE_10_REVIEW_2026-10-19.md`; shared dock/Ability, later services gated; user authorized Stage 11 |
| 11 | Combat Backpack permissions/Actions | Complete locally | Validator 248 classes; Godot 59/59; Python 13/13; 39 transaction checks; 50 native checks; safe-point tests pass | Pending | `COMPLETE_UI_MAP_ROOMS_STAGE_11_REVIEW_2026-10-21.md`; shared view/algorithm, actor-only atomic cost, Grapple guard |
| 12 | Loot/capacity/source lifetime | Complete locally | Validator 251 classes; Godot 61/61; Python 13/13; 54 transaction checks; 30 final native/headless UI checks | Pending | `COMPLETE_UI_MAP_ROOMS_STAGE_12_REVIEW_2026-10-24.md`; persistent room remainders, fight-only abandonment, shared Backpack/Item Bar |
| 13 | Current-run Party | Complete locally | Validator 253 classes; Godot 63/63; Python 13/13; 22 state checks; 52 native checks | Pending | `COMPLETE_UI_MAP_ROOMS_STAGE_13_REVIEW_2026-10-24.md`; immediate display order, legacy-compatible safe-point persistence |
| 14 | Ordinary Rest/Return | Complete locally | Validator 254 classes; Godot 65/65; Python 13/13; 40 state checks; 40 native checks | Pending | `COMPLETE_UI_MAP_ROOMS_STAGE_14_REVIEW_2026-10-25.md`; user defined party-wide half HP/MP, revival and Corruption |
| 15 | Graph/generation/knowledge/discovery | Not started | Not run for new target | Pending | New quotas, dead ends, per-exit knowledge; stage-gated new content |
| 16 | Flat map art/live presentation | Not started | Not run for new target | Pending | Manifest aliases, badges, filtered details/routes, zoom/focus |
| 17 | Combat-only Normal/Elite | Not started | Not run for new target | Pending | Trio/pair exist but Elite ungenerated; preserve story/defeat |
| 18 | Persistent Treasuries | Not started | Not run for new target | Pending | Stage 12 remainder model; two new authored backgrounds |
| 19 | Item traps/native particles | Not started | Not run for new target | Pending | Existing Light Arrow particle reference not found locally |
| 20 | Single-offer Rest rooms | Not started | Not run for new target | Pending | Independent saved offer/use; six approved effects |
| 21 | Field production/permanent recipes | Not started | Not run for new target | Pending | Stage 06 transaction; run-only inputs/output capacity |
| 22 | Intel/permanent ownership/Submit | Not started | Not run for new target | Pending | Wallet+entitlements transaction; real Submit action/coupling |
| 23 | Castle Memory/Passage | Not started | Not run for new target | Pending | Layout/knowledge projection, fresh content, eligible start |
| 24 | Combined lifecycle acceptance | Not started | Not run for new target | Pending | Normal-play plus labelled fixtures; actual graphical QA |

## Stage 00 execution record

- Authorization: supplied staged prompt, Stage 00 only. “Resume from where you left” continued the audit.
- Branch/HEAD: `codex/private-review-preparation` / `f3a573c`.
- Existing dirty Workbench files were preserved. New files are only the audit, this ledger and baseline document.
- Supplied package: 125 safe extracted entries, 124/124 listed hashes match. Temporary handoff directory: `/tmp/ab_complete_ui_handoff_2026-10-09/AB_Complete_UI_Map_and_Rooms_v1`.
- Baseline: structural validator exit 1 with 24 diagnostics; official runner exit 1 before Godot tests; independently run current list 48/48 exit 0; Python unit tests 4/4; headless startup exit 0 with cleanup diagnostics.
- Graph/Elite probe: twelve existing generated graphs valid under old contract, 10–12 playable rooms in sample, zero Elite/dead-end side rooms; both existing Elite formations confirmed directly.
- Renderer probe: Godot 4.7.2 effective setting `forward_plus`, despite `GL Compatibility` feature label. No configuration mutation.
- Visual evidence: inspected supplied reference images; these are not screenshots of an integrated new UI. Graphical startup failed (X11/Wayland unavailable); no new manual gameplay evidence.
- Migrations/compatibility: none. Existing envelope v3, IDs/enums, safe points, ownership and seed behavior unchanged.
- User feedback/verification: accepted to proceed via “good, proceed”; Stage 01 authorized. This supersedes the audit-time pending status.
- Committed at the user’s request: `cdd0830 docs: audit consolidated UI map and room stages`.

## Stage 01 execution record

- Authorization: “good, proceed”; resumed by “Resume from where you left”. Stage 01 only.
- Outcome: authored room/five props/eight hotspots, Bloom-only default, existing services in contextual panels, focus and nested Cancel, system actions routed to existing owners. Later services gated.
- Compatibility: no campaign migration; settings v1 gains optional `refuge_ui_scale` default 1.0. Explicit Compatibility renderer, preserving the existing Workbench plugin setting.
- Checks: 48/48 independently executed Godot scripts and 4/4 Python tests pass. Final focused UI rerun passes. Validator/official runner still fail the identical 24 pre-existing diagnostics. Actual Godot Compatibility fixture rendered 36 captures at three verified resolutions.
- Evidence and player checklist: `COMPLETE_UI_MAP_ROOMS_STAGE_01_REVIEW_2026-10-10.md`; retained engine captures/results in `evidence/complete_ui_stage01/`.
- User verification: pending, including physical controller and normal-play review. No claim of a newly played full campaign. Later “Proceed to stage 2” authorized continuation; this does not assert manual verification.
- Git: Stage 01–02 committed locally as `17d293d`; published together as `41fae95` on `codex/refuge-room-inventory-stages-01-02`. Unrelated Workbench files preserved.

## Stage 02 execution record

- Authorization: “Proceed to stage 2”, continued by resume requests through 2026-10-14. Stage 02 only, with the narrow validator prerequisite repair discussed before proceeding.
- Outcome: Stash-first tabs, reusable fifteen-slot Backpacks and independent named selection, shared Key-ring, banked Materials, and conditional external six-slot native Item Bar. Existing combat layout remains vertical.
- Ownership: slots reference existing equipment instances/condition; carried Mementos retain Item IDs. Old item-only saves remain readable without a version bump. Duplicate/dangling/equipped references reject. Current registered-equipment defeat protection is preserved.
- Validation: structural gate now passes, including rejection tests for explicit bad defaults/content and horizontal combat defaults. Final official suite passes all 49 scripts; focused keyboard/geometry checks pass; validator tests 9/9 and runner tests 4/4 pass. Actual Godot fixture rendered 45 captures at three resolutions; seven retained.
- Review/evidence: `COMPLETE_UI_MAP_ROOMS_STAGE_02_REVIEW_2026-10-14.md`, `evidence/complete_ui_stage02/`.
- User verification: pending. Physical controller and normal-campaign playthrough remain unverified. Advanced transfers (03), Loadouts exchanges (04), and production run Backpack access (11) remain deferred.
- Git: Stage 01–02 committed locally as `17d293d`; published as `41fae95` using the established separate publishing history. Remote SHA verified; publication tree matches the development checkpoint. Publishing suite: 48/48 Godot and 13/13 Python tests, excluding unrelated Workbench work. User then authorized Stage 03; physical-controller/normal-campaign verification remains pending.

## Stage 03 execution record

- Authorization: “After you finish with comit and github upload, proceed with the next stage”, then “Continue with the task”.
- Outcome: exact-slot moves/merges/swaps, Split, named quick transfers, stale-request rejection and controller-owned save rollback. Existing ownership state remains authoritative.
- Compatibility: no serialized changes; current equipment protection, scoped keys and Materials boundaries preserved. No Loadout/run/combat mutation permissions added.
- Validation: validator passes (233 classes), 50/50 Godot scripts and 13/13 Python tests pass. Focused transfers/rollback/reload and 100 seeded operations pass. Native fixture passes 60 interaction/capture checks at three exact resolutions; four images retained. Full suite preceded the final dialog font adjustment; focused/native/validator reruns pass afterward.
- Evidence: `COMPLETE_UI_MAP_ROOMS_STAGE_03_REVIEW_2026-10-15.md` and `evidence/complete_ui_stage03/`. User verification, physical controller and normal-campaign save/load checks remain pending. No design blocker. The user subsequently authorized Stage 04; this does not assert physical-controller or campaign verification.
- Git: Stage 03 committed locally as `27f658871a0ca41b90856ef3782092838bfadc47`; published as `ca244c83359c74bfb4c72b29ca8321534f184dfd` on `codex/refuge-room-inventory-stages-01-02`. Remote SHA verified. Source/publication trees match (`03f73f393f6abea2ac1ca30ba9af98c91daf8516`). The separate publication history and unrelated Workbench changes were preserved. Publication validator passes (233 classes) and focused inventory transfers report zero failures.

## Stage 04 execution record

- Authorization: “Good, comit, upload to github and proceed with stage 4”, followed by resume requests. Stage 03 was committed and uploaded before implementation continued.
- Outcome: right-side four-row Loadouts, shared named selector, all compatible Stash/named-Backpack sources, explicit preview/Equip, atomic exact-source return, Nothing-to-Stash and nested cancellation/focus. Existing party ordering is accessible in Expedition.
- Ownership/compatibility: existing state/transaction/save owners retained; no schema/version/ID changes. Shield remains Off Hand, current Memento ownership restrictions remain, unavailable equipment art is not fabricated, and multi-slot displacement is excluded. No run/combat permissions added.
- Validation: structural validator passes (236 classes), official suite 51/51 Godot scripts, Python 13/13. Focused full-bag/same-owner exchanges, duplicate instances, conditions, JSON reload, equipment/Memento save rollback, stale browsing and UI tests pass. Final graphical fixture passes 58 checks and produces twelve captures at three exact sizes; four retained.
- Review/evidence: `COMPLETE_UI_MAP_ROOMS_STAGE_04_REVIEW_2026-10-15.md`, `evidence/complete_ui_stage04/`. Actual Godot fixture and screenshot inspection completed. Physical controller and normal-campaign save/load player verification remain pending. Existing engine teardown diagnostics are recorded in the report/logs.
- Git: Stage 04–05 subsequently committed as source `135671e` and published `4cadcdd`; remote SHA verified and trees identical. Unrelated Workbench changes preserved.
- No blocking design decision for current authored gear. The user subsequently authorized Stage 05 via “Proceed to stage 5”; this does not assert manual campaign/controller acceptance.

## Stage 05 execution record

- Authorization: “Proceed to stage 5.” Stage 04 work retained locally; no commit/upload requested this turn.
- Outcome: contextual Repair/Salvage tabs; named Stash/Backpack/equipped sources; actual condition, authored cost and capped outcome; named salvage yield and destruction confirmation; nested cancellation and focus restoration. Equipped salvage now rejects at controller and ownership levels.
- Ownership/compatibility: existing repair/salvage state and transactional persistence reused; failed saves/stale previews cannot spend/destroy. No schema/version/ID/economy/Resource activation change. The old test permitting equipped salvage was superseded explicitly, with unchanged-state rejection followed by explicit unequip and original-yield verification.
- Catalog limit: one existing Armor recipe (one banked Servant Cloth → +1 condition); no currently player-available destructible gear. Production Salvage stays empty. Tests/graphics temporarily expose one existing definition in memory only; no production eligibility was changed.
- Validation: structural validator passes (237 classes); official suite 52/52 Godot scripts; Python 13/13. Focused location/affordability/cap/rollback/stale/reload and confirmation tests pass. Graphical fixture passes 53 checks, twelve captures at three verified resolutions; four retained.
- Review/evidence: `COMPLETE_UI_MAP_ROOMS_STAGE_05_REVIEW_2026-10-15.md`, `evidence/complete_ui_stage05/`. Native Godot fixture/screenshot review complete; physical-controller and normal-campaign save/load acceptance pending. Existing engine teardown diagnostics documented.
- Git: Stages 04–05 committed as source `135671e8502153b0e2d234ecf87f7ca64b4f3bfc`; published as `4cadcddb89c15506bae4ae3cba0dd433e1965314`. Matching tree `0f200c18ab04ca152683c0ea4ed1705e74f8a080`; remote branch verified. Publication validator and focused Workbench test passed. Unrelated Content Workbench changes excluded.
- No blocking Stage 05 rule; extra salvageable player content/repair recipes require future authoring. The user subsequently authorized Stage 06; normal campaign/controller acceptance remains pending.

## Stage 06 execution record

- Authorization: “Comit, upload and proceed to stage 6”; clarified “Keep production recipes empty; implement and verify the interfaces and transactions.” Stages 04–05 were committed/uploaded first.
- Outcome: separate Alchemy ingredient-convergence and Crafting assembly/checklist interfaces; same existing banked Materials/Stash ownership. Extended existing recipe Resource/catalog with production action/station/output; explicit staged provider boundary and controller-owned save rollback. Normal Brew/Craft remain disabled with empty recipe lists.
- Compatibility: repair action ordinal/defaults unchanged; no campaign schema/version/ownership changes. No data Resources, recipe economy, unlocks or field service enabled. Synthetic recipes exist only in isolated test/preview processes and are labelled as such.
- Validation: validator passes (240 classes); official suite 53/53 Godot scripts; Python 13/13. Focused transaction/provider/capacity/reload/UI tests pass. Native recipe fixture 78 checks/twelve captures and empty-catalog fixture 36 checks/six captures, all at three exact sizes; four images retained.
- Evidence: `COMPLETE_UI_MAP_ROOMS_STAGE_06_REVIEW_2026-10-16.md`, `evidence/complete_ui_stage06/`. Actual Godot screenshots reviewed; physical-controller/normal-campaign acceptance pending. Cleanup diagnostics, including the focused test's 13 ObjectDB/9 resource report, are recorded.
- Content status: missing authored recipes are intentionally deferred per the user's clarification, not silently invented or counted as playable production content. Field ownership/recipe discoveries remain Stage 21. No blocking decision for the authorized scope.
- Git: Stage 06 remains local/uncommitted after source `135671e` / published `4cadcdd`. Unrelated Content Workbench changes retained.
- User subsequently authorized Stage 07 via “Proceed to stage 7”; physical-controller and normal-campaign acceptance remain pending.

## Stage 07 execution record

- Authorization: “Proceed to stage 7”. Stage 06 remains local/uncommitted and unrelated Content Workbench changes are preserved.
- Outcome: shared heroine selector in the bed's contextual Rest panel, real current Resolve/Corruption values, truthful unavailable costs and disabled Restore Resolve/Cleanse Corruption. Missing snapshots show unavailable values. Popup cancellation and bed focus restoration reuse the existing shell.
- Ownership/compatibility: read-only projection from existing known heroine roster and `RunState.party_snapshot`; selection changes no expedition order, ownership, resources or persistence. No migration, schema/version change, new economy or activation.
- Design blocker: no authored recovery effects, amounts, currencies/Material costs, formulas or eligibility exist. The detailed Rest specification explicitly requires unavailable services in this situation. Paid transactions and their success/affordability/rollback acceptance remain deferred; no recovery behavior was fabricated.
- Validation: focused Rest test has zero failures; validator passes (241 classes); Python 13/13; native Godot fixture passes 93 checks with nine exact-size captures at 1280×720, 1920×1080 and 1024×768. Three screenshots inspected and retained. Full official suite passes all 54 Godot scripts; verification completed 2026-10-17.
- Evidence: `COMPLETE_UI_MAP_ROOMS_STAGE_07_REVIEW_2026-10-17.md`, `evidence/complete_ui_stage07/`. Physical-controller and normal-campaign player acceptance remain pending. Existing ObjectDB/resource teardown diagnostics are recorded in logs.
- Git: no new commit/push requested or performed. User subsequently authorized Stage 08; campaign/controller acceptance remains pending.

## Stage 08 execution record

- Authorization: “Proceed with stage 8”; Party clarification: “Draft selection with Apply Party”.
- Outcome: graphical accessed-floor/deepest-reach hub; dedicated canonical-sprite Party view with selected highlights and numbered order; nonempty one-to-three draft/apply; persistent selected-party ownership and correct encounter order; truthful Intel and Level Up views. Explore remains the existing Layer 2 Farthest Cell route and rejects unapplied drafts.
- Ownership: inactive preparation inventory, equipment, Mementos and stats survive start, active reload, voluntary return and defeat. Selected runtime inventory staging now works at combat and Event-room boundaries. Refuge production remains rejected while deployed even with retained inactive gear.
- Compatibility: v3 retained. Additive accessed-layer lifecycle history and active inactive-party snapshots use safe absent-field defaults for old saves; malformed explicit data rejects. JSON dictionary sorting cannot reorder the expedition. No recipes, recovery prices, upgrade economy, Intel transactions or later layers activated.
- Validation: focused subset/save/rollback/legacy/UI tests pass; validator 243 classes; Python 13/13; native fixture 120 checks and 28 captures at four resolutions, five retained. Full official suite passes all 55 Godot scripts.
- Evidence: `COMPLETE_UI_MAP_ROOMS_STAGE_08_REVIEW_2026-10-17.md`, `evidence/complete_ui_stage08/`. Actual Godot screenshots inspected; physical-controller and normal-campaign acceptance pending. Engine cleanup diagnostics recorded.
- Limits: paid Level Up definitions are absent; Intel purchases/effects are later stages. Their shells cannot spend resources. Floor access does not grant boss defeat or Passage.
- Git: Stage 06–08 remain uncommitted locally after source `135671e` / published `4cadcdd`; unrelated Content Workbench changes preserved. No commit/upload requested this stage. User subsequently authorized Stage 09; campaign/controller acceptance remains pending.

## Stage 09 execution record

- Authorization: “Proceed with stage 9”.
- Outcome: right-side Records with four categories, discovered-only authored Lore, scrollable reading pane, stable selection and optional Gallery thumbnails/image viewing/dialogue replay. Bestiary, Run History and current production Gallery remain truthfully unavailable/empty because their content mappings are absent.
- Reused owners: campaign-configured Lore catalog, existing Knowledge discovery, DialogueRunner/DialoguePanel and room navigation. Optional media fields extend LoreEntryDefinition; no independent unlock store or invented content. Replay uses authored starting context copied into a discard-only session with no campaign/result/save consumers.
- Compatibility: no campaign/save/Knowledge schema or version change. Existing lore Resources default to null/empty media. No production media attachments, discovery-ID aliases, enemy disclosure rules, expedition history or new content activation were authored.
- Validation: validator 245 classes; focused Records test zero failures; Python 13/13; full official suite 56/56. Native fixture passes 124 checks and captures 32 images at four resolutions; five inspected captures retained. Tests cover reward/flag/item/stat/recruitment isolation, repeated/cancelled replay, automatic branches, stale discovery and locks, missing content, long text and nested focus.
- Evidence: `COMPLETE_UI_MAP_ROOMS_STAGE_09_REVIEW_2026-10-18.md`, `evidence/complete_ui_stage09/`. Native fixtures are separate from campaign/physical-controller player acceptance, which remains pending. Optional media shown in fixture captures is not production-unlocked content.
- Diagnostics: focused shutdown retains five ObjectDB/three resources. Native shutdown additionally retains existing battlefield/visual-catalog dependencies (422 ObjectDB/414 resources/162 texture RIDs); verbose investigation and explicit fixture cleanup did not eliminate them. No new archive view/session resource was listed as retained; broader dependency-lifetime cause remains unresolved.
- Design limits: Bestiary disclosure, Run History retention/fields and production Gallery attachments/replay contexts still need authoring. Replay needing item use or external gameplay transitions stays unavailable. These missing definitions were explicitly permitted to remain unavailable in Stage 09.
- Git: Stage 06–09 remain local/uncommitted, unrelated Content Workbench work preserved. No commit/push requested or performed. Stop for review/continue; Stage 10 has not begun.

## Stage 10 execution record

- Authorization: “Good, proceed with stage 10”, followed by resume requests. Stage 11 has not begun.
- Outcome: shared bottom dock with ordered current-party cards, six existing Item Bar slots, separate Backpack, contextual commands and Log tab. Existing Ability/Struggle interfaces clear the dock and Log tab; targeting, reactions, cancellation, focus and End Phase retain their existing owners.
- Exploration: Party/Ability/Rest before permanent Refuge, Party/Ability/Return afterward. Every Event-room launch supplies a read-only progression snapshot so learned authored abilities display with existing costs. Field execution remains unavailable because its eligibility/targets/costs/effects contract is unauthored; browsing changes no Actions or unlocks.
- Compatibility: no save migration/version/serialized ownership change. Existing v3 saves, scene paths, signal APIs, stable IDs, seeds, authored battlefields and inactive room registrations retained.
- Validation completed 2026-10-20: validator passes (246 classes); official suite 57/57 scripts; Python 13/13. Focused HUD and final native fixture each pass 488 checks with zero failures. Native checks include 14 real-encounter checks and four resolutions, with 55 captures generated and eight retained. Final diff/check/stat review completed.
- Evidence: `COMPLETE_UI_MAP_ROOMS_STAGE_10_REVIEW_2026-10-19.md`, `evidence/complete_ui_stage10/`. Native Godot input injection and visual inspection performed; full player campaign and physical-controller acceptance remain pending. Baseline five ObjectDB/three-resource teardown diagnostics remain.
- Gates: Backpack transactions (11), current-run Party (13), ordinary Rest/Return (14), permanent Submit (22). No later mechanics or content fabricated.
- Git: Stage 06–10 remain local/uncommitted; unrelated Content Workbench changes preserved. No new commit/push requested or performed. Suggested commit: `feat: unify combat and exploration in the shared run HUD`. Stop for review/continue.

## Stage 11 execution record

- Authorization: “Good, proceed to stage 11”, then “Resume the task”; completed 2026-10-21. Stage 12 has not begun.
- Outcome: existing fifteen-slot Backpack/selector/Key-ring connected to current run ownership and the single HUD Item Bar. Mouse drag, context Split and keyboard/controller source/destination paths reuse the fixed-slot transaction algorithm. Exploration transfers are free with no remote Stash.
- Combat: acting heroine only; one Action per positive Backpack ↔ Item Bar change or carried Main Hand weapon/Armor replacement. Exact-source displacement and condition/instance identity retained. Other heroine browsing is read-only. Failed, stale, no-op and cancelled changes are free. Grapple, Stun, turn/targeting/reaction locks guard backend and input entry. Memento/handoff/unequip/Use/Discard permissions remain unavailable.
- Compatibility: no save migration/version change. No mid-node saves; existing pre-node snapshots recover original ownership/seed, normal post-node persistence retains changes. Failed-write recovery is tested through CampaignSaveSlotStore. Existing registered-equipment defeat protection retained.
- Validation: structural validator passes (248 classes), official Godot suite 59/59, Python 13/13, focused transactions 39/39, native UI 50/50 across four resolutions. Native tests include actual encounter/Event-room controllers, mouse drag, keyboard context selection, nested cancellation, one/two/three selectors, empty destinations after deferred refresh, input blocking and pending field-item target rejection. Safe-point interruption/failed-write/reload tests pass.
- Evidence: `COMPLETE_UI_MAP_ROOMS_STAGE_11_REVIEW_2026-10-21.md`, `evidence/complete_ui_stage11/`; sixteen native captures generated, six retained and inspected. Full campaign and physical-controller player acceptance pending. Baseline five ObjectDB/three-resource cleanup diagnostics remain in scene/native runs; intentional save-corruption diagnostics are documented.
- Design blockers: none for Stage 11. Later loot UI, persistent source lifetime and out-of-combat Use/Discard remain Stage 12. Test-only spare equipment/stacks never grant production content.
- Git: no commit/push requested or performed; Stages 06–11 and unrelated Content Workbench changes preserved locally. Suggested commit: `feat: enable run backpacks with atomic combat action costs`. Stop for review/continue.

## Recorded boundary proposals for later stages

Keep all existing stage numbers and review pauses. Resolve carried ownership in 02 before 03/04; complete subset roster start/return in 08; include persistent room re-entry needed for Stage 12 acceptance in 12 while keeping discovery/Solved in 15. In 15, validate new special-room quotas in fixtures and gate production activation until the relevant 18–21 service/content stage works. Preserve small Jailer-entry/Refuge holding graphs as story transitions, not full-budget layers. Do not fold the pre-existing validator repair into Stage 01. See the audit for rationale and precise mappings.

## Evidence required when updating later stages

Record the actual authorized change, exact files/services, migration/default behavior, entry path/seed, commands and results, failure provenance, runtime image/video paths, manual checks actually performed, provisional data and blockers. Separate normal gameplay from fixtures and implementation from automated tests and user verification. Leave unavailable services gated. Stop after the current stage for verification/continue.

## Stage 12 execution record

- Authorization: “Good, proceed with stage 12”, 2026-10-24. Stage 12 was completed before the subsequent authorization to proceed with Stage 13.
- Outcome: adjacent Loot/Backpack with one existing HUD Item Bar, partial capacity-aware collection, carried Use/Discard during Loot, source-specific closure, and production victory handoff before the existing summary. Ordinary pickup remainders survive close/revisit/load; explicit fight abandonment loses only its surplus.
- Ownership: extends existing room assignments and node reward records with optional `remaining_quantity`/`abandoned_quantity`; immutable authored quantities, bindings and seeds. Legacy missing-field defaults and deferred rewards remain compatible; malformed explicit counters reject transactionally. No save-version bump, new save store or mid-node save.
- Tests: validator passes (251 named classes); official 61/61 Godot scripts pass with zero GDScript runtime/parse errors; Python 13/13; transaction script 54/54. Cumulative UI fixture 29/29, final native/headless fixture 30/30 after adding real drag assertion. Production-store injected write failure preserves the old safe point; saved partial room collection conserves 7 total items.
- Native QA: actual room/encounter/main-controller hosts, four resolutions, mouse drag/click/right-click and keyboard Escape. Corrected confirmation layout after visual inspection. Existing 5 ObjectDB / 3 resources teardown diagnostics remain. Normal-campaign/physical-controller user verification pending.
- Evidence: `COMPLETE_UI_MAP_ROOMS_STAGE_12_REVIEW_2026-10-24.md` and `evidence/complete_ui_stage12/`. Original detailed package Loot file was unavailable locally; supplied staged prompt and retained audit supplied the approved scope.
- Scope: no new room, loot, recipe or economy authored. Future Treasuries/traps use the transaction/persistence foundation in their own stages. Stage 06–12 changes remain local/uncommitted; unrelated Content Workbench changes preserved. Stop for user review/continue.


## Stage 13 execution record

- Authorization: “Resume task. After stage 12 is complete, proceed with stage 13”, 2026-10-24. Stage 12 completed first; no Stage 14 implementation.
- Outcome: current-run Party inspection using standing art, live stats/conditions, existing authored skills/progression/equipment and shared read-only Ability view. Earlier/later moves apply immediately to presentation only. Solo/duo/trio use current members exclusively; no roster selection or Refuge draft changes.
- Ownership and persistence: new optional `party_display_order` in existing active-run snapshots. Legacy defaults to current/departure roster order; explicit invalid permutations reject transactionally. Main room callback updates live order and existing safe points persist it. No schema version bump or mid-node save. Combat roster, stable order, actor, initiative, Actions, positions and ownership stay unchanged.
- Tests: validator passes (253 named classes); official 63/63 Godot scripts, exit 0, with zero GDScript runtime/compile/parse errors; Python 13/13; Party state 22/22; final headless/native UI each 52/52. Final diff/check/stat review completed.
- Native QA: real room and combat hosts plus actual main-controller binding; injected mouse and B/Tab/Escape; four supported resolutions; 14 captures generated, five retained and visually inspected. Existing five ObjectDB / three resources teardown diagnostics remain. Normal-campaign and physical-controller acceptance pending.
- Evidence: `COMPLETE_UI_MAP_ROOMS_STAGE_13_REVIEW_2026-10-24.md` and `evidence/complete_ui_stage13/`. Original detailed archive remains unavailable locally; supplied staged prompt, retained audit and repository contracts define scope. No new content or economy authored; no unresolved Stage 13 gameplay design blocker.
- Git: Stage 06–13 changes remain local/uncommitted, unrelated Content Workbench changes preserved. Stop for Stage 13 review/continue before Stage 14.


## Stage 14 execution record

- Authorization: “Good, proceed with stage 14.” On 2026-10-25 the user specified half HP/MP per Rest for all heroines, +10 Corruption to all, and revival. Applied to current active heroines, half maxima rounded up and capped; rounding stated before implementation. Each confirmed success consumes one of two uses, cancellation consumes none.
- Outcome: compact pre-Refuge Rest confirmation/count; revival and existing HUD refresh; simple Return confirmation on exploration dock and existing map action. Dialogue/story, targeting, Backpack/Loot and Party guards; modal input blocking and Escape/focus restoration. Refuge bed and Stage 20 Rest rooms remain separate.
- Ownership: existing RunState/BattlerState, room outcome, Refuge return transfer and atomic save store remain owners. Return stages current room party/bags/equipment/dialogue state, writes Refuge, then publishes; failure preserves the live run/room and previous durable save for retry. New equipment identity/condition and remaining materials survive once.
- Persistence: optional `ordinary_rest_uses`, absent defaults to 0; malformed explicit values reject before restore commit. New runs reset it; layer continuation retains it. Existing pre-node/post-resolution saves persist stats and count together. No mid-node save or version bump; interrupted Rest restores prior stats/count/seed.
- Validation: structural validator 254 classes; official 65/65 Godot scripts, exit 0, no GDScript runtime/compile/parse errors; Python 13/13; state 40/40; final headless/native UI 40/40. Final diff/check/stat review passes.
- Native QA: four resolutions, actual room/main Return and isolated real Rest UI; mouse, Escape/B blocking, revived HUD, used-count exhaustion, save failure/retry, acquired equipment preservation. Ten captures generated, five retained. Enlarged confirmation text after screenshot review. Known five ObjectDB / three resource teardown diagnostics retained. First native permission review timed out; allowed retry succeeded.
- Evidence: `COMPLETE_UI_MAP_ROOMS_STAGE_14_REVIEW_2026-10-25.md`, `evidence/complete_ui_stage14/`. No Stage 14 design blocker. Normal campaign and physical gamepad acceptance pending; no Stage 15 implementation.
- Git: Stage 06–14 remain local/uncommitted; unrelated Content Workbench changes preserved. Stop for Stage 14 user review/continue.


## Stages 01–14 publication checkpoint — 2026-10-25

- User authorized committing and uploading the completed work, with a branch name identifying Stages 01–14. Target: `codex/complete-ui-map-rooms-stages-01-14` in `FuryFluffy/AB_Godot_project`.
- This checkpoint adds Stages 06–14 to the previously published Stages 01–05. Earlier “local/uncommitted” entries describe their original stage handoffs. Stage 15 has not begun.
- Publish the committed source tree on the existing separate publication ancestry, continuing `4cadcddb89c15506bae4ae3cba0dd433e1965314`; do not merge development history or its oversized archival blobs. Keep the old remote branch available.
- Exclude unrelated Content Workbench plugin, documentation, test and runner registration. Preserve those changes in the development workspace. The published suite therefore contains 64 scripts; the development suite's 65th script is the unrelated Content Workbench test.
- Existing stage reports retain automated and native QA evidence, save compatibility details, and outstanding normal-campaign/physical-gamepad acceptance. No new gameplay changes are part of publication.
