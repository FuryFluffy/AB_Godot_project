# Stage 11 — run Backpack and combat permissions

Authorized by “Good, proceed to stage 11”; resumed 2026-10-21. Stage 12 has not begun. Changes remain local and uncommitted alongside Stages 06–10; unrelated Content Workbench work is preserved.

## Player behavior

The existing BackpackView now opens from the run HUD Backpack button or B. Exploration shows current expedition heroines, the same fifteen-slot 3×5 grid, details and shared Key-ring. The native six-slot Item Bar stays in its HUD position and remains the sole transfer source/destination. No Stash is exposed.

Mouse drag, right-click Move/exchange or Split, and keyboard/controller context-menu source/destination selection use the existing fixed-slot algorithm. Matching stacks merge up to authored limits, retaining excess at source; full matching targets are no-ops. Different-item swaps return displacement to the exact source slot; partial different-item swaps reject. Exploration transfers and rearrangement within one bag are free.

Combat opens on the selected acting heroine under the existing Hero Phase rules. Each positive Backpack ↔ Item Bar operation or carried Main Hand weapon/Armor replacement spends exactly one of her Actions. Equipment displacement returns to its exact source; instance identity and condition remain with existing registered objects. Separate changes cost separately. Costs appear before commitment. Viewing another heroine is read-only and cannot change the actor or spend her Actions.

Opening, browsing, previewing, cancelling, invalid changes and no-ops are free. Zero-Action actors can browse but cannot mutate. Grapple, Stun, enemy phase, unresolved targeting/reactions and command locks enforce the existing eligibility rules. Grapple also closes an already open panel; B cannot bypass it. An outstanding exploration Item Bar target must be completed or cancelled before opening Backpack, so inventory movement cannot replace its pending item. Item Bar clicks while managing inventory select a transfer destination rather than using the item. Outside the panel, existing item-use costs and restrictions resume.

Memento equip, Shield/off-hand changes, cross-heroine handoffs, standalone unequip and direct Backpack Use/Discard are not enabled. Current authored weapons are Main Hand; no additional equipment definitions or slot mechanics are invented. Out-of-combat loot Use/Discard and adjacent source panels remain Stage 12.

## Existing owners and files

- New `scripts/inventory/run_backpack_controller.gd`: stages transactions over RunInventoryState, SixSlotInventoryState and RunEquipmentState; rejects stale inventory, condition and turn snapshots. Publishes ownership and Action deduction together after validation, then emits observer signals.
- `scripts/inventory/refuge_inventory_transfer.gd`: exposes the existing fixed-slot move/merge/swap algorithm for run callers. Refuge quick transfers and persistence remain unchanged.
- New `scripts/inventory/run_backpack_panel.gd`: reuses BackpackView, HeroineSelector, RefugeSlotGrid, InventorySlotPresenter and existing ItemBarView. Adds context/split interaction, nested cancellation, focus traversal, read-only browsing and input shields around the existing Item Bar.
- `scripts/battle/runtime/combat_engine.gd`: owns authoritative combat permission checks and binds current run ownership. Direct scene launches receive empty bags backed by existing battler equipment, without granting new carried equipment.
- `scripts/battle/encounter_coordinator.gd`: binds the panel, routes B/cancel and Item Bar selection, and preserves actor/targeting while the panel is open.
- `scripts/exploration/event_room_screen.gd` and `scripts/exploration/ui/exploration_hud.gd`: bind current run bags and shared keys, route inventory inputs, and prevent dialogue access bypass.
- `scripts/battle/presentation/reusable/{run_hud_dock,item_bar_view}.gd`: context-aware Backpack availability and management presentation that keeps empty destinations enabled through deferred combat refreshes.
- New `tests/test_run_backpack.gd`, `tests/test_run_backpack_ui.gd`, `tools/verify_run_backpack.gd`; extended `tests/test_active_run_safe_points.gd`; registered both new scripts in `tools/run_regression_suite.py`. Generated Godot UIDs accompany new scripts.
- This report, stage ledger and `docs/evidence/complete_ui_stage11/`.

## Compatibility and persistence

No save migration, schema/version bump, new item IDs, altered economy, room activation or new inventory owner. Production v3 remains intact. Runtime equipment instance objects are retained so existing WeaponState/ArmorState adapters receive the new equipped assignment and preserved condition.

