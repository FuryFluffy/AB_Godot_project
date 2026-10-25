# Stage 06 — Refuge Alchemy and Crafting interfaces/transactions

Implemented locally on 2026-10-16 after “Comit, upload and proceed to stage 6.” The user clarified: “Keep production recipes empty; implement and verify the interfaces and transactions.” This report marks that approved scope complete; it does not claim an authored production economy is playable.

Stages 04–05 were committed first as source `135671e8502153b0e2d234ecf87f7ca64b4f3bfc` and uploaded as `4cadcddb89c15506bae4ae3cba0dd433e1965314` on `codex/refuge-room-inventory-stages-01-02`. Source/publication trees match (`0f200c18ab04ca152683c0ea4ed1705e74f8a080`), remote SHA verified. Publication validator and focused Workbench test passed. Separate publishing history avoids uploading the development repository's oversized historical archives. Unrelated Content Workbench changes were excluded.

## Outcome

The existing Alchemy apparatus and Crafting toolbox open distinct right-side contextual menus. Both retain the room/Bloom display, a narrow recipe column and larger workspace. Alchemy uses ingredient cards with canonical icons, Owned / Required counts, violet selection and converging lines into a Final Item preview. Crafting uses an amber selection, parchment-coloured assembly preview, Materials checklist and separate finished-item preview. Long recipe labels use ellipsis with full-name tooltips. More than two ingredients remain readable, demonstrated with four inputs at three resolutions.

The normal catalog remains unchanged and has no production recipes. Both station lists truthfully show no recipes and Brew/Craft is disabled. Repair/Salvage remains its separate Workbench service. No mockup economy, item, equipment, unlock or recipe was turned into production data.

The existing recipe Resource/catalog now support a production action, station, canonical output Item ID and quantity. Production flows through an explicit storage provider: an isolated stage validates all ingredients and output storage, creates the output and consumes its inputs, then publishes together. The Refuge provider uses existing banked Materials and the existing merge-first Stash insertion. Full personal Backpacks do not block Stash output. Unknown recipes, wrong stations, insufficient inputs, stale requests and failed persistence change nothing.

The controller still owns clone/validation/persistence/rollback. The provider interface has no implicit storage fallback. A test-only alternate provider demonstrates capacity failure, debit failure, and independence from the Refuge bank/Stash. No field provider or field service was enabled; Stage 21 will supply its current-run Materials/Backpack binding and recipe-discovery policy.

## Files changed

- `scripts/data/refuge_recipe_definition.gd`: append production action; station/output fields; validation and shared provider-based production execution.
- `scripts/data/refuge_recipe_catalog_definition.gd`: validate production outputs against an explicit Item catalog.
- `scripts/refuge/recipe_production_provider.gd` (+ UID): explicit staged input/output provider interface; unbound contexts fail closed.
- `scripts/refuge/refuge_production_provider.gd` (+ UID): existing banked Materials → Stash adapter, with isolated staging and snapshot validation.
- `scripts/refuge/refuge_ownership_state.gd`: production entry through the registered recipe catalog; pass the supplied Item catalog during initialization; preserve repair-only execution contract.
- `scripts/refuge/refuge_management_controller.gd`: station-filtered recipe/ingredient/result view data, stale protection and production through the existing save transaction; production excluded from Repair.
- `scripts/refuge/ui/refuge_production_view.gd` (+ UID): shared recipe selection/commit flow with separate native Alchemy and Crafting compositions and truthful empty states.
- `scripts/refuge/bloom_refuge_screen.gd`, `scripts/refuge/ui/refuge_room_shell.gd`: integrate views into existing apparatus/toolbox pages, update them from current ownership, retain action gating and hotspot focus, provide adequate right-side workspace.
- `tests/test_refuge_production.gd` (+ UID), `tools/run_regression_suite.py`: focused definition, provider, ownership, transaction, reload and UI coverage, registered alongside prior tests.
- `tools/verify_refuge_production.gd` (+ UID): isolated normal-empty and synthetic-recipe graphical/native-input fixtures.
- Shared ledger, this report and `docs/evidence/complete_ui_stage06/`: status, evidence and player review.

No changes under `data/`. Unrelated `project.godot`, `addons/`, Content Authoring/Workbench documents and test remain untouched; their existing test-runner registration is preserved.

## Compatibility and deferred content

No campaign save version, envelope, serialized ownership field, Stable ID, equipment slot, run permission or loss policy changes. `Action.REPAIR_EQUIPMENT` retains ordinal 0; `PRODUCE_ITEM` is appended. Existing recipe Resources default to Workbench and no output, preserving the authored repair service. Newly authored production definitions must specify Alchemy/Crafting and a canonical ordinary ACTIVE output. Keys, Materials, Mementos and equipment are not introduced as production outputs.

