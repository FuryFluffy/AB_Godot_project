# Stage 10 — shared run HUD

Implemented 2026-10-19; final verification and native captures completed 2026-10-20.

Stage 10 implements the approved bottom dock in combat, Struggle and exploration. It retains CombatEngine, CombatPresenter, EncounterCoordinator, the exploration runner, item restrictions, targeting, reactions and authored battlefields. Stage 11 has not begun. Changes are local and uncommitted; earlier Stage 06–09 and unrelated Content Workbench changes are preserved.

## Implemented behavior

- Horizontal current-party cards, six native Item Bar slots, a separate Backpack button and one contextual command row. Item/Backpack/command positions remain stable across party sizes and modes. Cards follow the supplied party IDs and display existing portraits, HP/MP numbers, Resolve, Corruption, Action pips and status summaries. Mouse and keyboard selection emit the existing intent.
- Combat: Attack, Move, Ability, End Phase (Begin before encounter startup). Struggle: Struggle, Wait, Submit, End Phase. Existing availability and phase rules remain authoritative. Submit stays locked; obsolete Refuge-upgrade wording is removed without granting an unlock.
- Exploration: Party, Ability and Rest/Return, selected from the existing permanent Refuge-established flag. The former Back/Inventory tiles are hidden; room exits and navigation handlers remain intact.
- Combat Log/Log is a separate tab above commands. Combat keeps its authored drawer animation, fitted to the viewport. Exploration records only dialogue actually presented in the current screen, with repeated refreshes deduplicated; it is not a persistent run-history system.
- The existing Ability popup renders the selected heroine's definitions and costs in both contexts. Combat uses its existing availability controller. Exploration has no authored execution contract, so its real abilities can be inspected but remain disabled with an explanation. Every existing Event-room launch passes a read-only copy of the current progression snapshot, so learned abilities appear without granting unlocks. No parallel catalogue, substitute combat controller, artificial Actions or field effects were added.
- Ability/Struggle panels clear both the dock and the Log tab. Opening Log cancels the existing combat popup through its controller; Escape/right-click retain existing cancellation priorities and can close Log. Exploration dialogue reserves space above the dock and Log tab, preserving access to dialogue Item Bar choices.
- The bottom background and controls consume UI clicks. Popup and card focus remain native Godot controls. Camera rules and authored battler positions are unchanged.

## Deliberately gated dependencies

Backpack transactions are Stage 11, current-run Party is Stage 13, ordinary Rest/Return is Stage 14, and permanent Submit ownership is Stage 22. Their unsupported actions remain disabled. The Backpack explains the Grapple restriction when relevant. No gameplay definitions, production recipes, economy values or save fields were invented.

The remaining design dependency for exploration Ability execution is an authored field-use contract (eligibility, targets, costs and effects). This stage exposes current definitions truthfully without deciding those mechanics.

## Files changed for Stage 10

- New `scripts/battle/presentation/reusable/run_hud_dock.gd`: shared presentation/layout helper and separate Backpack/Log controls.
- `scripts/battle/presentation/reusable/{reusable_combat_hud,command_bar_view,heroine_card_view,item_bar_view,combat_log_drawer}.gd`: shared dock integration, labelled commands, state display, horizontal tray and readable Log entries.
- `scripts/battle/presentation/{ability_panel,struggle_panel}.gd` and `scripts/battle/encounter_coordinator.gd`: popup clearance, reuse and cancellation; truthful Submit text.
- `scripts/exploration/ui/{exploration_hud,exploration_command_bar}.gd` and `scripts/exploration/event_room_screen.gd`: contextual commands, selected state, presented dialogue Log and overlay clearance.
- `scripts/map/main_controller.gd`: supplies existing heroine progression at all eight Event-room creation paths for the read-only Ability view.
- `scenes/battle/ui/reusable/combat_hud.tscn`, `scenes/exploration/components/exploration_hud.tscn`, and reusable `components/{command_bar_view,exploration_command_bar}.tscn`: horizontal containers and contextual command tiles.
- New `tests/test_run_hud.gd` and `tools/verify_run_hud.gd`; updated `tests/{test_combat_hud,test_opening_event_room_flow}.gd`, `tools/{validate_project,run_regression_suite}.py`. Superseded vertical/icon-only expectations now assert the approved dock; gameplay assertions remain.
- This report, combined ledger, native QA logs and eight representative captures under `docs/evidence/complete_ui_stage10/`.

