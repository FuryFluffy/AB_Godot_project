# Stage 14 — Ordinary Rest and Return

Authorized by “Good, proceed with stage 14.” The user resolved the previously open Rest rule on 2026-10-25: half HP/MP per use for all heroines, Corruption for all, and revival for all. Implementation applies to every current active heroine, adds half maximum HP/MP rounded up, caps HP/MP at maximum and Corruption at 100, and revives defeated members through HP recovery. Rounding was stated before implementation. Stage 15 is not included.

## Player behavior

Before the Refuge exists, the exploration dock shows `Rest (2/2)`, then `Rest (1/2)` and disabled `Rest (0/2)`. A small confirmation states the recovery, revival, +10 Corruption per heroine and remaining uses. Each successful confirmation consumes one use, including a confirmed rest when already at resource caps. Cancelling consumes nothing. Resolve, Actions, equipment, items, keys and materials are unchanged. Recovery and revival immediately refresh the existing party cards.

After Refuge establishment, the same action becomes Return and asks only “Return to the Bloom Refuge?” The existing map Return action now uses the same confirmation. Returning captures the room's current party, Item Bar, bags, equipment and dialogue outcomes, then uses existing voluntary-return banking/recovery rules. It does not clear an unfinished encounter or grant its reward. A failed save leaves the live room/run and prior durable boundary intact, allowing a safe retry. A successful return saves Refuge before retiring the room and replacing the live run.

Dialogue/story sequences, pending item targeting, Backpack/Loot and Party inspection block recovery. The confirmation blocks input behind it, defaults focus to Cancel, and restores focus on Escape/cancellation. No combat or Struggle recovery action was introduced. Refuge bed recovery and the later single-offer Rest rooms remain separate.

## Files and existing owners

- `scripts/map/run_state.gd`: ordinary Rest access, request validation, atomic party/count update, optional saved count; stages a validated voluntary return using the existing snapshot, room-outcome and Refuge-transfer owners.
- `scripts/map/main_controller.gd`: supplies recovery callbacks, presents existing map Return confirmation, saves staged Return through `CampaignSaveSlotStore` before switching live state and showing the existing Refuge hub.
- `scripts/exploration/event_room_screen.gd`: exposes existing room outcome capture without requiring an exit signal; attaches the recovery dialog, guard and callbacks. Existing ordinary room exit still emits the same outcome.
- `scripts/exploration/ui/exploration_command_bar.gd`: Rest/Return intention, availability and remaining count.
- `scripts/exploration/ui/run_recovery_dialog.gd` (+ UID): small reusable confirmation with no gameplay or save authority.
- `tests/test_run_recovery.gd`, `tests/test_run_recovery_ui.gd`, `tools/verify_run_recovery.gd` (+ UIDs): state/persistence, native input and real main-controller room Return coverage; both tests registered in `tools/run_regression_suite.py`.
- `tools/verify_run_party.gd`: retains its fixture main controller until the room is freed, matching the lifetime required by the new live recovery callbacks. Existing Party assertions retained.
- This report, the combined ledger and `docs/evidence/complete_ui_stage14/`.

No equipment definitions, recipes, economy, narrative, map generation, or room activation changed. Newly collected equipment used in verification is an explicitly injected fixture instance routed through the existing Loot transaction.

## Persistence and compatibility

Adds optional `ordinary_rest_uses` to the existing active-run snapshot. Legacy saves default to zero uses. Explicit noninteger, negative, greater-than-two, string, boolean and null values reject before restore commits. New-run initialization/departure resets the count; continuing across a layer does not. No save version bump or second save store.

Rest updates live state and count together but writes no mid-node save. Existing pre-node/post-resolution safe points persist both; interrupted nodes restore the previous HP/MP/Corruption/count and identical content seed. An injected post-node write failure preserves the previous complete snapshot, and a retry saves the recovered state and consumed use together.

Return validates current room bags against current equipment, rather than stale room-entry bags. It applies the room outcome to an isolated existing RunState, prepares the existing Refuge transfer, writes it atomically and only then publishes it. Failed preparation or writing cannot duplicate Bloom/materials/equipment by replaying an already-applied live outcome. Successful Refuge save clears the active-run snapshot using the existing store behavior.

## Verification

- Structural validator: passes, **254 named classes**.
- Python unit tests: **13/13 pass**.
- Focused Recovery state/persistence: **40 checks, zero failures**.
- Final native Godot Recovery fixture: **40 checks, zero failures** at 1920×1080, 1600×900, 1280×720 and 1024×768. Ten captures generated; selected final captures retained. Mouse confirmation/cancellation, keyboard Escape/B blocking, focus restoration, revival/counter refresh, all context guards, map confirmation, actual authored Layer 2 room Return, injected save failure/retry, and newly acquired equipment identity/condition checked. Dialog text enlarged after inspecting initial screenshots, then recaptured and inspected.
- Cumulative suite: **65/65 regression scripts pass, exit 0**, including final Recovery state **40/40** and UI **40/40**. Zero GDScript runtime/compile/parse errors.
- Final editor import generated all four new UID sidecars; no script errors. Final `git diff --check` passes; reviewed diff/stat and complete Stage 14 changes.

Commands: `python3 tools/validate_project.py --allow-generated-cache`; `GODOT_BIN=/home/fluffy56/.local/bin/godot4 python3 -B tools/run_regression_suite.py`; `python3 -B -m unittest discover -s tools -p 'test_*.py'`. Native entry: `godot4 --path . --audio-driver Dummy --script res://tools/verify_run_recovery.gd -- --recovery-captures=/tmp/ab-stage14-captures`, using isolated temporary XDG directories. Test saves use dedicated test directories, not player slots.

The initial native launch permission review timed out; its allowed retry succeeded. Final native runs retain the known five ObjectDB / three resources shutdown diagnostics. Deliberate corrupt-save regression cases may print JSON parse errors. Script runtime/compile errors are checked separately. Native fixtures are not a full campaign playthrough: Rest uses an isolated real room UI with controlled stats; Return uses the real main controller and generated authored room.

## Player checklist and remaining acceptance

1. Before Refuge, enter an exploration room with injured/heroines at zero HP. Open Rest, cancel, then confirm. Check half maximum HP/MP (odd values round up), revival and +10 Corruption for every active heroine.
2. Use Rest a second time; confirm it is disabled at zero uses. Complete the room and Continue from Main Menu to verify stats/count. Interrupt before room resolution to verify the earlier safe point is restored.
3. Check Rest/Return stays unavailable during dialogue, targeting, Backpack/Loot and Party inspection.
4. After Refuge, collect room items/materials, cancel Return, then confirm. Verify safe Refuge arrival, existing HP/MP recovery, carried-item/equipment preservation and one-time banking.

Full normal-campaign and physical gamepad acceptance remain pending. No Stage 14 design blocker remains. The original detailed package remains unavailable locally; scope comes from the supplied staged prompt, retained audit, repository behavior and the user's explicit Rest clarification.

Suggested commit: `feat: add two-use party rest and transactional refuge return`

Changes remain local/uncommitted alongside Stages 06–13. Unrelated Content Workbench changes are preserved. Stop before Stage 15 for user verification/continue.
