# Stage 02 — Shared inventory views and ownership mapping

Authorized by “Proceed to stage 2”, continued by subsequent resume requests. Implementation is complete; final checks are recorded below. User verification is pending. Stage 03 has not started. Changes remain uncommitted, alongside Stage 01 and the previously existing Content Workbench work.

## Player behavior

The Refuge chest opens **Stash** first. **Backpacks** shows the selected named heroine's fifteen slots in three columns and five rows, with the party-shared Key-ring beneath them. Changing the Backpack owner does not change Loadouts selection or expedition order. Materials remain a view of the existing banked balance in Stash and cannot be withdrawn.

Backpacks reveals one native six-slot Item Bar at the bottom of the screen, outside the inventory panel. Switching to Stash, opening another station, or closing inventory hides it. The default room remains Bloom-only. Keyboard focus includes the external bar and stays within the open inventory. Reopening the chest returns to Stash.

Ordinary items use their canonical art and quantities. Carried Mementos use their existing Item IDs without invented durability. Equipment displays its authored name and actual condition; equipment definitions currently have no mapped inventory artwork, so no substitute art was invented. Empty slots remain visible and inspectable. Long panels scroll; at 16:9 the retained transfer buttons are below the initial fold.

Existing one-item transfer buttons and equipment ownership services remain available. Dragging, Split, partial acceptance, context-menu quick transfers, and exact-source equipment exchange are the separate Stage 03–04 work. Production run/combat Backpack entry remains Stage 11; the reusable component and read-only run adapter are available for that integration. The current demo still requires all recruited heroines in its expedition; subset start/return belongs to Stage 08.

## Ownership and compatibility

- Existing `RefugeOwnershipState`, `RunInventoryState`, `RunEquipmentState`, and `PersonalEquipmentLoadoutState` remain the authorities. No additional inventory store was introduced.
- An equipment Backpack slot contains `equipment_instance_id`, empty `item_id`, and quantity 1. The existing heroine equipment registry holds the instance definition and condition. Moving existing Stash equipment into a heroine's Backpack consumes a free slot and transfers its registry ownership once.
- Restoration rejects missing, repeated, cross-owner, or simultaneously equipped/carried references. Equipment cannot enter the Item Bar. Existing item placement respects slots occupied by equipment. The Refuge controller validates the staged result before committing through its existing save/rollback callback.
- Equipping, returning to Stash, or salvaging a carried instance clears its Backpack reference. Existing registered unequipped reserves are retained and identified as “Personal reserve”; they are not silently duplicated into a bag or relocated by loading. Stage 04 will implement the approved new Loadouts exchange contract.
- Voluntary return preserves mixed Backpack positions. On defeat, ordinary carried items and unequipped carried Mementos are lost; registered equipment and its condition remain protected, including carried instances. Equipped Mementos, Stash, key scopes, and Materials banking retain their existing behavior. Equipped-only equipment protection was not introduced.
- No save-version bump, stable-ID migration, or old-save abandonment. Old item-only slots still load. New mixed slots are supported by this build; older builds are not promised to understand the new equipment reference. The existing redundant loadout Memento mirror continues to normalize during restoration; the heroine's owned Memento field remains authoritative.

## Files and reused services

Paths below are relative to the repository root.

| Files | Stage 02 change |
| --- | --- |
| `scenes/inventory/backpack_view.tscn`, `scripts/inventory/backpack_view.gd` and UID | Reusable named selector, personal grid, and shared Key-ring component. |
| `scripts/inventory/inventory_panel_view.gd` and UID | Reusable Stash/Backpacks tab shell with explicit Refuge/run presentation context; run context cannot reveal Stash. |
| `scripts/inventory/inventory_slot_presenter.gd` and UID | Read-only item/equipment entries shared by Refuge and run views. |
| `scenes/refuge/bloom_refuge_screen.tscn`, `scripts/refuge/bloom_refuge_screen.gd` | Integrate tabs/component, independent Backpack selection, details, existing transfer controls, and actual banked Materials. |
| `scripts/refuge/ui/refuge_room_shell.gd` | Conditional external Item Bar, layout, tab reset, and focus containment. |
| `scripts/refuge/ui/refuge_slot_grid.gd` | Fifteen visible cells, canonical item art, condition text, inspection and selection. |
| `scenes/battle/ui/reusable/components/item_bar_view.tscn`, `scripts/battle/presentation/reusable/item_bar_view.gd` | Same six native buttons support a horizontal Refuge row. Authored combat default remains one vertical column at its existing size. |
| `scripts/map/backpack_payload.gd` and UID | Equipment reference shape and ownership-location validation. |
| `scripts/map/run_inventory_state.gd`, `scripts/map/run_equipment_state.gd` | Mixed slot restoration, capacity, duplicate/registry validation. |
| `scripts/refuge/refuge_ownership_state.gd`, `scripts/refuge/refuge_management_controller.gd` | Mixed persistent bags, Stash/Memento eligibility, instance location mapping, return/defeat retention, staged validation. |
| `tools/validate_project.py`, `tools/test_validate_resource_defaults.py` | Fix omitted-default false positives; preserve invalid-value checks and default combat orientation. |
| `tests/test_shared_inventory_views.gd` and UID, `tests/test_refuge_management_ui.gd`, `tests/test_combat_hud.gd`, `tools/run_regression_suite.py` | Ownership, UI, keyboard and default combat-layout coverage; register the additional script. Existing Workbench runner entry retained. |
| `tools/preview_refuge_room.gd` | Optional labelled inventory fixture, each heroine's bag, three-resolution captures. |
| This report, combined ledger, `docs/evidence/complete_ui_stage02/` | Review checklist, retained engine captures and validation evidence. |

