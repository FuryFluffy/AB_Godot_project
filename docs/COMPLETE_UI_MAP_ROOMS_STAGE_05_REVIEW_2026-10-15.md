# Stage 05 — Refuge Workbench review

Implemented locally on 2026-10-15 under “Proceed to stage 5.” Stage 04 work and unrelated Content Workbench/editor-plugin changes were preserved. No commit or GitHub upload was requested in this turn. Stage 06 has not begun.

## Outcome and player behavior

The tools hotspot opens one contextual Workbench panel with Repair and Salvage tabs. The room and Bloom counter remain visible. Repair shows the existing recipe, banked input quantities, the selected equipment's named source, condition and exact capped outcome. It can target damaged equipment in Stash, any named heroine's Backpack or an equipped slot. Successful repairs change the exact instance in place; insufficient resources or a stale preview cannot spend anything.

Salvage lists only unused, eligible Stash/Backpack equipment. Selection shows condition, source heroine/slot and the named Material yield. The destruction confirmation repeats the item, source and yield. Cancel preserves ownership/resources and returns focus to the review control. Confirmation removes exactly that instance/reference and banks the authored yield once. Equipped gear is excluded and independently rejected by the controller and ownership service until explicitly unequipped.

Both operations retain the existing save transaction and complete rollback on persistence failure. Stale confirmation rejects, and stale UI lists refresh for a new review. Nested selector/confirmation cancellation happens before the station closes; station Cancel restores focus to the tools hotspot.

## Existing data and limitations

- The only registered repair recipe is `refuge_repair_cloth_armor`: one banked Servant Cloth restores one condition, capped by the target definition. Its current target predicate accepts Armor; its name does not create a new cloth-only eligibility rule. No weapon/shield repair formula or economy value was invented.
- Current player-available equipment is non-destructible. Four existing destructible definitions have authored Material mappings/yields, but are not player-available. Therefore the normal production Salvage tab has no candidates. This is a content availability limitation, not permission to activate NPC equipment.
- The isolated verification fixtures temporarily enable the existing `red_wax_drip` definition in process memory and place one instance in Mira's Backpack. They do not edit a `.tres`, enable production content, or touch a production campaign slot. Common/Uncommon/Rare yields remain 1/2/3, verified by the existing service tests.
- Legacy personal registry reserves are not relabelled as Backpack contents. They can be moved into Stash through the existing ownership path before using the station.

There is no unresolved rule blocking the current Stage 05 implementation. Additional player salvageable equipment and additional repair recipes remain future authored content decisions.

## Changed files and boundaries

- `scripts/refuge/ui/refuge_workbench_view.gd` (+ UID): two tabs, reused controls, actual target/result previews, named Materials, selection and affordability presentation.
- `scripts/refuge/bloom_refuge_screen.gd`: integrate tabs, source labels, snapshots for review/commit, readable confirmation, disabled actions and nested focus restoration.
- `scripts/refuge/refuge_management_controller.gd`: named equipment sources, source/equipped filtering and optional expected-snapshot checks on existing repair/salvage APIs.
- `scripts/refuge/refuge_ownership_state.gd`: reject destruction of equipped instances before removal or banking.
- `tests/test_refuge_workbench.gd` (+ UID): repair in three source types, affordability, persistence rollback, unchanged location, stale requests, full-condition rejection, reload, tabs, cancellation, exact-instance salvage and duplicate-confirmation prevention.
- `tests/test_refuge_salvage_recipes.gd`: replace the explicitly superseded equipped-salvage expectation with rejection and unchanged-state assertions, then explicitly unequip and verify the original Uncommon yield/removal.
- `tools/run_regression_suite.py`: register the new focused test; preserve the pre-existing Content Workbench entry.
- `tools/verify_refuge_workbench.gd` (+ UID): isolated native-input and exact-size graphical verification; optional interactive fixture mode.
- Shared stage ledger, this report and `docs/evidence/complete_ui_stage05/`: execution/review records.

No save schema/version, Stable ID, recipe, Material mapping, equipment Resource, drop/activation policy, combat Action cost or run permission changes. Existing `RefugeOwnershipState`, `EquipmentInstance`, recipe/catalog Resources and controller clone/validate/persist/rollback remain the authorities. Old saves remain readable. The intentional behavior change is that equipped gear must now be explicitly unequipped before salvage.

The cumulative working tree also contains Stage 04 changes; those are documented separately. Unrelated `project.godot` plugin configuration, `addons/`, Content Authoring/Workbench documents and Workbench tests remain untouched by Stage 05.

## Executed checks

