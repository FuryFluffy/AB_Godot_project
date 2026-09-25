# Layer 1 Novel Integration and Jailer Calibration

**Date:** 2026-09-02  
**Godot target:** 4.7.2

## Implemented boundary

This pass adapts the approved Layer 1 novel material without forcing the
novel's linear room order onto the seeded run. The Servant Ledger, Wine Cellar,
Ruined Confessional, and Coat clue remain independently discoverable. Existing
Seraphine recruitment and Blood Nun combat are unchanged, and no novel-only
room was added.

- The optional Servant Ledger records permanent campaign knowledge and selects
  an available party-aware callback.
- The Wine Cellar makes its offer once per run. Accepting consumes the room's
  guaranteed bottle, restores active-party HP/MP, adds 10 Resolve and 10
  Corruption, and advances `hidden_feeding_flag_minor`. Refusal has no stat or
  knowledge effect and leaves the bottle collectible.
- Three additional Wine hotspots independently roll a deterministic 65% chance
  of one equally weighted eligible Layer 1/global item. Empty hotspots and
  duplicate results are valid; room state preserves all results on revisit and
  Continue.
- The Confessional waits for Seraphine. Confessing adds 10 Resolve and 10
  Corruption to the active party; refusing adds 15 Resolve and removes 5
  Corruption. Only a completed holy interaction records its permanent callback
  flag, and the choice is available once per run.
- The duelist's coat remains scenery. Taking the Torn Cuff grants the canonical
  `l01_torn_cuff` Story item as capacity-free campaign ownership exactly once.
  It is serialized in the existing NarrativeState campaign snapshot and is not
  placed in the Item Bar, a backpack, or Refuge storage.

All new result application uses plain serializable values. Malformed campaign
item snapshots and dialogue results are rejected before NarrativeState commits
staged data. Save Envelope v3, inventory/equipment domains, room topology,
recruitment, and Blood Nun behavior are unchanged.

## Jailer calibration

The immediate Jailer keeps the same identity, encounter, battlefield, AI
boundary, and Containment Crush weapon. Only the first-run combat profile was
reduced: 48 HP, two Actions, Might 6, Body 5/Tier 3, Athletics 5/Tier 3,
Endurance 7, Plate 7/Tier 3, Order 7, no weapon dice modifier, and +1 flat
damage. The target is a reliable win for a prepared, well-played first-run
party while retaining a likely loss for poor preparation or play. Runtime
manual QA remains the authority for final feel tuning.

## Deliberate non-changes

No new room, heroine, enemy, item definition, equipment system, save version,
Grapple rule, Blood Nun behavior, or Seraphine recruitment behavior is added or
changed here. Novel-only connective scenes remain prose reference rather than
new map nodes.

## Validation

Focused coverage lives in `tests/test_layer1_novel_integration.gd` and the
scene-level Wine regression in `tests/test_opening_event_room_flow.gd`.

```bash
python3 tools/validate_project.py --allow-generated-cache
python3 tools/test_run_regression_suite.py
GODOT_BIN=/home/fluffy56/.local/bin/godot4 python3 tools/run_regression_suite.py
git diff --check
```