The current sole repair recipe remains unchanged. Production recipes, amounts, unlocks and discovery mappings remain deliberately unauthored at the user's request. The test-only tonic/bandage recipes use existing item/Material IDs with synthetic quantities in memory; they are not `.tres` files, campaign unlocks or recommended balance values. A future authored catalog must be validated with both Material and Item catalogs. Permanent recipe discovery and field binding remain Stage 21 work.

## Executed checks

| Check | Exact result |
| --- | --- |
| `python3 tools/validate_project.py --allow-generated-cache` | Exit 0; 240 named GDScript classes. |
| `python3 -B tools/run_regression_suite.py` | Exit 0; all 53 Godot scripts passed, including the pre-existing Content Workbench test and all prior stage tests. |
| `python3 -B -m unittest discover -s tools -p 'test_*.py'` | Exit 0; 13 tests passed. |
| `tests/test_refuge_production.gd` | Exit 0; zero failures, directly and in the full suite. Covers definition validation, cap-aware merging, full-Backpack independence, insufficient inputs, persistence rollback, stale requests, wrong stations, repair separation, JSON reload, existing transfers, provider capacity/debit failure and UI cancellation/gating. |
| Native graphical recipe fixture | Exit 0; 78 checks passed, twelve exact-size captures, zero failures. |
| Native graphical empty-catalog fixture | Exit 0; 36 checks passed, six exact-size captures, zero failures. |
| Headless editor import | Exit 0; no script/parse errors; generated UIDs. Sandbox socket/listen diagnostics remain. |
| Diff review | `git diff --check` passes; full tracked diff/stat and all new source/test/fixture files reviewed; unrelated changes preserved. |

Logs are retained under `evidence/complete_ui_stage06/`. Godot teardown diagnostics remain: native fixtures report five leaked ObjectDB instances/three resources; the new focused production test reports 13/9. These are recorded rather than treated as a clean engine shutdown. The final logs have no script/formatting/assertion failures, and the regression runner succeeds. No claim is made that the project is leak-free.

## Graphical review and runnable entry

Actual Godot 4.7.2 Compatibility rendering used the desktop display and isolated temporary XDG directories. The fixture uses seed `27072026`, the established Refuge holding state and existing recruited heroines. No production save slot is connected.

The synthetic run tested native Brew/Craft clicks, native recipe-list direction input, exact output quantity and all four Material debits, and native Cancel/focus restoration. The normal run tested disabled production and empty lists. Captures cover 1280×720, 1920×1080 and 1024×768. Selected frames were visually inspected for quantities, source/destination wording, composition, contrast, visible room and controls. This is automated native Godot interaction plus screenshot review, not a manually completed campaign or physical-controller session.

Normal empty-recipe interactive preview:

```bash
XDG_DATA_HOME=/tmp/ab-stage06-review-data XDG_CONFIG_HOME=/tmp/ab-stage06-review-config XDG_CACHE_HOME=/tmp/ab-stage06-review-cache godot4 --path . --script res://tools/verify_refuge_production.gd -- --production-interactive
```

Add `--recipe-fixtures` to preview the explicitly synthetic compositions. Automated fixture verification/captures:

```bash
XDG_DATA_HOME=/tmp/ab-stage06-review-data XDG_CONFIG_HOME=/tmp/ab-stage06-review-config XDG_CACHE_HOME=/tmp/ab-stage06-review-cache godot4 --path . --audio-driver Dummy --script res://tools/verify_refuge_production.gd -- --recipe-fixtures --production-captures=/tmp/ab-stage06-captures
```

Omit `--recipe-fixtures` for the normal empty-catalog verification.

Retained engine captures:

- [Alchemy, four test ingredients](evidence/complete_ui_stage06/1280x720_alchemy_preview.png)
- [Crafting assembly/checklist](evidence/complete_ui_stage06/1920x1080_crafting_preview.png)
- [1024×768 Alchemy](evidence/complete_ui_stage06/1024x768_alchemy_preview.png)
- [Normal empty recipe catalog](evidence/complete_ui_stage06/1280x720_alchemy_empty.png)

## Player verification and next step

1. Open Alchemy and Crafting from their separate room props. Confirm the normal catalog has no recipes and no possible charge; Repair/Salvage remains separate.
2. Verify Close/Escape and physical-controller navigation return focus to the corresponding apparatus/toolbox hotspot.
3. In the explicitly labelled synthetic fixture only, inspect all four Owned / Required counts and result quantity, browse/cancel freely, then Brew/Craft once. Confirm inputs decrease once and the result is in Stash; transfer it through existing Backpack controls.
4. Normal campaign/physical-controller acceptance remains pending. Real production economy acceptance awaits authored recipes; no test recipe is to be copied into production as an approved design.

No blocking decision remains for the authorized interfaces/transaction scope. Next stage after review/continue is Stage 07 Refuge bed recovery. Stage 07 and field services have not begun.

Suggested commit: `feat: add Refuge Alchemy and Crafting production interfaces`.