| Check | Exact result |
| --- | --- |
| `python3 tools/validate_project.py --allow-generated-cache` | Exit 0; 237 named GDScript classes. |
| `python3 -B tools/run_regression_suite.py` | Exit 0; all 52 Godot regression scripts passed, including the pre-existing Content Workbench test. Final runtime changes were present when the Refuge UI/Loadouts/Workbench tests ran. |
| `python3 -B -m unittest discover -s tools -p 'test_*.py'` | Exit 0; 13 tests passed. |
| Focused `tests/test_refuge_workbench.gd` | Exit 0; zero failures. Expanded full-condition/reload assertions were rerun successfully after the full suite's focused-script execution. |
| Existing `tests/test_refuge_salvage_recipes.gd` and `tests/test_refuge_management_ui.gd` | Exit 0, both directly and in the full suite. Equipped-salvage expectations were updated only for the explicit Stage 05 contract. |
| Graphical `tools/verify_refuge_workbench.gd` | Exit 0; 53 native-input/capture checks passed, zero failures; twelve PNGs at three exact resolutions. |
| Headless editor import | Exit 0; no script/parse errors; new UIDs generated. Sandbox editor socket/listen diagnostics remain. |
| Diff review | `git diff --check` passed; full tracked diff/stat and new source/test/fixture files reviewed, including comparison against the Stage 04 starting files. |

Logs are retained in `evidence/complete_ui_stage05/`. Existing Godot teardown diagnostics remain (typically five leaked ObjectDB instances/three resources; broad Refuge UI test 27/24), consistent with previous stage evidence. They do not fail the regression runner. No new script/formatting errors remain in the final focused, graphical or full-suite logs.

## Godot review and entry paths

Actual Godot 4.7.2 Compatibility rendering used the desktop display with isolated XDG directories. The fixture uses seed `27072026`, an established Refuge holding state with the three recruited heroines, Seraphine's broken authored armor and two banked Servant Cloth. Salvage demonstration uses the explicit fixture-only availability described above.

Native mouse events activate Repair, the Salvage tab, review, Cancel and confirm; native direction input selects a candidate; native Cancel closes the station. The twelve images have verified dimensions: 1280×720, 1920×1080 and 1024×768. Selected Repair, Salvage, confirmation and empty-state screenshots were visually inspected for readable sources/cost/yield, tab state, visible room/Bloom and unclipped controls. This is native Godot fixture execution plus screenshot review, not a normal campaign or physical-controller playthrough.

Interactive repair review, with production salvage eligibility unchanged:

```bash
XDG_DATA_HOME=/tmp/ab-stage05-review-data XDG_CONFIG_HOME=/tmp/ab-stage05-review-config XDG_CACHE_HOME=/tmp/ab-stage05-review-cache godot4 --path . --script res://tools/verify_refuge_workbench.gd -- --workbench-interactive
```

To demonstrate salvage interactively, add `--salvage-fixture`. Automated verification and captures:

```bash
XDG_DATA_HOME=/tmp/ab-stage05-review-data XDG_CONFIG_HOME=/tmp/ab-stage05-review-config XDG_CACHE_HOME=/tmp/ab-stage05-review-cache godot4 --path . --audio-driver Dummy --script res://tools/verify_refuge_workbench.gd -- --salvage-fixture --workbench-captures=/tmp/ab-stage05-captures
```

Retained actual engine images:

- [Repair](evidence/complete_ui_stage05/1280x720_repair.png)
- [Salvage candidate](evidence/complete_ui_stage05/1920x1080_salvage.png)
- [Destruction confirmation](evidence/complete_ui_stage05/1280x720_confirmation.png)
- [Empty Salvage tab](evidence/complete_ui_stage05/1024x768_empty_salvage.png)

## Player verification still required

1. In an established campaign Refuge, open Workbench. Check Repair/Salvage tabs and return focus using keyboard/controller Cancel.
2. With damaged Armor and banked Servant Cloth, inspect source and exact before/after condition. Repair equipped gear, then gear stored in Stash or a named Backpack; confirm it stays in place and costs one cloth. Verify insufficient resources and full condition prevent another charge.
3. Use the labelled salvage fixture for the currently unavailable production-content path: inspect Mira's source/yield, cancel the confirmation, then confirm once. Verify only that instance disappears and one Red Wax is banked. Equipped gear must first be unequipped.
4. In normal campaign play, return to Main Menu and Continue/Load after repair. Confirm condition and banked Materials persist. Physical-controller and normal-campaign save/load acceptance remain pending.

Next stage after review/continue: Stage 06, separate Refuge Alchemy and Crafting. No Stage 06 production recipes or controls were implemented here.

Suggested commit: `feat: add Refuge Workbench repair and safe salvage tabs`.
