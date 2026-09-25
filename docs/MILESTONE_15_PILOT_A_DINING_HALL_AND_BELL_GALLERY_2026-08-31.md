# Milestone 15 Pilot A — Dining Hall and Bell Gallery

Pilot A activates exactly two registered ordinary Layer 1 rooms through the
production generator, exploration, dialogue, combat-stage, encounter, and
safe-point boundaries. Both are optional deterministic filler choices. The
other incomplete registry entries remain identity-only content.

## Dining Service Hall

`dining_service_hall` uses the reviewed restyled
`l01_room_dining_service_hall.png` for both its exploration presentation and
linked combat stage. The exploration scene has a readable entry/exit route and
the reusable interaction trigger `dining_service_hall_battle_route`. That
trigger resolves through `dining_service_hall_battle_binding` to encounter
`layer_1_dining_service_hall`, stage `dining_service_hall_stage`, and battlefield
`dining_service_hall`, then returns through the normal Layer 1 map outcome path.

The battlefield is a long two-lane serving route: a split foreground service
floor, west and east service lanes, and a three-part connected rear dais. Seven
authored Engagement Areas provide reciprocal zone and area routes, eight sparse
cross-area Position contacts, three party spawns, two enemy spawns, and explicit
depth bands validated through the existing `AuthoredBattlefield` compiler. The
split entry and central dais deliberately use the established two-position
restricted capacity; tests lock that choice. It adds no cover, line-of-sight,
or novel combat rule.

The party entry floor and both service lanes request rear-facing heroine poses,
matching the straight-on depth of the reviewed room. The earlier Opening
Servant Corridor battlefield was corrected at the same presentation boundary:
its threshold-to-far-door graph no longer reuses the retired diagonal layout.
Runtime facing now follows the nearest living opponent, with those authored
orientations retained only as the no-opponent fallback. Movement between the
new anchors uses a static step-pose fade/snap transition rather than gliding.

The encounter is the fixed existing ordinary-Layer-1 pair `hollow_servant` and
`knife_footman`, using `ruined_chapel_group_rulebook.tres`. No battler, stat,
ability, AI rule, or balance value was created. It grants only the established
ordinary battle Bloom result; it has no item reward source. Victory clears the
node and writes the post-node safe point. Defeat leaves it retryable from the
same pre-node content seed, while cleared revisits keep the trigger disabled.

## Bell-Pull Gallery

`bell_pull_gallery` uses the reviewed restyled
`l01_room_bell_pull_gallery.png` and the production room-entry dialogue trigger.
Its single observation is: “Rows of servant bells line both walls. Their cords
move without visible hands.” Completion uses the existing
`resolved_interaction` dialogue outcome and NarrativeState persistence.

The gallery has a readable exit and no hotspot grant, battle, reward source,
item, key, lock, status, named character, or campaign branch. The pre-node safe
point replays an interrupted unresolved entry; the post-node safe point and
dialogue completion prevent a resolved revisit from replaying the observation.

## Activation and compatibility

The generator assigns these definitions only when their existing stable IDs are
selected from ordinary Layer 1 filler candidates. Neither room is added to the
required opening/event/boss anchors, and Dining Service Hall is excluded from
the fixed Corrupted Butler Lower Kitchen route. Selection and encounter seeds
remain deterministic and snapshot-backed. Save Envelope v3, reward routing,
inventory/equipment, existing room content, combat mechanics, and all Layer 2
activation remain unchanged.

Presentation-only rooms selected as filler now open their registered art and a
normal map exit. They still cannot create an unbound generic battle, dialogue,
or room mechanic merely because their registration marks them as a candidate.
The existing Mira
recruitment aftermath also uses the current curated heroine sprites and a
portrait crop from Mira's curated source instead of temporary artwork.

Focused coverage is in `tests/test_milestone_15_pilot_a.gd`, with supporting
catalog, battlefield, stage-trigger, dialogue, and generator assertions in the
existing suites. Validate with:

```bash
python3 tools/validate_project.py --allow-generated-cache
python3 tools/test_run_regression_suite.py
python3 tools/run_regression_suite.py --godot /home/fluffy56/.local/bin/godot4
git diff --check
```
