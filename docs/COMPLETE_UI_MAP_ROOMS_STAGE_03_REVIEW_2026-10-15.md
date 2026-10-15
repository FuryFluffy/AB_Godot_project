# Stage 03 — Atomic inventory transfers and stacks

Authorized after the requested Stage 01–02 commit/GitHub upload, continued by “Continue with the task”. Stage 04 has not started. User verification is separate from implementation and automated fixture checks.

## Publication checkpoint

The prior Stage 01–02 work is committed locally as `17d293d70689dd7e85049586ef52d4425d00f24a` and published as `41fae9555a95b9f31d8a23e1e53d019b89db16ac` on `codex/refuge-room-inventory-stages-01-02` in `FuryFluffy/AB_Godot_project`. The publishing commit uses the separate established publishing history; its tree exactly matches the development checkpoint. The new remote branch SHA was verified after pushing. Main and the publishing checkout's later local Dining work were preserved. Publication checks passed 48/48 Godot scripts and 13/13 Python tests, excluding unrelated local Content Workbench work.

Stage 03 is a subsequent local change, not included in that upload.

## Player behavior and implementation

- Drag a full Backpack/Item Bar stack to an exact slot. Matching Stable IDs merge to the authored cap; excess stays at source. A full matching target and dropping on the source are no-ops. A whole different-item swap returns displacement to the exact source slot, after validating both directions.
- Right-click, keyboard Menu, or controller Y opens the same item menu. Move / exchange arms a source for destination selection. Split opens a positive-integer quantity picker for Backpack/Item Bar stacks, then arms that quantity for drag or destination selection. Partial different-item swaps reject. Cancelling a picker, pending move or drag changes no ownership. Empty bar slots are selectable destinations in Refuge only.
- Stash context menus offer Move to Backpack → named heroine. Backpack context menus offer Move to Stash. These transfer the whole selected stack immediately, filling matching stacks before the first free slots. Overflow remains at the selected source; unrelated contents are never evicted. Stash remains unbounded. Existing transfer buttons now use the same full-stack quick operation.
- Stored equipment uses the named transfer menu and the existing equipment registry services. Carried equipment may be rearranged within its bag; instance identity and condition remain unchanged. Equipment/Mementos cannot enter the Item Bar. Loadout exchanges remain Stage 04.
- Stale drag/context requests reject if the ownership snapshot changed. A successful transfer persists once through the existing controller. Save failure restores the original ownership object. No-op/invalid operations do not save.

`RefugeInventoryTransfer` is stateless operation code over the existing `RefugeOwnershipState` containers. It is not another inventory store. `RefugeManagementController._mutate` still owns staged restoration, full ownership validation, persistence and rollback. `RefugeInventoryInteraction` handles native control forwarding, menus, quantity selection, and focus. The existing Backpack and native six Item Bar buttons remain in use. Combat UI gets no new mutation permissions.

## Changed files

- `scripts/inventory/refuge_inventory_transfer.gd` and UID: exact slot and automatic placement operations, eligibility, conservation and equipment routing.
- `scripts/inventory/refuge_inventory_interaction.gd` and UID: shared mouse/controller transaction intentions, context menus, Split and cancellation.
- `scripts/refuge/refuge_management_controller.gd`: snapshot-bound requests and one-save transfer entry; no-op results skip persistence.
- `scripts/refuge/bloom_refuge_screen.gd`: connects the interaction helper, selectable empty bar targets and full-stack transfer buttons.
- `tests/test_inventory_transfers.gd` and UID, `tools/run_regression_suite.py`: focused behavior, rollback, persistence and deterministic conservation checks; suite registration.
- `tools/verify_inventory_transfers.gd` and UID: isolated native-input/graphical fixture extending the existing Refuge preview.
- This report, the shared stage ledger and `docs/evidence/complete_ui_stage03/`: results and selected Godot captures.

Unrelated Workbench files, plugin configuration and its existing test-suite entry remain intact and uncommitted.

## Compatibility and scope

No save-version bump, field migration, stable-ID change, balance value or new item definition. Existing mixed slots and equipment registries remain authoritative. Canonical item Stable ID is the current authored stack compatibility key; equipment instances never merge. Current registered-equipment defeat protection, return rules, shared Key-ring and banked Materials remain unchanged.

