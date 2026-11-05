# Complete UI / Map / Rooms — Stage 22 review

Stage 22 implements Intel purchases, temporary/permanent ownership, seven map benefits and the permanent Submit upgrade. The user authorized Stage 22, approved provisional prices of **10 Bloom per supported one-run Intel option**, **1,000 Bloom per permanent counterpart**, and **100 Bloom for Submit**, and chose the **older level-1 Grapple bundle** for that unlock. Castle Memory and Conqueror’s Passage remain unavailable until Stage 23. No production recipes are added.

## Player behavior

The existing Refuge Expedition → Intel page now offers This Run and Permanent purchases, supplied manifest icons, actual prices, affordability and ownership states. Viewing is free. A purchase immediately deducts Bloom once and saves the entitlement; Cancel, closing preparation, reopening and Load retain it without refund. Duplicate purchases are free no-ops. A permanent benefit disables its temporary repurchase. Buying a permanent benefit after a temporary one does not refund the earlier payment.

Explore stages the existing Layer 2 departure and saves its new active-run checkpoint and consumed pending ownership in one atomic document. A failed write leaves the Refuge, wallet, purchases and previous durable document intact. Successful departure does not charge again; the existing discard of unspent Bloom remains unchanged and visible in preparation. Continue immediately after Explore restores the same paid benefits and map knowledge. The fallback Refuge boundary contains no reusable pending entitlement. Return/defeat ends temporary benefits; permanent benefits survive into subsequent runs.

- Scouting identifies neighbors through the existing eligible adjacency/exit discovery, preserving hidden and locked exit restrictions.
- Battle Sense identifies Normal and Elite Combat nodes only.
- Smell of a Coin selects one Treasury consistently from stable IDs and the run seed, then reveals a deterministic real graph route from the layer entry. No synthetic direct edge is drawn.
- Pathfinding reveals graph connections. It does not identify room types or open blocked passages.
- Sanctuary Sense identifies Rest nodes; Danger Sense identifies Trap rooms without exposing particular item traps; Artisan’s Eye identifies Alchemy and Workshop nodes.

Benefits compose additively and never erase known nodes/routes. Knowledge and physical accessibility are separate: an Intel-known hidden/locked passage can appear with a blocked indicator, but travel still rejects it. Undiscovered hidden connections remain absent from the view. The Stage 16 test that suppressed even explicitly known hidden edges was superseded by Stage 22’s approved connection-reveal behavior; it now checks both known-but-blocked and unknown-hidden cases.

Submit appears only with the permanent entitlement in Grapple context. An eligible, non-defeated, non-Stunned heroine in Hero Phase spends all remaining Actions to advance the main track once and receive one point of healing. HP fills first, then unused healing restores MP. Pending targeting/reaction/resolution and zero Actions reject the request. The action does not end Hero Phase, and Grapple still disables Backpack.

Per the user’s explicit choice, ownership also changes ordinary Climax damage from 15% to **25% of enemy maximum HP**, retaining the existing ceiling/minimum convention, and adds a separate **2-point Climax healing instance**. Submit healing resolves before Climax healing. Enemy-driven Climax receives the same upgrade. Main/secondary track succession, stage effects, cooldown and detachment remain with GrappleController. Climax recovery may raise a defeated heroine’s stored HP but never revives her. No level-2 upgrade is implemented.

## Implementation and files

- `scripts/intel/` and `data/intel/intel_catalog.tres`: configurable option Resources, permanent price calculation and map-effect handlers. Prices are explicitly marked provisional in data. Existing map art is resolved through its manifest; no new art is authored.
- `scripts/refuge/refuge_ownership_state.gd`, `refuge_management_controller.gd` and `ui/refuge_expedition_view.gd`: pending/permanent ownership, staged wallet-plus-entitlement purchase and the existing preparation interface.
- `scripts/map/run_state.gd`, `main_controller.gd`, `layer_map_graph.gd`, `layer_map_view.gd` and `scripts/save/campaign_save_slot_store.gd`: departure persistence, active benefit reconstruction, adjacency integration and independent known/blocked rendering.
- `scripts/battle/runtime/combat_engine.gd`, Grapple controller/result, encounter coordinator and reusable command presentation: entitlement propagation, rule-owned Submit and the approved level-1 effects.
- Three regression entries cover Intel state, Submit rules and the production interface. The native verifier and existing map/HUD checks cover updated visibility contracts. Documentation and retained evidence identify the exact Stage 22 delta against `/tmp/ab-stage22-baseline`.

