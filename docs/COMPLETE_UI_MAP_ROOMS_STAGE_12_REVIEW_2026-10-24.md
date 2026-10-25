# Stage 12 — Loot, capacity and source lifetime

Stage 12 is implemented locally. Ordinary room pickups and authored fight rewards now open Loot beside the shared Backpack, with the existing six-slot HUD Item Bar. Stage 13 has not begun. No commit or push was requested or performed.

## Player behavior

- Select a current heroine, then collect into her Backpack. Quick collection merges compatible stacks first and uses the first empty slots afterward. Dragging chooses an exact empty/compatible bag slot; full matching stacks accept nothing, and excess stays at the source. Loot cannot evict carried items, enter Stash, or equip directly.
- Switch to another heroine when the first bag cannot accept more. The existing carried bag/Item Bar moves, merges, splits and exact-source exchanges remain available.
- During an open out-of-combat Loot offer, carried-item context menus offer Use and Discard. Use selects a current heroine and applies the existing field-item rules; Discard confirms the exact quantity. Invalid/no-effect use and cancellation change nothing. These are not new combat permissions or general Backpack Use/Discard permissions.
- Keys and Materials retain their shared run collections. Carried Mementos enter a bag. The transaction accepts existing equipment-instance snapshots into a bag, preserving identity and condition; no new equipment rewards were authored.
- Closing ordinary room loot retains its contents. Exhausted hotspots disappear; nonempty ones remain. The existing room exit/outcome and cleared-room re-entry paths carry the remainder through production safe-point persistence.
- Victory with an authored reward opens Loot before the existing encounter summary. Closing with fight surplus asks **Leave items behind**; cancelling preserves the offer. Confirming marks only those fight sources exhausted and records their abandoned quantity. Collected inventory remains owned. Defeat and mandatory story transitions retain their existing flows.

## Ownership, files and compatibility

New files:

- `scripts/inventory/loot_claim.gd`: remainder/lifetime helpers over existing source dictionaries.
- `scripts/inventory/run_loot_controller.gd`: staged collection, Use/Discard, equipment registry transfers and fight abandonment, extending `RunBackpackController`.
- `scripts/inventory/run_item_use.gd`: the existing Event-room field-item validation/effect methods extracted without changing their rules.
- `tests/test_run_loot.gd`, `tests/test_run_loot_ui.gd`, `tools/verify_run_loot.gd`: transactions, production persistence, actual host/input/rendering checks.

Extended files:

- `scripts/inventory/run_backpack_controller.gd`: publishes shared collections and staged equipment registrations/removals with inventory; applies validated field effects after ownership is published.
- `scripts/inventory/run_backpack_panel.gd`: adjacent scrollable Loot column, named heroine destination, carried Use/Discard, nested confirmation and source-specific close behavior. Reuses `BackpackView`, slot presenters, drag forwarding and the original HUD Item Bar.
- `scripts/exploration/event_room_screen.gd`: opens existing pickup assignments, removes only exhausted pickups, and makes dialogue room-item consumption respect partial quantities. Existing room outcomes retain ownership of persistence.
- `scripts/map/main_controller.gd`: victory Loot handoff and refreshed party/Item Bar capture before the existing summary.
- `scripts/map/run_state.gd`, `scripts/exploration/items/reward_source_resolver.gd`: prepare a fixed record without collecting it, validate saved remainder counters, and preserve legacy routing compatibility.
- `tools/run_regression_suite.py`, `tools/validate_project.py`: register the two new tests and update superseded pickup-routing structural expectations.
- This report, combined stage ledger and `docs/evidence/complete_ui_stage12/`.

No save-version bump or ID/enum migration. Existing v3 saves remain supported. Source `quantity`, authored entry, binding and deterministic seed remain unchanged. Optional `remaining_quantity` and `abandoned_quantity` extend the existing `reward_resolutions` and room `local_state.item_spawns` records. Missing counters preserve legacy all-or-nothing claims; explicit malformed counters and impossible room abandonment reject during active-run restoration before commit. Legacy deferred node rewards retain their compatibility retry path. Newly presented fights resolve collection/abandonment before summary, so their surplus cannot be reclaimed later.

There is no new save store, inventory authority, mid-node save, price, recipe, reward table or active room registration. `CampaignSaveSlotStore` retains atomic writes/backups/recovery. An interrupted room/fight resumes the saved pre-node state and seed; a successful resolution saves inventory and source claims together. Existing equipment defeat protection and material banking rules are unchanged.

## Executed verification

Godot: `/home/fluffy56/.local/bin/godot4`, 4.7.2 stable. Native rendering: Compatibility/OpenGL on Intel Iris Xe.