## Compatibility

No save migration or version bump. Production save envelope v3, stable IDs, catalogues, inventory/equipment ownership, safe points, encounter/content seeds and map activation remain unchanged. Old development saves need not be abandoned. Runtime layout changes preserve the existing reusable scene paths and signal APIs.

## Executed validation

- `python3 tools/validate_project.py --allow-generated-cache`: passes, 246 named GDScript classes.
- `python3 -B -m unittest discover -s tools -p 'test_*.py'`: 13/13 pass.
- Initial full official Godot 4.7.2 regression run: 56/57 scripts passed. The sole failure was the superseded 12-point Log font assertion; it now expects the Stage 10 16-point text while preserving the existing hover-detail and mouse-blocking assertions. Final full rerun: all 57/57 scripts pass, exit 0, with zero GDScript runtime/parse errors.
- New headless HUD fixture in that run: 488 checks, zero failures.
- Native Compatibility-renderer fixture: 488 checks, zero failures across 1920×1080, 1600×900, 1280×720 and 1024×768. Covers 1/2/3 heroines, supplied order, keyboard selection, empty/populated slots, exact ×9999 display stress case, actual poison/status/Action values, mode stability, disabled Backpack/Submit, dialogue clearance, shared Ability, Log and mouse blocking.
- The final native fixture includes 14 live-combat checks, zero failures. Includes authored out-of-range Attack rejection, Move targeting, Escape/right-click cancellation, disabled Backpack preserving Actions, existing Ability definitions, Log cancelling Ability, fully collapsed Log and End Phase reaching the real phase handler.
- 55 native screenshots generated; eight representative images retained. Final live screenshots wait for animation completion rather than a timer to avoid capturing an intermediate drawer position under rendering load.
- `git diff --check`: passes. Stage 10 source/scene/test diff reviewed for unrelated changes.

Native and focused live runs still report five ObjectDB instances and three resources at teardown, the established baseline signature. Other regression scripts retain their existing cleanup/intentional invalid-save diagnostics. This report does not claim a leak-free shutdown.

## Native visual QA and player review

Inspected actual Godot-rendered captures for the three-card populated 1920/1280 layouts, 1600 Struggle popup, 1280 dialogue clearance and live encounter/Ability/Log, and 1024 solo/Log layouts, plus the populated exploration Ability view with its disabled authored ability and unchanged costs. The dock fits, labels/quantities are readable, popups clear it, and authored battlefield presentation remains. Captures use temporary XDG profiles and in-memory fixture states; no production campaign save is loaded or written. The ×9999 quantity is display stress data, never an inventory grant.

This is native input injection plus visual inspection, not a complete campaign playthrough or a physical-gamepad test. Player acceptance remains pending: enter a normal encounter, select each current heroine, check targeting/cancellation and End Phase; inspect a real Grapple; enter an exploration room and its dialogue; compare Party/Ability/Rest before Refuge and Party/Ability/Return afterwards. Backpack and the deferred services should remain unavailable at this checkpoint.

Reproduce the full native fixture:

```sh
XDG_DATA_HOME=/tmp/ab-stage10-native-data XDG_CONFIG_HOME=/tmp/ab-stage10-native-config XDG_CACHE_HOME=/tmp/ab-stage10-native-cache godot4 --path . --audio-driver Dummy --script res://tools/verify_run_hud.gd -- --hud-captures=/tmp/ab-stage10-captures
```

Add `--hud-live-only` after `--` to run only live encounter checks/captures.

Suggested commit message: `feat: unify combat and exploration in the shared run HUD`

Next authorized milestone would be Stage 11: connect the existing Backpack component to run ownership and enforce atomic combat transfer permissions and Action costs. Stop here for review/continue.
