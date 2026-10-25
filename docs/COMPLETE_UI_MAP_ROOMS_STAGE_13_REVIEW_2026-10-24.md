# Stage 13 — Current-run Party

Authorized by “Resume task. After stage 12 is complete, proceed with stage 13.” Stage 12 was completed and its evidence recorded before Stage 13 implementation. Stage 14 is not included.

## Player behavior

In an ordinary exploration room, Party opens inspection of the current run's members. Select a standing heroine to view her live HP/MP, Resolve, Corruption, status, authored attributes/skills, persistent weapon ranks, equipped instances/conditions, Shield and Memento. Abilities reuses the existing read-only exploration Ability panel. Move earlier/later applies the display order immediately; there is no Apply step for this screen. Refuge's separate draft-and-Apply expedition selection is unchanged.

Only current members appear. A solo party has no reorder operation. Inspection does not select a field item target. The modal blocks world/dock clicks and the Backpack shortcut; pending item targeting, dialogue and an open Backpack/Loot prevent opening it. Escape/right-click closes nested Abilities first and then Party, restoring focus. Keyboard navigation remains inside the current panel.

The order follows the run into later rooms and the next combat HUD. It never changes encounter composition, battlefield positions, battler instances, combat initiative/phase/round, the selected actor, Actions, equipment or inventory ownership. There is no new combat Party command or roster editing in a run.

## Implementation and changed files

- `scripts/exploration/ui/run_party_panel.gd`: current-member standing portraits, runtime inspection, immediate moves and nested shared Ability panel. Uses the existing visual profile catalog and existing state/loadout objects.
- `scripts/map/run_party_order.gd`: validates a complete member permutation and resolves presentation order when members join or a new context binds.
- `scripts/map/run_state.gd`: stores presentation order separately from gameplay `party_snapshot` and Refuge `selected_party_ids`; validates before restore commit; resets it at new-run initialization/departure and retains it across a continuing layer transition.
- `scripts/map/main_controller.gd`: supplies room order/commit callback and the next encounter's display preference.
- `scripts/exploration/event_room_screen.gd`, `scripts/exploration/ui/exploration_hud.gd`, `scripts/exploration/ui/exploration_command_bar.gd`: Party access, input/focus routing and immediate HUD refresh.
- `scripts/battle/presentation/reusable/run_hud_dock.gd`, `scripts/battle/encounter_coordinator.gd`: present the saved permutation without modifying engine order. Backpack selectors use the same presentation order.
- `tests/test_run_party.gd`, `tests/test_run_party_ui.gd`, `tools/verify_run_party.gd` and their UID sidecars: persistence/validation, actual room/main-controller callback, native input and combat invariants.
- `tools/run_regression_suite.py`: registers both focused scripts. `tools/validate_project.py`: supersedes the old fixed-order source assertion with normalized current-party display ordering.
- This report, the combined ledger, and `docs/evidence/complete_ui_stage13/`.

Shield inspection uses the production runtime shield bound to Off Hand. This milestone does not migrate the equipment slot enum or create another equipment authority.

## Persistence and compatibility

Adds optional `party_display_order` to the existing active-run `run_snapshot`. Missing legacy fields resolve to the current/departure roster order. Explicit malformed, duplicate, missing or foreign-member permutations reject before mutating live state. No save version bump. Production JSON/atomic store remains unchanged. A reorder updates live RunState only; existing pre-node/post-resolution saves persist it, so an interrupted node restores the prior safe point. No mid-node save is introduced.

## Verification

- Structural validator: **passes, 253 named GDScript classes**.
- Python: **13/13 tests pass** (`python3 -B -m unittest discover -s tools -p 'test_*.py'`).
- Focused state/persistence: **22 checks, zero failures**.
- Final native Godot Party fixture: **52 checks, zero failures**, four resolutions (1920×1080, 1600×900, 1280×720, 1024×768), 14 captures generated and five retained. Uses injected mouse clicks, B/Tab/Escape, real room/main callback and real combat host. Confirms object/roster/position/initiative/actor/Action/ownership preservation and one/two/three-member presentation. Inspected actual PNGs for panel/dock separation, equipment scrolling and nested Ability presentation.
- Cumulative suite: **63/63 regression scripts pass, exit 0**. Includes final Party state **22/22** and UI **52/52**, Stage 12 Loot **54/54** and UI **30/30**, Stage 11 Backpack **39/39** and UI **50/50**. Zero GDScript runtime/compile/parse errors.
- Editor import: completed; all five new script UID sidecars generated. Sandbox network-listen and existing teardown diagnostics were observed, with no script compilation errors.
- Final `git diff --check`: passes. Reviewed the diff/stat and complete Stage 13 changes; earlier stage and unrelated Workbench work preserved.

Commands: `python3 tools/validate_project.py --allow-generated-cache`; `GODOT_BIN=/home/fluffy56/.local/bin/godot4 python3 -B tools/run_regression_suite.py`; native fixture `godot4 --path . --audio-driver Dummy --script res://tools/verify_run_party.gd -- --party-captures=/tmp/ab-stage13-captures`, with isolated XDG directories. Logs and screenshots are retained in `docs/evidence/complete_ui_stage13/`.

The native fixture is an isolated actual Godot scene/controller test with synthetic mouse/keyboard input; it is not a full campaign playthrough. Screenshot backgrounds are blank because only the actual room's UI host is initialized for controlled inspection.

Known baseline diagnostics: fixtures may report five ObjectDB instances and three resources retained at shutdown. Existing deliberate corrupt-save tests can print JSON parse diagnostics. These are distinguished from GDScript compile/runtime errors and test failures.

## Player verification checklist

1. Continue a run and enter an ordinary exploration room. Open Party; inspect each current heroine and scroll to her equipment.
2. Move a heroine earlier/later. Close/reopen Party and leave the room; verify the order follows into the next room/combat HUD while battlefield positions and actor/Actions remain unchanged.
3. Open Abilities, use Tab and Escape, then Escape again to return focus to Party. Check one-, two- and three-member runs and pending item/dialogue/Backpack guards.
4. Complete a node, reload via Main Menu Continue and verify the saved order. Interrupt a node before resolution and verify the previous safe point resumes.

Normal campaign end-to-end acceptance and physical gamepad checks remain for the user. No unresolved Stage 13 gameplay design question remains. The original detailed ZIP/extracted package is unavailable locally; implementation uses the supplied staged prompt, retained Stage 00 audit and current repository contracts. No new art, economy, abilities, recipes or narrative was invented.

Suggested commit message: `feat: add current-run party inspection and persistent display ordering`

Changes remain local and uncommitted alongside the earlier stage checkpoints. Unrelated Content Workbench work is preserved. Stop before Stage 14 for user review/continue.