| Check | Exact result |
| --- | --- |
| `python3 tools/validate_project.py --allow-generated-cache` | Pass, 251 named GDScript classes |
| `GODOT_BIN=/home/fluffy56/.local/bin/godot4 python3 -B tools/run_regression_suite.py` | Exit 0; all 61 scripts passed |
| `python3 -B -m unittest discover -s tools -p 'test_*.py'` | Exit 0; 13 tests passed |
| Stage 12 transaction script | 54 checks, 0 failures |
| Stage 12 UI in the cumulative suite | 29 checks, 0 failures |
| Final focused UI with added native drag assertion | 30 checks, 0 failures, both headless and native |
| Existing Stage 11 transaction/UI in cumulative suite | 39 and 50 checks respectively, 0 failures |
| `git diff --check` | Pass |

Meaningful coverage includes full-bag compatible merges; full matching no-op; empty/alternative heroine capacity; exact partial acceptance; stale requests; no direct Loot-to-bar/equipment action; shared Keys/Materials; Use/no-effect Use/Discard; equipment identity, condition and registry cleanup; mixed room/fight abandonment isolation; malformed/legacy counters; production reward seed restoration; confirmed fight loss across save/revisit; and source exhaustion without duplicate Bloom.

The production-store room test collects four of seven items, retains three, verifies no mid-room write, injects a post-room write failure, verifies the previous file remains identical, retries successfully, restores JSON, and collects exactly the remaining three. The actual-room fixture also serializes/reopens authored Wine Cellar content and verifies no reroll or duplicate exhausted hotspot.

The suite contains intentional corrupt-JSON recovery diagnostics and existing teardown warnings. There were zero GDScript runtime/parse errors in the cumulative suite and final focused runs. The Stage 12 native fixture reports the existing 5 ObjectDB / 3 resources-at-exit diagnostics; this is not a leak-free claim.

## Native Godot QA and evidence

Actual `EventRoomScreen` and `CombatEncounter`/main-controller hosts rendered at 1920×1080, 1600×900, 1280×720 and 1024×768. Injected mouse/keyboard input covered opening/closing offers, selecting another heroine, dragging Loot into a bag, right-click context, Escape cancellation and confirmation-button clicks. Assertions checked adjacent geometry and exactly one six-slot bar. All four resolutions were captured; selected images were visually inspected. Inspection caught and corrected an overlapping confirmation message/quantity field before final captures.

Retained evidence in `docs/evidence/complete_ui_stage12/`:

- `1280x720_room_loot.png`
- `1024x768_full_backpack.png`
- `1024x768_discard_confirmation.png`
- `1024x768_fight_abandon_confirmation.png`
- `regression-suite.log`, `native-loot.log`, `python-tests.log`, `focused-loot-ui.log`

These are native Godot fixture captures, not browser previews. The fixture forces a victory outcome to inspect the real handoff; it does not establish a newly played full campaign. Physical gamepad and normal-campaign player acceptance remain pending.

Runnable isolated visual QA:

```bash
XDG_DATA_HOME=/tmp/ab-stage12-native-data XDG_CONFIG_HOME=/tmp/ab-stage12-native-config XDG_CACHE_HOME=/tmp/ab-stage12-native-cache /home/fluffy56/.local/bin/godot4 --path . --audio-driver Dummy --script res://tools/verify_run_loot.gd -- --loot-captures=/tmp/ab-stage12-captures
```

## Player review and remaining scope

1. In an authored item room such as Wine Cellar, open a pickup, close it, leave, revisit and load from a resolved safe point. Confirm the same uncollected contents remain.
2. Fill one heroine's bag. Check compatible merges, rejected full stacks, another heroine's capacity, and bag/Item Bar management without a second bar.
3. During Loot, cancel Use/Discard, then confirm a valid carried-item use/discard. Check the chosen heroine and exact quantity.
4. Win the Layer 2 Kept Watch encounter with its authored Chain Oil reward. Cancel the leave-items confirmation, then collect or explicitly abandon it. Confirm summary/Continue/revisit cannot grant it twice.

No unresolved design decision blocks the implemented Stage 12 scope. New Treasury variants, hidden caches and trapped pickups remain Stage 18/19 content; the multi-source transaction API and saved counters are ready for those callers without activating them now. No loot/equipment definitions or economy were invented. The detailed package Loot file and original archive were absent locally; implementation used the supplied staged prompt and repository Stage 00 audit's retained approved rules.

Earlier Stage 06–11 work and unrelated Content Workbench changes remain preserved and uncommitted alongside Stage 12. Suggested Stage 12 commit message: `feat: add persistent loot claims and shared backpack loot UI`.

Next: user verification/continue, then Stage 13 — current-run Party inspection/reordering without changing roster or combat turn ownership.
