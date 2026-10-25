# Stage 08 — Refuge Expedition hub and ordered party

## Outcome

Authorized by “Proceed with stage 8”. The user selected **Draft selection with Apply Party**: clicking a heroine adds/removes her in order, Back preserves the draft, Apply Party persists the selection, and Explore requires an applied nonempty party.

The map hotspot now opens a graphical vertical floor-access display and Party, Intel, Level Up, Explore controls. The deepest reached floor is marked independently of floor completion or boss victories. No route details or starting-floor shortcuts are exposed by access history.

Party opens a dedicated wide view using the existing canonical visual-profile catalog (including Mira's authored idle fallback), selected highlights and numbered badges. One to three recruited heroines may deploy. Unselected heroines retain their preparation inventory, equipment, Memento and current stats across run start, active saves, return and defeat. Combat encounters use the applied party order instead of the old hardcoded heroine order.

Level Up maps Stats to authored base attributes/max HP/max MP/Actions; Skills to authored levels/tiers plus persistent weapon-family ranks; Heroine Upgrades to authored abilities and actual unlock state. No fictional character level or mockup Attack/Defense/Speed progression was added. Paid upgrades remain unavailable because their purchase definitions are absent.

Intel has This Run/Permanent tabs with the approved option descriptions, plus permanent Submit. Prices and purchases remain unavailable. No entitlement, payment, effect, castle-memory or shortcut implementation was pulled forward from Stages 22–23. Explore uses the existing seed input and launch signal; unspent Bloom still follows the existing departure-discard rule, with no Intel charge.

## Files and existing owners

- `scripts/refuge/ui/refuge_expedition_view.gd` and UID: hub, Party draft, progression mapping, Intel shells, nested Back/focus and Explore gating.
- `scripts/refuge/ui/refuge_floor_progress_view.gd` and UID: native live floor-access diagram; no added bitmap assets.
- `scripts/refuge/bloom_refuge_screen.gd`, `scripts/refuge/ui/refuge_room_shell.gd`: integrate the new view and wide Party layout with existing controls, input, launch and room navigation.
- `scripts/refuge/refuge_management_controller.gd`: save-backed Apply Party through existing `_mutate`, with no-op/stale checks and rollback.
- `scripts/refuge/refuge_ownership_state.gd`: validate one to three selected heroines; deploy/return selected records while retaining inactive ownership.
- `scripts/map/run_state.gd`: preserve inactive heroine stats, selected encounter order, correct subset inventory staging, active safe-point restoration and reunion.
- `scripts/map/campaign_lifecycle_state.gd`: persistent accessed floors, distinct from defeated bosses and generated layer seed manifests.
- `scripts/refuge/refuge_production_provider.gd`: retain its deployed-state rejection when inactive equipment now remains in Refuge.
- `tests/test_refuge_expedition.gd` and UID, `tools/verify_refuge_expedition.gd` and UID, regression runner registration, combined ledger and this evidence/report.

Existing `CampaignSaveSlotStore` atomic writing, backups and recovery were retained. Stage 06–07 and unrelated Content Workbench changes remain local and preserved; no commit/push was requested for this stage.

## Migration and compatibility

Save Envelope **v3 remains unchanged**. Two additive fields use the existing snapshot owners:

- `campaign_lifecycle.accessed_layer_ids`: absent legacy tutorial data defaults to Layer 1; legacy established Refuge/ascent data defaults to the supported Layer 1–2 history. Actual restored/entered graphs record their layer. Explicit malformed, unknown or duplicate entries reject before commit. Seed manifests never imply access or boss defeat.
- Active `run_snapshot.inactive_party_snapshot`: absent legacy full-roster saves default to empty. Subset saves require the complete complementary heroine set, with no active/inactive overlap and valid numeric current values. The existing `refuge_boundary_snapshot` retains inactive preparation/equipment; no second inventory authority was introduced.

JSON key sorting does not determine party order: active restoration rebuilds the party using persisted `selected_party_ids`. Subset inventory/equipment restore uses that same set. The combined ownership state is validated before accepting an active save. No existing ID/enum was reordered, no old save abandoned and no later-layer content activated.

## Verification

| Check | Result |
| --- | --- |
| `python3 tools/validate_project.py --allow-generated-cache` | Pass, 243 named classes; exit 0 |
| `python3 -B tools/run_regression_suite.py` | All 55 scripts pass, including existing Content Workbench and new Expedition coverage; exit 0 |
| `python3 -B -m unittest discover -s tools -p 'test_*.py'` | 13/13 pass; exit 0 |
| Isolated headless `tests/test_refuge_expedition.gd` | Zero failures, no script/parse errors; exit 0 |
| Native `tools/verify_refuge_expedition.gd` | 120 checks pass; 28 exact-size captures at four resolutions; exit 0 |
| `git diff --check`, full tracked diff and new Stage 08 source review | Pass; unrelated work preserved |

Five inspected screenshots are retained under `docs/evidence/complete_ui_stage08/`: `1280x720_hub.png`, `1920x1080_party_draft.png`, `1280x720_intel_permanent.png`, `1600x900_stats.png`, `1024x768_heroine_upgrades.png`. The final badge adjustment moved numbers into the card corners so they do not cover faces. Intel's long list scrolls; its options can receive keyboard focus.

Initial focused fixture failures came from typed-array setup and comparison against legacy/null loadout fields and pre-JSON numeric types. The final tests normalize the existing schema and compare the exact stats and ownership separately; no ownership-preservation assertion was dropped. Native checks passed before and after selection styling changes. Final focused/native/validator checks cover the last presentation changes.

Engine teardown still reports five ObjectDB instances and three resources in focused/native runs, matching the baseline signature. The full suite also emits existing cleanup and deliberate invalid-save diagnostics. No leak-free shutdown or unrun campaign path is claimed.

Focused coverage includes Apply Party persistence failure rollback, no-op and stale requests, invalid/empty/duplicate parties, one- and two-heroine departure, real slot validation/writes, JSON and pre-node seed continuation, correct encounter order, Event-room inventory staging, voluntary return, defeat, unchanged inactive stats/gear/Memento/bags, legacy field defaults, malformed access history, draft cancellation, Backpack independence and disabled upgrade actions.

Native fixture screenshots cover 1280×720, 1920×1080, 1600×900 and 1024×768. This is actual Godot rendering and native input injection, not a normal campaign playthrough. Explore's UI fixture asserts one launch signal; real run transitions are exercised by the focused tests. No production slot is used by the graphical fixture. The focused test uses its own dedicated test save directory.

## Player review

Normal entry: established Refuge → map hotspot.

1. Check the marked accessed floors/deepest reach. Access must not imply a cleared boss or available Passage purchase.
2. Open Party. Remove/re-add heroines to change numbered order; try an empty draft. Back must preserve the draft and Explore must remain disabled until Apply Party succeeds.
3. Apply one or two heroines, inspect an inactive heroine's Backpack, and verify the applied party does not change.
4. Review every heroine in Level Up's three sections and both Intel tabs. Browsing must charge nothing; unavailable actions cannot purchase/upgrade anything.
5. Explore, then return or suffer defeat. Verify the inactive heroine's bag, equipment, Memento and stats stay intact. Test Continue at a supported active safe point and Main Menu Load at Refuge.
6. Back/Escape from a submenu returns to the hub; closing the hub restores map-hotspot focus.

Isolated visual review:

```sh
XDG_DATA_HOME=/tmp/ab-expedition-review-data XDG_CONFIG_HOME=/tmp/ab-expedition-review-config XDG_CACHE_HOME=/tmp/ab-expedition-review-cache godot4 --path . --audio-driver Dummy --script res://tools/verify_refuge_expedition.gd -- --expedition-interactive
```

Physical-controller and normal-campaign playthrough acceptance remain pending. Paid Level Up rules (effects, costs, caps, prerequisites) still need authoring; Intel implementation/prices remain the later authorized stages. These unavailable services are not counted as tested purchases.

Suggested commit message: `feat: add Refuge Expedition hub and safe party selection`

Stop after this stage for review/continue. Stage 09 has not begun.
