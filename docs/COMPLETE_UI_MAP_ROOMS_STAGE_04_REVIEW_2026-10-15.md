# Stage 04 — Refuge Loadouts review

Implemented locally on 2026-10-15 following “Good, comit, upload to github and proceed with stage 4” and the resume requests. Stage 03 was committed and published first. Stage 04 stops here for the requested player review; Stage 05 has not begun.

## Player behavior

The weapon stand opens a right-side Loadouts panel with the shared named heroine selector and four rows: Main Hand, Off Hand, Armor and Memento. Rows show actual equipment names/condition, empty states, canonical Memento artwork and Change buttons. Changing the displayed heroine does not change expedition party order. Existing party-order controls remain accessible in Expedition.

Change offers Nothing, compatible Stash instances, and compatible contents of every named heroine's Backpack. It excludes equipped items and legacy personal reserves. Candidates identify their source heroine and slot and preserve separate copies of a definition. Selection previews the return destination; Equip explicitly commits. Back, top Back/Close and Escape return to the rows, then to the weapon stand with focus restored.

A Stash replacement returns the old item to Stash. A Backpack replacement returns it to the exact vacated source heroine/slot, including full bags and other heroines. Nothing stores the equipped item in Stash; an empty slot is a no-op without saving. Instance identity and condition survive exchanges and JSON reload. Stale previews reject, and failed persistence rolls back the complete exchange.

## Files and existing owners

- `scripts/refuge/refuge_loadout_exchange.gd` (+ UID): stateless candidate filtering and source-return transactions over existing ownership dictionaries. No second inventory authority.
- `scripts/refuge/refuge_management_controller.gd`: candidate/row queries and exchange API through the existing clone, validation, persistence and rollback transaction.
- `scripts/refuge/ui/refuge_loadouts_view.gd` (+ UID): four rows, submenu, destination preview, explicit commit and nested focus/cancellation.
- `scripts/inventory/heroine_selector.gd` (+ UID), `scripts/inventory/backpack_view.gd`, `scenes/inventory/backpack_view.tscn`: shared presentation-only named selector used in Backpacks and Loadouts.
- `scripts/refuge/bloom_refuge_screen.gd`, `scripts/refuge/ui/refuge_room_shell.gd`: station integration, right-side placement, cancellation routing and relocation of existing party ordering to Expedition.
- `tests/test_refuge_loadouts.gd` (+ UID): exchanges, full bags, same-owner registry aliasing, duplicate definitions, broken condition, Armor/Memento eligibility, Nothing, persistence rollback, stale requests, reload, UI selection and focus.
- `tests/test_refuge_management_ui.gd`: existing nested selector test now targets the visible Loadouts selector.
- `tools/run_regression_suite.py`: registers the focused Loadouts test; the pre-existing Workbench registration remains untouched.
- `tools/verify_refuge_loadouts.gd` (+ UID): isolated native-input graphical fixture, three actual render sizes and twelve captures.
- This report, the shared stage ledger, and `docs/evidence/complete_ui_stage04/`: review and execution evidence.

Unrelated `project.godot` plugin configuration, `addons/`, Workbench test/UID and Content Authoring/Workbench documents remain outside this change.

## Compatibility and remaining mappings

No save version, serialized field, Stable ID, enum, ownership/loss policy, combat rule or run permission changes. `RefugeOwnershipState`, `PersonalEquipmentLoadoutState`, `BackpackPayload`, canonical item/equipment catalogs and the existing save callback remain authoritative. Production Save/Load still uses the existing Main Menu paths.

The Stage 00 mapping remains: runtime shields occupy Off Hand; there is no new fifth serialized equipment slot. The current player-available catalog contains no Off Hand/shield candidate, so that submenu truthfully contains Nothing. Multi-slot hand conflicts are excluded rather than automatically displacing several items. Future multi-slot behavior still requires its own decision before activation; it does not block the current authored gear.

Mementos retain their existing canonical Item ID representation and one-equipped-owner-per-ID rule, without fabricated instance IDs or condition. Equipment inventory icons are not authored in the current equipment definitions; their slot frames remain empty while names and condition are rendered. Canonical Memento art is shown. Mockup equipment names/art/values were not promoted into game data.

## Executed checks