Backpack operations do not introduce mid-combat/mid-dialogue saves. Combat uses the current run ownership already bound to RunEquipmentState; exploration returns its existing inventory outcome. The established pre-node and post-resolution safe points persist the result. Tests confirm interruption restores the original pre-node inventory and encounter seed, a failed post-node write preserves that recoverable save, and a successful post-node reload retains the transfer without duplication. All fallible inventory/eligibility validation happens before the in-memory commit, so rejection changes neither ownership nor Actions.

## Validation

- `python3 tools/validate_project.py --allow-generated-cache`: passes, 248 named classes.
- `python3 -B -m unittest discover -s tools -p 'test_*.py'`: 13/13 pass.
- Focused transaction tests: 39 checks, zero failures. Cover whole moves, exact-source swap, split, partial merge, full-stack no-op, insufficient Actions, stale requests, forbidden destinations, other heroine access, Grapple/Stun/turn locks, equipment preview/replacement/condition/adapters, JSON reload, free exploration and atomic observer visibility.
- Active-run safe-point tests: pass, including the new real save-store transfer/interruption/failed-write/reload coverage. The initial added fixture left a third slot affecting a pre-existing newest-slot test; fixture cleanup was corrected, with original expectations retained.
- Existing Stage 03 transfers: zero failures. Existing Stage 10 HUD fixture: 488 checks, zero failures.
- Final native Compatibility-renderer fixture: 50 checks, zero failures at 1920×1080, 1600×900, 1280×720 and 1024×768. Covers the actual encounter and EventRoomScreen, native drag, keyboard context selection, nested cancellation, one/two/three selectors, read-only browsing, context costs, input shields, dialogue guard and Grapple button/shortcut invalidation.
- Full official Godot 4.7.2 suite: **59/59 scripts pass**, exit 0, zero GDScript runtime/parse errors. The new UI fixture reports 50 checks in both headless and native runs; the final exploration targeting guard also passes a separate opening/Event-room flow rerun.
- `git diff --check`: passes. Full Stage 11 source/test changes and cumulative diff/stat reviewed; earlier milestone and unrelated Workbench changes preserved.

Native and scene tests retain the established five ObjectDB/three-resource teardown diagnostics. Save tests deliberately exercise corrupt JSON and write failures. These are distinguished from assertion or GDScript failures; no leak-free claim is made.

## Visual QA and remaining player acceptance

Actual Godot captures inspected at all four resolutions: the panel fits above the dock/Log tab, the grid is 3×5, cost/read-only labels are readable and the original Item Bar remains available. Equipment names may truncate in narrow slots; selection details and tooltips expose the full name and condition. The 4:3 fixture retains existing battlefield framing, including uncovered background outside the authored camera area. The exploration fixture mounts the actual room controller/HUD without a room presentation background; its grey background is fixture-only.

The native fixture uses temporary XDG profiles, in-memory stacks and one explicitly labelled spare instance of an existing authored weapon to exercise condition display. These are test data, never production rewards or save grants. A full campaign playthrough and physical gamepad acceptance remain pending.

Player checklist:

1. During free exploration, open Backpack/B, switch current heroines, split and move items to/from the existing Item Bar; confirm no Stash and no Action charge.
2. During a legal Hero Phase, select a heroine and open Backpack. Browse another heroine and cancel for free. Return to the actor and perform two valid separate changes; each spends one Action. A full matching-stack/no-op or rejected partial swap spends none.
3. With carried compatible weapon/Armor, use its context menu to replace equipment; confirm the old instance returns to the exact bag slot and condition is preserved.
4. Check Escape/right-click cancellation and keyboard/controller source/destination selection. While grappled, Backpack and B remain unavailable.
5. Resolve the node, Continue/Load through the Main Menu and confirm the completed transfer. Interrupting before resolution should replay from the pre-node save with the original inventory and seed.

Reproduce isolated native checks:

```sh
XDG_DATA_HOME=/tmp/ab-stage11-native-data XDG_CONFIG_HOME=/tmp/ab-stage11-native-config XDG_CACHE_HOME=/tmp/ab-stage11-native-cache godot4 --path . --audio-driver Dummy --script res://tools/verify_run_backpack.gd -- --backpack-captures=/tmp/ab-stage11-captures
```

No unresolved design blocker for Stage 11. Later loot source lifetime and Use/Discard remain Stage 12. Suggested commit: `feat: enable run backpacks with atomic combat action costs`.
