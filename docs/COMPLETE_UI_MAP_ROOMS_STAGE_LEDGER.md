# Combined UI, map and rooms stage ledger

Updated 2026-10-15. This is the single Stage 00–24 ledger for `AB_Complete_UI_Map_and_Rooms_v1`; it replaces neither existing runtime state nor historical checkpoint evidence. Follow the supplied root `02_IMPLEMENTATION_STAGES.md`. Work proceeds one authorized stage at a time and pauses for user verification/continue after each stage. Corrections remain in the current stage.

Stage 00 report: `COMPLETE_UI_MAP_ROOMS_STAGE_00_AUDIT_2026-10-09.md`.
Executed evidence: `COMPLETE_UI_MAP_ROOMS_STAGE_00_BASELINE_2026-10-09.md`.

| Stage | Deliverable | Implementation | Executed checks | User verification | Evidence / dependency |
| --- | --- | --- | --- | --- | --- |
| 00 | Local audit and combined plan | Complete (audit documents only) | Baseline complete; 48/48 direct Godot scripts, 4/4 Python; structural gate fails; graphical QA unavailable | Accepted to proceed | Audit committed as `cdd0830`; no gameplay/UI edits |
| 01 | Refuge room framework | Complete; committed/pushed | 48/48 direct Godot scripts; expanded UI checks; 4/4 Python; 36 graphical fixture captures; historical structural failures repaired in Stage 02 | Continue authorized; player QA pending | `COMPLETE_UI_MAP_ROOMS_STAGE_01_REVIEW_2026-10-10.md`; original background, five props/eight hotspots, menus/focus; Compatibility explicit |
| 02 | Shared inventory views | Complete; committed/pushed | Structural validator passes; 49/49 regression scripts; 9/9 validator tests and 4/4 runner tests; 45 actual Godot captures | Continue authorized; player QA pending | `COMPLETE_UI_MAP_ROOMS_STAGE_02_REVIEW_2026-10-14.md`; mixed ownership, independent selector, native contextual bar |
| 03 | Atomic inventory transfers/stacks | Complete; local/uncommitted | 50/50 Godot scripts; 13/13 Python tests; 100-operation conservation sequence; 60 native-input/capture checks | Pending | `COMPLETE_UI_MAP_ROOMS_STAGE_03_REVIEW_2026-10-15.md` |
| 04 | Refuge Loadouts | Not started | Not run for new target | Pending | All named sources; exact-source exchange; Shield/Off Hand mapping |
| 05 | Repair/Salvage | Not started | Not run for new target | Pending | Reuse repair recipe, condition and salvage yields |
| 06 | Alchemy/Crafting | Not started | Not run for new target | Pending | Explicit production providers; authored output recipes missing |
| 07 | Refuge bed | Not started | Not run for new target | Pending | Recovery amounts/costs missing |
| 08 | Expedition/Party/Level Up/Intel shells | Not started | Not run for new target | Pending | Subset ownership must preserve inactive heroines; no paid shells |
| 09 | Records/Gallery | Not started | Not run for new target | Pending | Lore available; other content/replay mappings incomplete |
| 10 | Compact run/combat/Struggle dock | Not started | Not run for new target | Pending | Reuse HUD/Ability; later service actions gated |
| 11 | Combat Backpack permissions/Actions | Not started | Not run for new target | Pending | Actor-only atomic positive-operation cost; grapple guard |
| 12 | Loot/capacity/source lifetime | Not started | Not run for new target | Pending | Add fight abandonment; persistent room re-entry dependency |
| 13 | Current-run Party | Not started | Not run for new target | Pending | Immediate order without turn/roster mutation |
| 14 | Ordinary Rest/Return | Not started | Not run for new target | Pending | Ordinary recovery amounts/recipient scope missing |
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
- Evidence: `COMPLETE_UI_MAP_ROOMS_STAGE_03_REVIEW_2026-10-15.md` and `evidence/complete_ui_stage03/`. User verification, physical controller and normal-campaign save/load checks remain pending. No design blocker. Stage 04 has not started.
- Git: Stage 03 remains local and uncommitted, subsequent to the verified Stage 01–02 upload.

## Recorded boundary proposals for later stages

Keep all existing stage numbers and review pauses. Resolve carried ownership in 02 before 03/04; complete subset roster start/return in 08; include persistent room re-entry needed for Stage 12 acceptance in 12 while keeping discovery/Solved in 15. In 15, validate new special-room quotas in fixtures and gate production activation until the relevant 18–21 service/content stage works. Preserve small Jailer-entry/Refuge holding graphs as story transitions, not full-budget layers. Do not fold the pre-existing validator repair into Stage 01. See the audit for rationale and precise mappings.

## Evidence required when updating later stages

Record the actual authorized change, exact files/services, migration/default behavior, entry path/seed, commands and results, failure provenance, runtime image/video paths, manual checks actually performed, provisional data and blockers. Separate normal gameplay from fixtures and implementation from automated tests and user verification. Leave unavailable services gated. Stop after the current stage for verification/continue.
