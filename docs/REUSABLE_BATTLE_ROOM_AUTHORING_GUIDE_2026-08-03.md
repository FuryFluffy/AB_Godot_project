# Reusable Battle Room Authoring Guide

## Included backgrounds and starter scenes

| Room | Background asset | Starter scene |
|---|---|---|
| Opening Servant Corridor | `res://assets/backgrounds/layer_1/opening_servant_corridor_battle.png` | `res://scenes/battle/battlefields/authoring_templates/opening_servant_corridor_authoring.tscn` |
| Servant Dormitory | `res://assets/backgrounds/layer_1/servant_dormitory_battle.png` | `res://scenes/battle/battlefields/authoring_templates/servant_dormitory_authoring.tscn` |
| Service Stair Landing | `res://assets/backgrounds/layer_1/service_stair_landing_battle.png` | `res://scenes/battle/battlefields/authoring_templates/service_stair_landing_authoring.tscn` |

The starter scenes contain the correctly sized background and the required
containers. They are intentionally not encounter-ready until you author and
validate their spatial data.

## Fast native-Godot workflow

1. Open Ruined Chapel beside the chosen starter scene.
2. Copy one BattleZone Polygon2D from `Zones` and one Engagement Area
   Polygon2D from the internal `Anchors` container.
3. Paste each under the matching container in the starter scene.
4. Rename IDs before duplicating further.
5. Edit BattleZone polygons first.
6. Edit Engagement Area polygons inside those Zones.
7. Arrange Position children inside each area.
8. Add two-way Zone and area connections.
9. Copy and place neutral spawn markers last.
10. Save and press **Validate Battlefield**.

## Opening Servant Corridor — recommended first pass

This room is a depth-focused linear battlefield. Avoid cutting it into left
and right halves merely because the screen is wide.

Suggested BattleZones:

1. **Entry Carpet** — broad foreground floor.
2. **Near Corridor** — the floor between foreground cabinets and the arch.
3. **Arch Choke** — a short restricted threshold.
4. **Rear Corridor** — the distant hall beyond the arch.

Suggested Engagement Areas:

- one standard Entry area for the party;
- one standard Near Corridor area;
- one restricted Arch Choke area;
- one standard Rear Corridor area.

Graph: `Entry → Near Corridor → Arch Choke → Rear Corridor`.

This room deliberately starts the three heroines in one four-Position area,
making them Adjacent. That is a useful contrast with Ruined Chapel's three
separate starting areas.

Suggested depth: `1.00 / 30`, `0.85 / 22`, `0.72 / 16`, `0.62 / 10`.

## Servant Dormitory — recommended first pass

Use the beds and central carpet to create asymmetry without tracing every bed.

Suggested BattleZones:

1. **Foreground Beds** — the near-left beds and near carpet.
2. **Dormitory Floor** — the broad middle of the room.
3. **Rear Work Area** — shelves, desk, and window side.

Suggested Engagement Areas:

- Foreground Left Beds;
- Foreground Carpet;
- Middle Bed Row;
- Middle Aisle;
- Rear Desk.

Connect the two foreground areas to their matching middle areas. Connect both
middle areas to Rear Desk. This produces two lanes that converge at the back
without needing line-of-sight or cover rules yet.

Suggested depth: foreground `1.00 / 30`, middle `0.82 / 20`, rear `0.66 / 10`.

## Service Stair Landing — recommended first pass

This room should test a branch rather than another straight line.

Suggested BattleZones:

1. **Foreground Landing** — carpet and open floor.
2. **Main Stair** — the climb through the centre-left.
3. **Upper Landing** — the top of the stairs.
4. **Lower Passage** — the right-hand arch and corridor.

Suggested Engagement Areas:

- Foreground Left;
- Foreground Right;
- Stair Foot;
- Upper Landing;
- Passage Mouth (restricted);
- Lower Passage.

Suggested graph:

- Foreground Left ↔ Foreground Right;
- Foreground Left ↔ Stair Foot ↔ Upper Landing;
- Foreground Right ↔ Passage Mouth ↔ Lower Passage.

Do not connect Upper Landing directly to Lower Passage unless later room logic
establishes a real crossing. The room's value is its forked route choice.

Suggested depth: foreground `1.00 / 30`, Stair Foot/Passage Mouth `0.82 / 20`,
Upper Landing/Lower Passage `0.66 / 10`.

## Validation checklist

- every ID is unique;
- every graph edge exists in both directions;
- every Engagement Area polygon is inside its owning BattleZone;
- every Position is inside both polygons;
- Position indices are unique and zero-based;
- capacity matches the number of Position children;
- spawn diamonds sit within snap distance of one exact Position;
- every connected Zone pair has at least one cross-Zone area route;
- battler scale decreases with visual depth;
- full debug geometry is not enabled for ordinary combat.

## Linked combat-stage presentation

After tactical validation, register the room's battle-specific visual variant
in `res://data/presentation/combat_stage_catalog.tres`. The stage must use the
same `battlefield_id`, a reviewed matching background (or explicitly preserve
the current authored background), and sparse prop placements with explicit
rear/mid/foreground bands and normalized floor anchors. Add its stable
exploration-room/trigger/encounter/aftermath binding only when the encounter is
production-reachable. Decorative props never imply cover, capacity, route, LOS,
or collision changes; mechanical claims require the exact matching battlefield
rule and legality tests. The complete recipe and active matrix are in
`docs/STATIC_PNG_COMBAT_PRESENTATION_2026-08-30.md`.
