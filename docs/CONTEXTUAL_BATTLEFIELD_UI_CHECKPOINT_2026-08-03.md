# Contextual Battlefield UI Checkpoint — 2026-08-03

## Implemented

- Authored Anchors are now editable Engagement Area Polygon2D nodes.
- Ruined Chapel has six BattleZones and eight Engagement Areas.
- Foreground Nave is divided into Left, Centre, and Right areas.
- Gallery Approach remains the required connection to Rear Gallery.
- Positions are validated against both their area and BattleZone.
- The permanent runtime debug diagram is off by default.
- Move uses white Zones, teal subdivisions, gold choice/path, red threat, and
  final-area Position reticles.
- AOE uses white legal Zones and an ability-coloured hover preview without
  Engagement Area subdivisions.
- Dodge reveals only relevant Zone, area, and Position information.
- Opening Servant Corridor, Servant Dormitory, and Service Stair Landing art
  and authoring starter scenes are included.

## Godot 4.7 Web Editor runtime check

1. Start an ordinary Ruined Chapel battle. Confirm no battlefield geometry is
   visible before choosing an action.
2. Choose Move. Confirm all six BattleZones appear faint white and the internal
   Engagement Areas appear as thin teal subdivisions.
3. Select a legal teal area. Confirm it becomes gold and only its free exact
   Positions appear.
4. Select a second step where available and confirm the gold route advances.
5. Enter a route that permits a hostile Move Reaction and confirm the affected
   step is red.
6. Cancel with right-click or Esc and confirm all geometry disappears.
7. Choose Blight Bomb. Confirm legal whole Zones are white, area subdivisions
   are hidden, and the hovered Zone receives the ability-coloured preview with
   a gold outline.
8. Trigger a Dodge step and confirm only relevant areas and Positions appear.
9. Load the Blood Nun battle and repeat Move/AOE once to confirm the Processing
   Chapel's converted area polygons.

## Authoring check

Open `ruined_chapel_battlefield.tscn`, select the root, and press **Validate
Battlefield**. Then deliberately move a Position outside its teal Engagement
Area, validate, and confirm the new error identifies that Position. Undo the
move and validate again.

Godot was not available in the build environment, so the cumulative structural
suite and focused scene-data checks pass, while the visual/runtime items above
remain the handoff verification.
