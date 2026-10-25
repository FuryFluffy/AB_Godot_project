# Stage 09 — Records and isolated Gallery playback

## Outcome and current content

Authorized by “Proceed with stage 9”. Books now open one contextual right-hand Records panel with Lore, Bestiary, Run History and Gallery tabs. The entry list, parchment-style scrollable reading area, selection highlights and thumbnail/preview layout follow the approved Records/Gallery references while retaining the existing room, theme and navigation shell.

Lore reads the campaign-configured `LoreCatalogDefinition` and filters through the existing `KnowledgeState.has_entry`. The current catalog contains **Butler's Records**, stable ID `butler_records`. Undiscovered and unknown IDs reveal no title, archive text or media. The existing authored text is shown unchanged (including its pre-existing missing initial “R”). Some older save tests use `butlers_records`; that is not the authored ID and no alias/discovery migration was invented.

Bestiary has no authored discovery/disclosure rules or record store. Run History has no past-expedition ledger/retention contract. Both tabs truthfully report unavailable. Current map/seed state and registered enemy definitions are not presented as discovered enemies or historical runs.

Gallery supports explicitly attached media on discovered lore entries. `LoreEntryDefinition` now has optional `archive_image`, `archive_replay` and `archive_replay_context` fields. The last is an authored starting `DialogueContext` snapshot, not a captured live campaign or an invented historical state. This reuses existing entry discovery; it introduces no independent unlock collection. **No production Resource has been assigned media, replay context, new lore or new unlock rules.** Production Gallery therefore remains empty until eligible attachments are authored. Independent artwork eligibility remains an authoring decision.

Image-only and scene-only entries expose only their supported action; combined entries expose both. View Image preserves aspect ratio in a larger view. Replay completion, Back and Escape return to the selected Gallery entry and list focus; closing Records restores the books hotspot. Stable entry IDs retain category selections. Screen action locks also gate media entry and an already-open replay.

## Replay boundary

`ArchiveReplaySession` uses the existing `DialogueRunner`; its starting context is reconstructed with deep copies. Entry/choice/automatic outcomes affect only that disposable context so authored branching still works. No `DialogueResult` is forwarded to `RunState`, `NarrativeState`, reward handlers or persistence. Completion, cancellation and repeated playback cannot publish rewards, discoveries, stats, inventory, currency, flags, recruitment or story requests.

The existing `DialoguePanel` renders text, portraits, actors and choices inside the Records panel. Authored background overrides are retained. Graphs requiring ordinary/required/dialogue-item use, battles, scene requests or room-item consumption are unavailable rather than pretending those gameplay services work in replay. Invalid graphs and missing/malformed starting contexts also reject before playback. Replay support is dialogue-only; arbitrary gameplay scenes are not instantiated.

## Files changed in this stage

- `scripts/data/lore/lore_entry_definition.gd`: optional archive media/context authoring fields; no existing fields changed.
- `scripts/dialogue/archive_replay_session.gd` and UID: discard-only playback, eligibility checks, deep-copy context boundary.
- `scripts/refuge/ui/refuge_records_view.gd` and UID: category/list/reading, image and replay views, action gating and nested focus restoration.
- `scripts/refuge/bloom_refuge_screen.gd`: Records integration/refresh/cancel/lock and optional configured lore-catalog input.
- `scripts/refuge/ui/refuge_room_shell.gd`: contextual Records width/right-side placement.
- `scripts/map/main_controller.gd`: passes its existing lore catalog into Refuge presentation.
- `tests/test_refuge_records.gd`, `tests/fixtures/refuge_archive_fixture.gd`, corresponding UIDs and regression runner registration.
- `tools/verify_refuge_records.gd` and UID: native mouse/UI-action fixture, isolated optional media and captures.
- Combined stage ledger, this report and `docs/evidence/complete_ui_stage09/`.

Earlier Stage 06–08 edits and unrelated Content Workbench changes remain preserved. No commit or push was requested or performed.

## Compatibility and ownership

Save Envelope v3, `KnowledgeState` serialization, campaign snapshots, atomic slot writes, backups and recovery are unchanged. Optional Resource fields default to null/empty for existing content. No save version bump, migration, ID change, renamed discovery, economy change or content activation is required. Browsing has no mutation/save callback. The test media catalog exists only under test fixtures and is attached in memory by tests; normal gameplay never registers it.

