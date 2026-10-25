# Stage 07 — Refuge bed presentation

## Outcome and scope

Authorized by “Proceed to stage 7”. The bed opens a compact Rest panel with the shared named heroine selector, each selected heroine's actual Resolve/Corruption, and the two required actions: Restore Resolve and Cleanse Corruption. Closing restores focus to the bed; cancelling an open selector closes that selector first. Selection is local presentation state and does not reorder the expedition party.

Recovery remains unavailable. The supplied `Refuge_and_Run_UI/06_Rest_Station_Design.md` explicitly leaves recovery amounts, currencies/Materials, price formulas, prerequisites and wider effects undefined, and requires the unavailable state when mechanics are missing. Repository-wide inspection found no authored service definitions. Each action displays “Cost: unavailable” and stays disabled, including after other screen actions are re-enabled. No recovery transaction or invented balance values were added. Paid recovery acceptance cannot be completed until those rules are supplied.

This is separate from automatic Refuge-arrival HP/MP recovery, ordinary run Rest, and special Rest rooms. Those systems were not changed.

## Files and reused owners

- `scripts/refuge/ui/refuge_rest_view.gd` and UID: presentation-only panel, shared `HeroineSelector`, selected values, unavailable actions, nested cancellation.
- `scripts/refuge/refuge_management_controller.gd`: read-only projection of known heroine names and current `RunState.party_snapshot` values. Missing current values display Unavailable instead of substituting initial stats.
- `scripts/refuge/bloom_refuge_screen.gd`: integrates Rest into existing station, refresh, action-lock and cancellation lifecycle.
- `tests/test_refuge_rest.gd` and UID: focused current-value, no-mutation, refresh, unavailable-action, cancellation and missing-state coverage.
- `tools/verify_refuge_rest.gd` and UID: isolated graphical fixture using actual Godot controls and native input events.
- `tools/run_regression_suite.py`: registers the focused Rest test.
- Combined stage ledger and `docs/evidence/complete_ui_stage07/`: review status and retained evidence.

Stage 06 changes remain locally uncommitted. Existing Content Workbench files and plugin settings remain untouched. No commit or upload was requested for this stage.

## Compatibility

No migration, save-version change, serialized field/ID change, new Resource catalog, economy or activation change. Existing `RunState`, Refuge ownership and campaign persistence remain authoritative. The Rest view does not write state or call persistence. Actual values are copied into presentation entries; mutating those entries cannot alter campaign state.

## Verification

Completed 2026-10-17 (implementation began 2026-10-16).

| Check | Result |
| --- | --- |
| `python3 tools/validate_project.py --allow-generated-cache` | Pass, 241 named classes; exit 0 |
| `python3 -B tools/run_regression_suite.py` | All 54 Godot scripts pass, including the existing Content Workbench test and new Rest test; exit 0 |
| `python3 -B -m unittest discover -s tools -p 'test_*.py'` | 13/13 pass; exit 0 |
| `godot4 --headless --path . --script res://tests/test_refuge_rest.gd` | Zero failures; exit 0 |
| Native `verify_refuge_rest.gd -- --rest-captures=/tmp/ab-stage07-captures` | 93 checks pass, zero failures; nine captures at three exact resolutions; exit 0 |
| `git diff --check`, full tracked diff and new Stage 07 source review | Pass; Stage 06 and unrelated Workbench changes preserved |

Screenshots visually inspected and retained: `1280x720_lysandra.png`, `1920x1080_mira.png`, `1024x768_seraphine.png` in `evidence/complete_ui_stage07/`. Controls fit inside the contextual panel, the authored room remains visible, and all selected names/values are legible. The native fixture uses actual mouse and Godot UI action events; it does not create or load a campaign slot.

Earlier fixture attempts failed because direct popup event routing, immediate confirmation and an assumed initial keyboard focus did not match Godot's embedded PopupMenu behavior. The final fixture routes UI actions through the parent viewport after settling, handles initial focus of -1, and asserts the exact selected heroine and closed popup. No production behavior or acceptance assertion was relaxed to mask those fixture failures.

Known diagnostics remain: focused Rest/native runs report five ObjectDB instances and three resources in use at engine shutdown, matching the existing baseline signature. The full suite also logs its existing cleanup and deliberate invalid-save recovery diagnostics. Final Rest runs have no script/parse errors. Passing checks do not claim a leak-free engine shutdown.

## Runnable review and player checklist

Normal gameplay: enter the established Refuge and activate the bed. For an isolated preview with current authored starting values and no production save slot:

```sh
XDG_DATA_HOME=/tmp/ab-rest-review-data XDG_CONFIG_HOME=/tmp/ab-rest-review-config XDG_CACHE_HOME=/tmp/ab-rest-review-cache godot4 --path . --audio-driver Dummy --script res://tools/verify_refuge_rest.gd -- --rest-interactive
```

1. Open the bed and select each named heroine. Check Resolve and Corruption against her campaign state.
2. Confirm both named recovery actions show unavailable costs and cannot activate.
3. Open the selector and cancel once: Rest remains open. Cancel again: focus returns to the bed. Also check Close.
4. Confirm party order, Bloom and Materials remain unchanged after repeated browsing.

Native fixture evidence does not establish a normal campaign save/load playthrough or physical-controller acceptance; those remain user QA. Successful paid recovery, affordability, no-op and save rollback checks remain blocked by absent authored recovery rules, rather than counted as passed.

Suggested commit message: `feat: add selected-heroine Refuge Rest panel`

Stage 08 is not authorized by this request and has not begun.
