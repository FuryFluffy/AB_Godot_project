# Complete UI / Map / Rooms — Stage 23 review

Stage 23 implements Castle Memory and Conqueror’s Passage through the existing Refuge preparation, map, run and atomic-save systems. The user authorized Stage 23 and approved provisional prices: Castle Memory costs 10 Bloom for one expedition or 1,000 permanently; Passage costs 100 Bloom × the selected layer for one expedition, with permanent ownership at 100× that layer’s one-run price. No later-layer content or cross-layer travel is activated.

## Player behavior

Castle Memory retains the latest full generated layout for each supported layer, including positions, authored room identities, room types, connections and discovered type/route knowledge. Unknowns remain unknown unless entry discovery or another owned Intel benefit reveals them. The snapshot survives return, defeat and Continue. Tutorial layer transitions preserve the completed Layer 1 layout; the transient two-node Jailer story threshold does not overwrite a full expedition layout. If no layout has been recorded for the selected departure, preparation explicitly says that a new one will be generated.

Layout identity has its own seed. Each memory expedition derives new content randomness from the new preparation seed and the preceding run identity, so repeating a seed does not simply replay the previous contents. New room states, loot claims, Material grants, Rest uses/offers and item-trap assignments are created through their existing handlers. Prior collected/solved/used state is not restored. Permanent boss defeats remain authoritative. Remembered routes retain knowledge while current authored exit locks are read afresh; an old opened Wine Cellar door is locked again until its current interaction resolves it.

Conqueror’s Passage offers only Layer 1 or Layer 2 bosses that have been permanently defeated, with an established Refuge. Floor access alone is insufficient. Intel shows the chosen layer and its exact price before purchase. A successful purchase immediately deducts Bloom and persists ownership; duplicate purchases do not recharge, and permanent ownership prevents temporary repurchase for that same layer. Each layer is owned separately.

The Expedition departure selector offers the ordinary Layer 2 Farthest Cell start and owned, eligible boss-room starts. Changing this selection, closing preparation or loading does not refund or erase paid shortcuts. Starting consumes only the corresponding temporary Passage; other paid layers remain available even after an unrelated expedition. Permanent Passage survives repeated departures. The existing Party draft/Apply flow and normal starting inventories/equipment are retained.

A shortcut visits only the dead boss room. Skipped rooms receive no visits, completion, XP, loot, Materials or recipe discoveries. The boss yields no repeat kill reward. Known open adjacent passages permit ordinary within-layer backtracking. Layer 1 departures use the existing generated-key rules with fresh run randomness; Continue retains that placement. Old recruitment encounter IDs cannot insert an inactive heroine into a post-Refuge party.

Explore retains the atomic departure document: failed writes leave live preparation, purchases, Bloom and the previous save intact. Successful writes consume the used rights in both the active state and fallback Refuge, preserving unused Passage entitlements. Unspent Bloom is discarded under the existing departure rule; there is no second purchase charge.

## Files and compatibility

The Stage 23 source manifest is `evidence/complete_ui_stage23/files_changed.txt` with SHA-256 hashes. Changes cover the new `CastleLayoutMemory` handler; Intel option data/pricing; map/run state and Main departure; Refuge ownership/purchases/preparation; atomic departure persistence; focused state/interface tests and the regression runner. Stage 22 assertions that intentionally gated these options were updated for their newly authorized availability. Earlier stages and unrelated Content Workbench edits are preserved.

No save-version bump or destructive migration. `layout_seed` defaults to a legacy graph’s existing run seed. Optional `castle_layouts`, `pending_passage_layers`, `permanent_passage_layers` and `selected_passage_layer` fields default to empty/unselected. Memories are also included in active-run safe points so pre-Refuge transitions can survive Continue. JSON integer-valued numbers are validated and normalized for layer entitlements; malformed, duplicate, unsupported or unowned selections reject transactionally. Generic Intel arrays reject a layerless Passage entitlement.

The existing save envelope v3, atomic writes, recovery/backups and pre-node/post-resolution boundaries remain intact. No mid-combat or mid-dialogue saving is introduced. Production recipes remain empty under the earlier user decision.

## Verification

- Focused state: **1,524 checks, zero failures**, covering both layers over ten layout seeds each; memory identity/knowledge/content reset; repeated seeds; current authored locks; temporary/permanent layer rights; duplicate/stale-price/save-failure handling; normal and shortcut departures; return/defeat; selected-party preservation; key-placement persistence; malformed fields and older saves.
- Production interface: **37 headless and 37 desktop checks, zero failures**. Actual Main/Refuge/save hosts exercise purchases, Cancel/reopen/Load, departure changes, failed purchase/departure writes, both boss starts, Continue, Return, unused entitlement preservation and actual backtracking into the adjacent Layer 1 encounter.
- Native Godot 4.7.2 Compatibility on Intel Iris Xe: **12 screenshots manually inspected**, covering 1920×1080, 1600×900, 1280×720 and 1024×768. Prices, layer labels, scrolling/focus, departure selection, boss status and remembered/unknown room knowledge are readable. Prior story/boss deaths, wallet and initial memory are fixture-controlled; purchases, persistence, launches and backtracking use production handlers.
- Python tooling: **13/13 passed**. Project validator: **270 named GDScript classes**. Final `git diff --check` passes.
- Official cumulative suite: **84/84 regression scripts passed, exit 0**, with no GDScript parse/compile/runtime errors. The retained `regression.log` contains the final uninterrupted run. Existing ObjectDB/resource shutdown and deliberate corrupt-save diagnostics remain; they are not new gameplay failures.

Development checks caught and corrected a GDScript dependency cycle, JSON number normalization and an untyped empty-array argument on the new optional Layer 1 placement path. Earlier development logs are retained in `evidence/complete_ui_stage23/development/`, separately from the final results. The key-placement continuation assertion compares every field after the same JSON normalization on both sides; no gameplay expectation was relaxed. A desktop-check attempt was temporarily prevented by automatic approval review reaching a usage limit; a later retry was accepted.

Full normal-play campaign acceptance and a physical-gamepad pass remain separate from the automated native-input fixtures. Stage 24 is the next combined end-to-end acceptance milestone and is not part of this authorization.

## Handoff

Stage 23 is complete locally. Full Stage 23 changes and cumulative diff/stat/check were reviewed, and the source manifest hashes match the verified files. No unresolved design decision remains for Stage 23; prices are explicitly provisional. Changes remain local and uncommitted. Suggested commit: `feat: complete stage 23 Castle Memory and layer-specific Passage`.