| Check | Exact result |
| --- | --- |
| `python3 tools/validate_project.py --allow-generated-cache` | Exit 0; 236 named GDScript classes. |
| `python3 -B tools/run_regression_suite.py` | Exit 0; all 51 regression scripts passed, including the unrelated pre-existing Workbench test. The final Loadouts/shared-inventory/Refuge UI changes were present when their scripts ran. |
| `python3 -B -m unittest discover -s tools -p 'test_*.py'` | Exit 0; 13 tests passed. |
| Focused `tests/test_refuge_loadouts.gd` | Exit 0; zero failures, including equipment JSON identity/condition reload and injected Memento save failure. Also passed in the full suite. |
| Graphical `tools/verify_refuge_loadouts.gd` | Exit 0; 58 native-input/capture checks passed, zero failures; twelve exact-size PNGs at 1280×720, 1920×1080 and 1024×768. |
| Headless editor import | Exit 0; no script/parse errors; generated script UIDs. Sandbox editor socket/listen diagnostics appeared. |
| Diff review | `git diff --check` passed; tracked full diff/stat and all new source/test files reviewed; unrelated Workbench changes preserved. |

Logs are retained in `evidence/complete_ui_stage04/`. Existing Godot teardown diagnostics remain (typically five leaked ObjectDB instances/three resources; the broad Refuge UI test reports 27/24). These do not fail the runner and are also present in earlier stage evidence; no claim is made that the repository has zero engine diagnostics.

## Graphical review and reproducible entry

Actual Godot 4.7.2 Compatibility rendering used the desktop display with isolated temporary XDG directories. The fixture uses seed `27072026`, the established Refuge holding state, all three recruited heroines, and existing authored items. Seraphine exchanges her staff for the sword stored in Mira's Backpack. Memento browsing uses the Hollow Livery Pin from Lysandra's Backpack. No production campaign slot is connected.

Native mouse button events exercise Change, Equip and top Back; native direction/Cancel actions exercise candidate selection and nested cancellation. The twelve PNGs were checked for exact dimensions; selected main/chooser/equipped frames were visually inspected for right-side placement, readable sources/condition, slot frames, violet selection, room/Bloom visibility and unclipped controls. This is automated native Godot fixture execution plus screenshot review, not a manually played campaign or physical-controller session.

Run an interactive review fixture from the repository:

```bash
XDG_DATA_HOME=/tmp/ab-stage04-review-data XDG_CONFIG_HOME=/tmp/ab-stage04-review-config XDG_CACHE_HOME=/tmp/ab-stage04-review-cache godot4 --path . --script res://tools/preview_refuge_room.gd -- --inventory-fixture
```

Open the weapon stand. For repeatable native checks and captures:

```bash
XDG_DATA_HOME=/tmp/ab-stage04-review-data XDG_CONFIG_HOME=/tmp/ab-stage04-review-config XDG_CACHE_HOME=/tmp/ab-stage04-review-cache godot4 --path . --audio-driver Dummy --script res://tools/verify_refuge_loadouts.gd -- --inventory-fixture --loadout-captures=/tmp/ab-stage04-captures
```

Retained engine captures:

- [1280×720 main](evidence/complete_ui_stage04/1280x720_main.png)
- [1280×720 weapon sources](evidence/complete_ui_stage04/1280x720_weapon_sources.png)
- [1024×768 Memento sources](evidence/complete_ui_stage04/1024x768_memento_sources.png)
- [1920×1080 equipped result](evidence/complete_ui_stage04/1920x1080_equipped.png)

## Player verification still required

1. Enter an established Refuge through the normal campaign and open the weapon stand. Browse all three heroines and four rows; confirm expedition order is unchanged.
2. Change equipment from Stash and from another heroine's full Backpack. Inspect the exact return slot, item identity and condition. Use Nothing twice to confirm safe storage and the empty no-op.
3. Repeat with authored Mementos. Back/Escape must not commit; the next Cancel returns focus to the weapon stand. Check keyboard and physical controller navigation.
4. Exit to Main Menu and Continue/Load the campaign. Confirm the equipment, Backpack sources, Mementos and conditions persist. Normal-play campaign reload and physical-controller acceptance remain unverified by this implementation session.

There is no blocking Stage 04 design decision. Selection presentation remains available for user review. Next authorized work would be Stage 05 Repair/Salvage, after the required stage review/continue instruction.

Suggested commit: `feat: add Refuge Loadouts with exact-source equipment exchanges`.