The preceding Stage 01 changes are still present. Unrelated `addons/`, Content Workbench tests/documents, plugin configuration and its runner entry remain preserved.

## Validator repair

The prior 24 diagnostics came from assuming default-valued exports must appear explicitly in Godot Resource text, followed by registry/art coverage cascades. The validator now reads the declared `layer_number`, `canonical_order`, and legacy canonical-item defaults and inspects root Resource properties rather than subresources. Background coverage is checked independently of identity validity. Wrong layers/orders, malformed values, missing IDs/art, and an explicitly canonical legacy blanket still fail.

The Item Bar layout check now accepts the explicit one-column native grid used by this stage, while rejecting a six-column authored combat default. A runtime HUD test also verifies that the combat default remains vertical. No content definitions or room activation were changed to satisfy validation.

## Executed checks and evidence

Godot: `4.7.2.stable.official.ed1daf0bf`. Godot tests use isolated user/config/cache directories, and the graphical fixture is not attached to a production save slot.

| Check | Result |
| --- | --- |
| `python3 -B tools/validate_project.py --allow-generated-cache` | Exit 0; 231 named GDScript classes; no structural diagnostics. |
| `python3 -B tools/test_validate_resource_defaults.py` | Exit 0; 9/9 tests passed. |
| `python3 -B tools/test_run_regression_suite.py` | Exit 0; 4/4 tests passed. |
| `python3 -B tools/run_regression_suite.py` | Exit 0; all 49 regression scripts passed on the final tree, including the new inventory script and vertical combat-default assertion. |
| Focused `tests/test_shared_inventory_views.gd` | Exit 0; 0 failures, including 40 keyboard-focus steps. |
| Actual Godot Compatibility rendering | 45 successful captures at 1280×720, 1920×1080 and 1024×768; seven selected images retained. |
| `git diff --check`, diff/stat review | Clean whitespace; reviewed Stage 02 ownership/UI changes and preserved preceding/unrelated work. |

Evidence is in `docs/evidence/complete_ui_stage02/`: validator and regression logs, focused output, graphical log, exact image dimensions and selected PNGs. The visual capture pass was performed on 2026-10-11; final automated handoff checks were resumed on 2026-10-14. Images are actual Godot-rendered fixture views, not browser mockups. Examined Stash and mixed/empty Backpacks at the supported sizes. The capture pass caught and corrected a clipped/overlapping Item Bar; automated geometry checks now cover six separate slots within the viewport.

Existing engine teardown ObjectDB/resource warnings remain in logs. Save corruption tests deliberately produce JSON parse/recovery diagnostics. Editor import logs include sandbox-denied local socket binding; scripts imported successfully. These messages are not new inventory test failures. Physical controller testing and a newly played normal campaign path were not performed; no claim is made that those passed.

## Runnable entry and player review

Normal gameplay: load or reach an established Refuge, then open its chest. This path uses the existing production ownership and save services.

For an isolated, explicitly seeded visual fixture, run from the project root:

```sh
XDG_DATA_HOME=/tmp/ab-stage02-review/data \
XDG_CONFIG_HOME=/tmp/ab-stage02-review/config \
XDG_CACHE_HOME=/tmp/ab-stage02-review/cache \
godot4 --path . --audio-driver Dummy \
  --script res://tools/preview_refuge_room.gd -- --inventory-fixture
```

The fixture uses existing authored item IDs, deliberately moves Lysandra's existing sword into Mira's bag, and supplies a small test Material balance. It creates no production save and disables expedition launch. It is not evidence of collecting that equipment through normal play. Add `--capture-dir=/tmp/ab-stage02-review/captures` after the fixture argument to capture and exit.

1. Open the chest: Stash is first, with stored contents and banked Materials.
2. Switch to Backpacks and choose each heroine. Count fifteen cells; confirm expedition order and Loadouts selection stay unchanged.
3. Confirm the Key-ring and six Item Bar contents stay shared across heroine changes. The bar appears below the panel once, with no embedded duplicate.
4. Inspect an ordinary item, Memento, and carried equipment in the fixture. Equipment condition matches its existing instance; a Memento shows no durability.
5. Tab through the panel and external bar, inspect the heroine selector, and cancel. Test equivalent navigation on a physical controller.
6. Switch to Stash, close, reopen, and open another station. Confirm bar visibility and focus restoration. In normal gameplay, save/load and verify the displayed owned contents.

No unresolved design blocker prevents Stage 02 review. Equipment inventory-art mappings, future Memento exchanges, subset roster behavior and advanced transfers remain their documented later work; no balance or narrative values were invented.

Suggested Stage 02 commit message: `feat: add shared Backpack views and mixed inventory ownership`.

Stop here for user verification/continue. Next: Stage 03 atomic moves, merges, swaps, splits and named quick transfers.