The retained manifest identifies **32 source/content/test/UID files** changed for Stage 22. Eight manually inspected screenshots are retained. Final Stage 22 diff review, `git diff --check` and cumulative `git diff --stat` have been reviewed.

Earlier stages and unrelated Content Workbench changes are preserved. No commit or push is part of this stage request.

## Persistence and compatibility

No save-version bump or destructive migration. Optional `pending_intel` and `permanent_intel` arrays live in existing Refuge ownership snapshots; absent fields restore as empty/unowned. Explicit malformed values, duplicates, unknown IDs, gated options and temporary Submit reject transactionally.

The already-saved active-run Refuge departure boundary retains that expedition’s paid temporary benefits. Active ownership has consumed its pending list, so Continue can reconstruct benefits without manufacturing another pending purchase. Permanent entitlements use existing ownership copies, departure and return paths. Ordinary node safe points remain authoritative; no mid-combat or mid-dialogue saves are introduced. The new departure write retains CampaignSaveSlotStore validation, atomic replacement and backup behavior.

Validated map reservation enum values are normalized to integers during JSON restore. This fixes an exact round-trip mismatch between JSON numeric values and generated enum integers without changing node types, layout, seeds or activation. No old map is regenerated. New known-hidden edge combinations are valid knowledge states; `hidden` still blocks physical traversal.

## Verification and remaining acceptance

- Focused Intel state: **3,602 checks, zero failures**, including individual effects over twenty seeds, all 128 benefit combinations, failed purchases, duplicate/insufficient/stale-price handling, malformed/legacy ownership, deterministic Treasury routing and return/defeat/next-run scope.
- Submit rules: **49 checks, zero failures**, including one remaining Action, phase/targeting/Stun/defeat guards, exact healing overflow/caps, 25% Climax damage, enemy-driven recovery, defeated-state preservation and secondary-track succession.
- Production interface: **49 headless and 49 native checks, zero failures**. Tests use actual Main/Refuge/map/combat/save hosts, real purchase/Explore/Submit input, failed purchase and departure writes, Cancel/reopen/Load, Continue, and four resolutions: 1920×1080, 1600×900, 1280×720 and 1024×768.
- Python tooling: **13/13 passed**. Project validator: **269 named GDScript classes**. Editor import has no GDScript parse/compile errors; restricted headless editor networking emits its existing socket-startup diagnostics.
- Revised native map verification: **101 checks, zero failures**, including Intel-known blocked routes and undiscovered hidden routes. Final uninterrupted official cumulative suite: **82/82 regression scripts passed, exit 0**, with no GDScript parse/compile/runtime errors. Nine verification logs are retained.

Native QA used Godot 4.7.2 Compatibility on Intel Iris Xe. Screenshots were manually inspected for readable option descriptions/prices, ownership states, scrolling/focus, map knowledge and usable Struggle controls. Prior campaign progression, Bloom balance and combat positioning are explicitly fixture-controlled; the purchase, persistence, launch and combat actions are production handlers. A full manually played campaign and physical-gamepad acceptance remain pending.

The first cumulative attempt exposed the superseded Stage 16 hidden-edge expectation and was deliberately stopped before restarting with the corrected contract. Earlier development checks also caught and fixed the map numeric round-trip mismatch. Existing ObjectDB/resource shutdown diagnostics and deliberate corrupt-save diagnostics remain in retained logs; they are not counted as gameplay failures.

No unresolved design blocker remains for the authorized scope. Prices are provisional balance; Stage 23’s Castle Memory and Conqueror’s Passage are truthfully unavailable and cannot charge.

## Handoff

Reproduce the native production flow with `tools/verify_intel.gd` using isolated Godot user/config/cache directories and `--intel-captures=/tmp/intel-captures`. Normal-play acceptance: open Refuge Intel, buy an affordable option, close/reopen preparation, Load, Explore and Continue; verify the paid benefit, then Return or defeat and check its lifetime. Purchase Submit permanently and verify it only in an eligible Grapple.

Changes remain local and uncommitted. Suggested commit: `feat: complete stage 22 Intel purchases and Submit upgrade`.

Next milestone: **Stage 23 — Castle Memory and Conqueror’s Passage**, awaiting instruction.