Run/combat Backpack access and Action charging remain Stage 11. Loadout exchanges remain Stage 04. Cross-tab hover switching is still an unapproved presentation proposal; use the named Stash quick transfers. Split is available on the fixed Backpack/Item Bar slots where a destination can be selected. No remote Stash or new loot-source behavior is introduced.

## Validation

Godot 4.7.2, Compatibility renderer. All fixture user/config/cache paths were isolated from production saves.

| Command/check | Exact result |
| --- | --- |
| `python3 -B tools/validate_project.py --allow-generated-cache` | Exit 0; 233 named GDScript classes. |
| `python3 -B tools/run_regression_suite.py` | Exit 0; all 50 scripts passed, including the pre-existing local Workbench test. |
| `python3 -B -m unittest discover -s tools -p 'test_*.py'` | Exit 0; 13/13 tests (9 validator, 4 runner). |
| `godot4 --headless --path . --script res://tests/test_inventory_transfers.gd` | Exit 0; zero failures, including 100 seeded transfer operations, save-failure rollback, equipment condition and JSON reload. Rerun after the final dialog font adjustment. |
| Native input/visual fixture above | Exit 0; 60 assertions passed: 30 interaction checks plus 15 captures and 15 exact dimension checks. Mouse drag/Split/cancel and injected controller context/submenu input passed at 1280×720, 1920×1080 and 1024×768. |
| Final headless editor import | Exit 0; new script UIDs generated, no parse/compile errors. |
| `git diff --check`, diff/stat and new-file review | Clean whitespace; unrelated Workbench changes preserved. |

The full regression run preceded the final dialog-only font/size adjustment; the focused transfer suite, native graphical fixture and validator were rerun afterward. Native input uses actual Godot event routing and the engine-rendered controls, with fixture-seeded inventory. Physical controller hardware testing and a newly played normal campaign path are still required; neither is claimed by these checks.

Evidence: `docs/evidence/complete_ui_stage03/` contains the full-suite/focused/native/validator logs, exact results/dimensions and four selected PNGs. Visually inspected the context menu, named-owner submenu, Split dialog and post-split quantities. The off-screen fixture uses exact viewport dimensions and explicit mouse entry, avoiding desktop window-size limits. Screenshots are Godot output, not mockups.

Existing ObjectDB/resource cleanup warnings remain. Corrupt-save tests deliberately log parse/recovery errors, and editor import reports sandbox-denied local socket binding. The passing scripts have no new GDScript parse/compile/runtime errors.

## Runnable review

Normal entry: reach/load an established Refuge and open its chest. Existing campaign save persistence remains connected there.

For isolated fixture input checks and screenshots, run from the project root:

```sh
XDG_DATA_HOME=/tmp/ab-stage03-review/data \
XDG_CONFIG_HOME=/tmp/ab-stage03-review/config \
XDG_CACHE_HOME=/tmp/ab-stage03-review/cache \
godot4 --path . --audio-driver Dummy \
  --script res://tools/verify_inventory_transfers.gd -- \
  --inventory-fixture --transfer-captures=/tmp/ab-stage03-review/captures
```

For interactive review, use `tools/preview_refuge_room.gd -- --inventory-fixture` with the same isolated directories. These fixtures seed authored items and equipment; they do not load or create a production campaign slot.

1. Drag Backpack ↔ Item Bar into empty, matching and different occupied slots. Confirm exact-source displacement and matching-cap remainder.
2. Right-click/controller Y → Split. Try an empty slot, matching slot, incompatible occupied slot, and cancellation.
3. Right-click Stash → Move to Backpack → choose Mira; verify the party order does not change. Move it back using the Backpack menu.
4. Fill a bag but leave space in a matching stack. Quick-transfer a larger stack and check partial acceptance without eviction.
5. Move carried gear to Stash and back to a named bag; check identity/condition. Save/reload through the normal campaign and verify ownership.
6. Check keyboard/controller focus and Escape with menus, quantity picker, pending selection, native drag and parent inventory.

No unresolved design decision blocks Stage 03. Suggested commit: `feat: add atomic Refuge inventory moves swaps and splits`.

Stop after Stage 03 for user verification/continue. Next: Stage 04 Refuge Loadouts and exact-source equipment exchange.