## Verification

| Check | Result |
| --- | --- |
| `python3 tools/validate_project.py --allow-generated-cache` | Pass, 245 named GDScript classes; exit 0 |
| `python3 -B tools/run_regression_suite.py` | All 56 scripts pass; exit 0 |
| `python3 -B -m unittest discover -s tools -p 'test_*.py'` | 13/13 pass; exit 0 |
| Isolated `tests/test_refuge_records.gd` | Zero failures; exit 0 |
| Native `tools/verify_refuge_records.gd` | 124 checks pass; 32 exact-size captures; exit 0 |
| `git diff --check`, full tracked/new-source review | Pass; unrelated changes preserved |

The full suite passed before the final two unavailable-category wording simplifications. Focused/native/validator checks passed again afterward. Final import generated the new script UIDs without script/parse errors.

Focused tests cover unknown/undiscovered IDs; exact archive text; long-text scrolling; configured catalog and restored discovery; truthful missing categories; media-action applicability; image aspect ratio; completion/cancel/focus; stable selection; stale discovery; action locks; repeated reward-bearing replay; local choice/automatic branches; immutable source context and full campaign/knowledge snapshots; unsupported gameplay rejection; malformed/missing context. The persistence callback is never invoked.

Actual Godot 4.7.2 Compatibility rendering and mouse/UI-action injection were checked at 1280×720, 1920×1080, 1600×900 and 1024×768. Five inspected screenshots and focused/native/validator/Python/full-suite logs are retained. Images labelled `fixture` demonstrate test-only attachments; they are not screenshots of unlocked production Gallery content. The native fixture does not enter a normal campaign or use a production save slot. Normal campaign and physical-controller acceptance remain pending.

The first focused run used a misspelled fixture discovery ID; the first native run carried a selected fixture entry between resolution cases while expecting the first entry. Corrected fixture setup passes without changing production IDs or removing preservation assertions.

Focused shutdown reports the baseline five ObjectDB instances/three resources. Native shutdown reports **422 ObjectDB instances, 414 resources and 162 texture RIDs**. A verbose repeat identifies retained existing authored-battlefield/visual-catalog dependencies and lists no new archive view/session resources. Explicit fixture tree cleanup does not remove these diagnostics. Their broader dependency-lifetime cause remains unresolved; this is not claimed as a leak-free native run. Logs retain the warnings. Existing invalid-save diagnostics also remain in the full regression suite.

## Player review and runnable entry

Normal entry: established Refuge → books hotspot → Records.

1. Open Lore before and after collecting Butler's Records; only discovered authored entries should appear. Read/scroll without spending anything.
2. Switch all four categories. Bestiary/Run History should report unavailable; Gallery currently has no production attachments.
3. Close/Escape and verify focus returns to the books. Reopen and verify category/selection navigation remains usable.
4. Once media is authored, check image aspect ratio, applicable actions and return to Gallery. Repeat/interrupt a supported replay and compare campaign flags, knowledge, stats, inventory and Bloom before/after.

Isolated production-content review (temporarily marks the existing document discovered, without writing a save):

```sh
XDG_DATA_HOME=/tmp/ab-records-review-data XDG_CONFIG_HOME=/tmp/ab-records-review-config XDG_CACHE_HOME=/tmp/ab-records-review-cache godot4 --path . --audio-driver Dummy --script res://tools/verify_refuge_records.gd -- --records-interactive
```

Automated optional-media review:

```sh
XDG_DATA_HOME=/tmp/ab-records-review-data XDG_CONFIG_HOME=/tmp/ab-records-review-config XDG_CACHE_HOME=/tmp/ab-records-review-cache godot4 --path . --audio-driver Dummy --script res://tools/verify_refuge_records.gd -- --records-captures=/tmp/ab-records-review-captures
```

Unresolved content decisions: Bestiary discovery/fields; Run History fields/retention; eligible production Gallery image/dialogue attachments and their replay starting contexts. The stage explicitly permits unavailable missing data, so these were not replaced by fabricated content. Gameplay-scene replay needs a separately supported isolation boundary before activation.

Suggested commit message: `feat: add Refuge Records and isolated Gallery playback`

Stop after Stage 09 for review/continue. Stage 10 has not begun.
